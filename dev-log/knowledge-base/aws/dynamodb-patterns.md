---
tags: [aws, dynamodb, patrones, produccion, idempotencia]
created: 2026-05-20
source: "PROJECT_DNA.md §4,§6 + PROJECT_DNA_COMPLEMENT.md ADR-2 — prestashop-holded-middleware-prod"
confidence: "high — validado en producción (5 tablas)"
---

# DynamoDB patterns — validados en producción

#aws #dynamodb #patrones

Patrones extraídos de `prestashop-holded-middleware-prod` — 5 tablas, operativas desde 2026-05-15.

---

## Regla 1 — PAY_PER_REQUEST siempre

```yaml
# En serverless.yml — resources
Resources:
  OrdersTable:
    Type: AWS::DynamoDB::Table
    Properties:
      BillingMode: PAY_PER_REQUEST   # ← Siempre. Sin excepciones para proyectos nuevos.
      TableName: ${self:service}-orders-${sls:stage}
      AttributeDefinitions:
        - AttributeName: id_pedido_tienda
          AttributeType: S
      KeySchema:
        - AttributeName: id_pedido_tienda
          KeyType: HASH
```

**Por qué PAY_PER_REQUEST:**
- Tráfico bajo e impredecible (crons diarios, webhooks esporádicos)
- Dentro del free tier para < 25 WCU/RCU constantes
- Sin capacity planning — escala automáticamente
- Coste dominante en proyectos de bajo volumen: Secrets Manager (~€0.04/mes), no DynamoDB

**Cuándo revisar:** Si el proyecto supera 1M de escrituras/mes de forma consistente.
Para integraciones B2B típicas, PAY_PER_REQUEST es correcto indefinidamente.

---

## Regla 2 — Sin GSIs por defecto

ADR-2 del proyecto de referencia:

```
5 tablas independientes, una por entidad:
- orders     → siempre acceso por id_pedido_tienda   (PK)
- contacts   → siempre acceso por id_tienda          (PK)
- accounts   → siempre acceso por num                (PK)
- products   → siempre acceso por product_reference  (PK, SKU)
- categories → siempre acceso por category_id        (PK)

Ninguna tabla necesita queries secundarios → GSIs = coste sin beneficio
```

**Cuándo añadir GSI:** Solo si aparece un patrón de acceso por atributo no-PK que
no puede resolverse con Scan + FilterExpression de forma eficiente.
Para la mayoría de integraciones, acceso por PK directo es suficiente.

---

## Regla 3 — ConditionalCheck como idempotencia (AtómICO)

```typescript
import { ConditionalCheckFailedException } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';

// ── CORRECTO: atómico, sin race condition ─────────────────────────────────────
export async function registrarPedidoNuevo(pedido: StandardOrder): Promise<'nuevo' | 'duplicado'> {
  try {
    await docClient.send(new PutCommand({
      TableName: process.env.DYNAMODB_TABLE_ORDERS!,
      Item: {
        id_pedido_tienda: pedido.id_pedido_tienda,
        estado_procesado:  'pending_upload',
        fecha_registro:    new Date().toISOString(),
        datos_raw:         JSON.stringify(pedido),
      },
      ConditionExpression: 'attribute_not_exists(id_pedido_tienda)',
    }));
    return 'nuevo';

  } catch (error: unknown) {
    if (error instanceof ConditionalCheckFailedException) {
      log.warn({ id: pedido.id_pedido_tienda }, 'Pedido ya registrado — duplicado ignorado');
      return 'duplicado';  // No es un error — es el mecanismo funcionando
    }
    throw error;  // Otros errores DynamoDB → propagar
  }
}

// ── INCORRECTO: race condition ─────────────────────────────────────────────────
// Lambda A: getItem → null → putItem ← duplicado si Lambda B hizo lo mismo en paralelo
// Lambda B: getItem → null → putItem ← duplicado
```

**Por qué ocurre la race condition:**
Dos invocaciones Lambda paralelas leen "no existe" simultáneamente y ambas insertan.
Con `ConditionExpression: 'attribute_not_exists(PK)'`, DynamoDB garantiza que solo una gana.
La segunda recibe `ConditionalCheckFailedException` — que se trata como "ya procesado".

Ver [[e2-race-condition-facturas-duplicadas]] — error real que motivó este patrón.

---

## Regla 4 — Naming en snake_case español

```typescript
// ── CAMPOS DYNAMODB — snake_case en español para dominio de negocio ───────────
const item = {
  id_pedido_tienda:   pedido.id,           // NO: orderId, order_id
  estado_procesado:   'invoice_created',   // NO: status, estado
  fecha_registro:     new Date().toISOString(),
  holded_factura_id:  docId,               // ID externo puede ser inglés
  total_pagado:       pedido.total,
  metodo_pago:        pedido.payment_method,
};

// ── RECURSOS AWS — PascalCase en inglés ───────────────────────────────────────
// OrdersTable, ContactsTable, ProductsTable (serverless.yml Resources)
```

**Regla:** Campos que representan datos de negocio → `snake_case` en español.
Referencias a recursos AWS → `PascalCase` en inglés.

---

## Anti-patrón E5 — Bug estado → estado_procesado

```
Error real en prestashop-holded-middleware-prod.
Commit: 8c5e93e "fix(dynamodb): corregir campo estado→estado_procesado"
```

**Qué pasó:**
1. El campo se llamó inicialmente `estado` al crear la tabla
2. Se renombró a `estado_procesado` en el código sin migración de datos
3. `obtenerPedidosYaProcesados()` filtraba por `estado` (nombre viejo)
4. Todos los pedidos ya procesados "desaparecieron" del filtro
5. Lambda 2 volvió a procesarlos → facturas duplicadas en Holded

