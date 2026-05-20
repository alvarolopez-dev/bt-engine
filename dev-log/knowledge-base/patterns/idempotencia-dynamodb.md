---
tags: [patron, idempotencia, dynamodb, lambda, concurrencia]
created: 2026-05-20
project: prestashop-holded-middleware-prod
fuente: PROJECT_DNA.md §6 P5 P6, PROJECT_DNA_COMPLEMENT.md ADR-2
---

# Patrón — Idempotencia por ConditionalExpression en DynamoDB

#patron #idempotencia #dynamodb #concurrencia

Resuelve el problema de invocaciones Lambda paralelas que intentan procesar el mismo evento.
Sin este patrón: facturas duplicadas. Con él: solo una gana, la otra lo detecta y se retira.

Ver error que motivó este patrón: [[e2-race-condition-facturas-duplicadas]]

## Principio

Reemplazar el patrón **check-then-insert** (con race condition) por una **operación atómica** de DynamoDB con `ConditionExpression: 'attribute_not_exists(pk)'`.

## Por qué funciona

`PutItem` con `attribute_not_exists` es atómico en DynamoDB.
Solo una Lambda puede ganar. La otra recibe `ConditionalCheckFailedException`.
`ConditionalCheckFailedException` se trata como **warn**, no como error.

## Implementación validada

```typescript
import { ConditionalCheckFailedException } from '@aws-sdk/client-dynamodb';
import { PutCommand } from '@aws-sdk/lib-dynamodb';

// ── PASO 1: escritura atómica ────────────────────────────────────────────────
try {
  await docClient.send(new PutCommand({
    TableName: process.env.DYNAMODB_TABLE_ORDERS!,
    Item: {
      id_pedido_tienda: pedido.id,
      estado: 'pending_upload',
      fecha_creacion: Date.now(),
    },
    // Solo crea si no existe — la primera Lambda que llegue gana
    ConditionExpression: 'attribute_not_exists(id_pedido_tienda)',
  }));
} catch (error: unknown) {
  if (error instanceof ConditionalCheckFailedException) {
    // Otra invocación Lambda ya registró este pedido — no es error
    log.warn({ idPedido: pedido.id }, 'Pedido registrado por otro proceso en paralelo — ignorando');
    return; // La otra Lambda lo está procesando
  }
  throw error; // Cualquier otro error sí se propaga
}

// ── PASO 2: procesar (solo la Lambda que ganó la escritura llega aquí) ───────
await procesarPedido(pedido);
```

## Estados del ciclo de vida

Los estados documentan la transición completa. Si Lambda falla a mitad, puede reintentar sin duplicar:

```typescript
type EstadoPedido =
  | 'pending_upload'      // registrado, pendiente de crear en Holded
  | 'invoice_created'     // factura creada correctamente
  | 'pending_creditnote'  // reembolso detectado, abono pendiente
  | 'creditnote_created'  // abono creado correctamente
  | 'error';              // fallo permanente — revisión manual
```

## Relación con ADR-2 (5 tablas DynamoDB)

De PROJECT_DNA_COMPLEMENT.md ADR-2: se usan **5 tablas independientes** porque cada entidad se accede **exclusivamente por su PK**. No hay queries secundarios que requieran GSIs. Esto simplifica el modelo de idempotencia — cada tabla tiene una PK clara y única.

| Tabla | PK | Patrón de acceso |
|-------|----|-----------------|
| orders | `id_pedido_tienda` | Por ID de pedido |
| contacts | `id_tienda` | Por ID de cliente |
| accounts | `num` | Por número de cuenta |
| products | `product_reference` (SKU) | Por SKU |
| categories | `category_id` | Por ID de categoría |

## Proyectos donde se validó

- [[prestashop-holded-middleware-prod]] — resuelve race condition con Step Functions Express