**Lección:**
- Renombrar un campo en DynamoDB **no es un cambio transparente**
- Los datos existentes tienen el nombre viejo → el filtro no los encuentra
- Protocolo obligatorio: migrar datos existentes O mantener compatibilidad con ambos nombres durante transición
- Ver [[e5-campo-estado-renombrado]] para análisis completo

```typescript
// Patrón de compatibilidad durante migración de campo:
const estado = item.estado_procesado ?? item.estado;  // Lee nuevo, fallback a viejo
// Después de migrar todos los datos: eliminar el fallback
```

---

## Ciclo de vida de estados

```
// Estados válidos para pedidos
type EstadoPedido =
  | 'pending_upload'       // Lambda 2 aún no procesó
  | 'invoice_created'      // Factura creada en Holded
  | 'pending_creditnote'   // Reembolso pendiente
  | 'creditnote_created';  // Abono creado en Holded

// La idempotencia funciona porque:
// 1. Lambda 2 escribe 'pending_upload' con ConditionalCheck (atómico)
// 2. Solo si tiene éxito, actualiza a 'invoice_created'
// 3. Un pedido ya en 'invoice_created' no se vuelve a procesar (guard en Lambda 2)
```

---

## Scan paginado completo

```typescript
// DynamoDB Scan nunca garantiza devolver todos los items en una sola llamada.
// Siempre paginar con LastEvaluatedKey.

export async function obtenerTodosLosPedidos(): Promise<OrderRecord[]> {
  const items: OrderRecord[] = [];
  let lastKey: Record<string, any> | undefined;

  do {
    const response = await docClient.send(new ScanCommand({
      TableName: process.env.DYNAMODB_TABLE_ORDERS!,
      ExclusiveStartKey: lastKey,
      FilterExpression: 'estado_procesado = :estado',
      ExpressionAttributeValues: { ':estado': { S: 'pending_upload' } },
    }));

    items.push(...(response.Items ?? []));
    lastKey = response.LastEvaluatedKey;  // undefined cuando no hay más páginas
  } while (lastKey);

  return items;
}
```

---

## BatchGet/BatchWrite en chunks

```typescript
const BATCH_GET_SIZE   = 100;  // Límite DynamoDB BatchGet
const BATCH_WRITE_SIZE = 25;   // Límite DynamoDB BatchWrite

// BatchGet — dividir en chunks de 100
async function batchGetBySku(skus: string[]): Promise<ProductMapping[]> {
  const results: ProductMapping[] = [];

  for (let i = 0; i < skus.length; i += BATCH_GET_SIZE) {
    const chunk = skus.slice(i, i + BATCH_GET_SIZE);
    const res = await docClient.send(new BatchGetCommand({
      RequestItems: {
        [TABLE_PRODUCTS]: {
          Keys: chunk.map(sku => ({ product_reference: sku })),
        },
      },
    }));
    results.push(...(res.Responses?.[TABLE_PRODUCTS] ?? []));
  }

  return results;
}
```

---

## Deuda técnica documentada — Sin PITR

```
Estado actual: Sin Point-In-Time Recovery activado en ninguna tabla
Impacto: Pérdida total de datos si se borra una tabla (irreversible)
Riesgo: Alto
Coste PITR: ~€0.20/tabla/mes
```

**Para activar en producción:**

```yaml
# En serverless.yml Resources, en cada tabla:
OrdersTable:
  Type: AWS::DynamoDB::Table
  Properties:
    BillingMode: PAY_PER_REQUEST
    PointInTimeRecoverySpecification:
      PointInTimeRecoveryEnabled: true     # ← Añadir esto
```

**Cuándo activar:** Antes de que el cliente tenga datos de producción que no quiera perder.
Para proyectos nuevos: activar desde el primer deploy.
Coste: ~€0.20 × N tablas/mes — negligible vs el riesgo.

---

## 5 tablas del proyecto de referencia

| Tabla | PK | Propósito | Patrón de acceso |
|---|---|---|---|
| `orders-{stage}` | `id_pedido_tienda` (S) | Idempotencia + historial | PutItem (ConditionalCheck) + GetItem |
| `contacts-{stage}` | `id_tienda` (S) | Caché contactos Holded | GetItem + PutItem (caché) |
| `accounts-{stage}` | `num` (S) | Caché plan de cuentas | GetItem + BatchWrite (sync) |
| `products-{stage}` | `product_reference` (S) | Mapeo SKU → cuenta contable | BatchGet (bulk) + PutItem (sync) |
| `categories-{stage}` | `category_id` (S) | Mapeo categoría → cuenta | GetItem + BatchWrite (sync) |

**Nota ADR-4:** SKU (`product_reference`) como PK en lugar de `product_id` de PrestaShop.
`product_id` puede cambiar si se recrea el producto. SKU es estable. Ver [[e1-object-object-nombres]].

---

## Relaciones

- [[idempotencia-dynamodb]] — patrón ConditionalCheck en detalle
- [[e2-race-condition-facturas-duplicadas]] — error real que motivó ConditionalCheck
- [[e5-campo-estado-renombrado]] — antipatrón de renombrado sin migración
- [[lambda-patterns]] — código TypeScript que usa estas tablas (P7, P8, P10)
- [[serverless-framework-v3]] — definición IaC de las tablas en serverless.yml
- [[prestashop-holded-middleware-prod]] — proyecto de referencia

## Proyectos donde aparece

- [[prestashop-holded-middleware-prod]] — 5 tablas operativas desde 2026-05-15
