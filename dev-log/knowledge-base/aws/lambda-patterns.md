---
tags: [aws, lambda, typescript, patrones, produccion]
created: 2026-05-20
source: "PROJECT_DNA.md — prestashop-holded-middleware-prod"
confidence: "high — confirmado en producción (4 Lambdas)"
---

# Lambda patterns — TypeScript validados en producción

#aws #lambda #typescript #patrones

Todos los patrones confirmados en `prestashop-holded-middleware-prod` — 4 Lambdas, operativas desde 2026-05-15.

---

## P1 — Estructura de handler (obligatoria)

Patrón consistente en las 4 Lambdas del proyecto de referencia.

```typescript
// Orden exacto — nunca alterar
export const main = async (event: Input, _context: Context): Promise<Output> => {
  // 1. SECRETOS — siempre primero, siempre
  await cargarSecretos();

  // 2. GUARD — early return si no hay trabajo
  if (!event.s3Key || event.count === 0) {
    return { procesados: 0, errores: [], saltados: 0 };
  }

  // 3. LÓGICA PRINCIPAL — con error handling individual por ítem
  const resultados = { procesados: 0, errores: [] as string[], saltados: 0 };

  for (const item of items) {
    try {
      await procesarItem(item);
      resultados.procesados++;
    } catch (error: any) {
      // Error de ítem: aísla, continúa el batch
      resultados.errores.push(`Item ${item.id}: ${error.message}`);
      log.error({ itemId: item.id, error: error.message }, 'Error procesando ítem');
    }
  }

  // 4. RETURN SUMMARY — nunca void, siempre objeto con métricas
  return resultados;
};
```

**Reglas:**
- `cargarSecretos()` siempre primero — sin excepción
- Guard antes de lógica — evita invocaciones vacías que consumen tiempo
- Return siempre un objeto — Step Functions necesita el output para decisiones
- Nunca `throw` en el handler raíz — matar la Lambda no ayuda, el error se registra y continúa

---

## P2 — Singleton fuera del handler (warm start)

```typescript
// ── CORRECTO: módulo scope — persiste entre invocaciones warm ──────────────
const prestashopClient  = new PrestashopClient();
const s3Service         = new S3Service();
const holdedService     = new HoldedService();
export const ordersService    = new DynamoOrdersService();
export const productMapping   = new ProductMappingService();

export const main = async (event: any) => {
  // Usa los singletons — ya inicializados
  const pedidos = await prestashopClient.getOrders(desde, hasta);
  // ...
};

// ── INCORRECTO: dentro del handler — nueva instancia cada invocación ────────
export const main = async (event: any) => {
  const client = new PrestashopClient(); // ← nueva conexión cada vez = lento
  // ...
};
```

**Por qué importa:** Lambda reutiliza el proceso entre invocaciones calientes (warm start).
Los singletons en module scope persisten — conexiones HTTP, clientes AWS SDK, caché en memoria.
Instanciar dentro del handler destruye ese beneficio.

---

## P3 — Los 3 niveles de error handling

```typescript
// NIVEL 1 — Error fatal: interrumpe todo el proceso
// Cuándo: secretos no cargados, env vars requeridas ausentes, S3 vacío
if (!process.env.DYNAMODB_TABLE_ORDERS) {
  throw new Error('CONFIG_ERROR: DYNAMODB_TABLE_ORDERS no está definido');
}
// Step Functions captura el throw → rama Catch → SNS alerta

// NIVEL 2 — Error de ítem: aísla el fallo, continúa el batch
// Cuándo: un pedido falla → otros pedidos no deben verse afectados
for (const pedido of pedidos) {
  try {
    await procesarPedido(pedido);
    procesados++;
  } catch (error: any) {
    errores.push(`Pedido ${pedido.id}: ${error.message}`);
    log.error({ pedidoId: pedido.id }, 'Error procesando pedido');
    // No re-throw — el batch continúa
  }
}

// NIVEL 3 — Error de enriquecimiento: degradación silenciosa
// Cuándo: feature opcional falla → el flujo principal no debe interrumpirse
try {
  await holdedService.crearPago(docId, amount, treasuryId);
} catch (pagoError: any) {
  log.warn({ error: pagoError.message, docId }, 'Factura creada pero fallo al registrar pago');
  // warn, no error — el pedido se marca procesado igual
  // Ver: [[degradacion-silenciosa]]
}
```

**Jerarquía:**
- Nivel 1 → `throw` → Step Functions → SNS alerta → requiere intervención
- Nivel 2 → log `error` → continúa → reportado en summary del return
- Nivel 3 → log `warn` → continúa → silencioso para el flujo principal

---

## P4 — Carga de secretos con caché

```typescript
// secrets.service.ts
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

// Singleton del cliente — fuera del handler
const client = new SecretsManagerClient({ region: process.env.AWS_REGION || 'eu-west-2' });
let secretosCargados = false;  // Flag de caché — persiste en warm start

export async function cargarSecretos(): Promise<void> {
  if (secretosCargados) return;  // ← warm start: ya cargados, skip

  if (!process.env.SECRETS_MANAGER_SECRET_NAME) {
    // Local: usa .env directo
    secretosCargados = true;
    return;
  }

  const response = await client.send(new GetSecretValueCommand({
    SecretId: process.env.SECRETS_MANAGER_SECRET_NAME,
  }));

  const secrets = JSON.parse(response.SecretString!);
  for (const [k, v] of Object.entries(secrets)) {
    process.env[k] = v as string;  // Inyecta en process.env como si fuera .env
  }

  secretosCargados = true;
}
```

**Coste:** Secrets Manager cobra por llamada API (~€0.04/mes con 1 invocación/día).
El flag evita re-llamar en warm starts — ahorro de tiempo y coste.

---

## P5 — Logging estructurado con Pino

```typescript
// logger.service.ts
import pino from 'pino';

// Logger base — módulo scope (singleton)
const baseLogger = pino({
  base: { service: 'prestashop-holded-middleware', version: '1.0.0' },
  level: process.env.LOG_LEVEL || 'info',
});

// Child logger por orden — correlación en CloudWatch
export function createOrderLogger(orderId: string, extra?: Record<string, any>) {
  return baseLogger.child({ correlationId: orderId, ...extra });
}

// Child logger por componente — filtro en CloudWatch Insights
export function createComponentLogger(component: string) {
  return baseLogger.child({ component });
}

// ── USO ──────────────────────────────────────────────────────────────────────

// En handler:
const log = createOrderLogger(pedido.id, { orderId: pedido.id, estado: pedido.estado });
log.info({ docId, total }, 'Factura creada');
// → {"service":"prestashop-holded-middleware","correlationId":"404","docId":"5ab...","total":121.0,"msg":"Factura creada"}

// En servicio:
const log = createComponentLogger('HoldedService');
log.warn({ sku, error }, 'Error creando producto en catálogo');
// → {"component":"HoldedService","sku":"CAM-001","error":"...","msg":"Error creando producto"}
```

**Niveles:**
- `info` — operaciones exitosas con contexto clave (factura creada, pedido procesado)
- `debug` — pasos intermedios (solo activar en dev: `LOG_LEVEL=debug`)
- `warn` — fallos recuperables, degradación silenciosa, caché miss
- `error` — fallos que interrumpen el procesado de un ítem

**Regla:** Nunca `console.log` en producción. Todo pasa por el logger Pino.

---

## P6 — Retry con backoff exponencial (axios-retry)

```typescript
// En el constructor del cliente HTTP — fuera del handler
import axiosRetry from 'axios-retry';
import axios from 'axios';

export class HoldedService {
  private readonly client = axios.create({
    baseURL: 'https://api.holded.com/api/v2/',
    headers: {
      'Authorization': `Bearer ${process.env.HOLDED_API_KEY}`,
      'Content-Type': 'application/json',
    },
  });

  constructor() {
    axiosRetry(this.client, {
      retries: 3,
      retryDelay: axiosRetry.exponentialDelay,  // 1s → 2s → 4s
      retryCondition: (error) =>
        axiosRetry.isNetworkOrIdempotentRequestError(error) ||
        error.response?.status >= 500 ||
        error.response?.status === 429,          // Rate limit → retry
      onRetry: (retryCount, error, requestConfig) => {
        log.warn({
          retryCount,
          url: requestConfig.url,
          status: error.response?.status,
        }, 'Reintentando llamada HTTP');
      },
    });
  }
}
```

**Step Functions también tiene retry** (nivel de orquestación):
```yaml
# En serverless.yml — Step Functions state definition
Retry:
  - ErrorEquals: ["States.ALL"]
    IntervalSeconds: 3
    MaxAttempts: 2
    BackoffRate: 2.0
```

**Principio:** El retry ocurre en la capa correcta:
- HTTP transient (5xx, 429, network): axios-retry
- Lambda completa falla: Step Functions retry
- Nunca: retry manual en lógica de negocio

---

## P7 — Idempotencia con DynamoDB ConditionalCheck

```typescript
// dynamodb.service.ts
import { ConditionalCheckFailedException } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';

export async function registrarPedido(pedido: StandardOrder): Promise<void> {
  try {
    await docClient.send(new PutCommand({
      TableName: process.env.DYNAMODB_TABLE_ORDERS!,
      Item: {
        id_pedido_tienda: pedido.id_pedido_tienda,
        estado_procesado: 'pending_upload',
        fecha_registro: new Date().toISOString(),
      },
      // ← Magia: solo escribe si NO existe. Atómico.
      ConditionExpression: 'attribute_not_exists(id_pedido_tienda)',
    }));
  } catch (error: any) {
    if (error instanceof ConditionalCheckFailedException) {
      // Pedido ya procesado por otra invocación Lambda paralela
      // NO es un error — es el mecanismo de deduplicación funcionando
      log.warn({ pedidoId: pedido.id_pedido_tienda }, 'Pedido ya registrado — skip');
      return;  // No throw, no incrementar errores
    }
    throw error;  // Otros errores DynamoDB → sí propagar
  }
}
```

**Por qué ConditionalCheck vs "verificar primero + insertar":**
```
// ── INCORRECTO: race condition ───────────────────────────────────────────────
const existe = await getItem(id);        // Lambda A: no existe
                                          // Lambda B: no existe
if (!existe) await putItem(item);         // Lambda A: inserta ← duplicado
                                          // Lambda B: inserta ← duplicado

// ── CORRECTO: atómico ────────────────────────────────────────────────────────
await putItem(item, condition: NOT_EXISTS); // Lambda A: éxito
                                            // Lambda B: ConditionalCheckFailed → skip
```

Ver [[idempotencia-dynamodb]] para el patrón completo.
Ver [[e2-race-condition-facturas-duplicadas]] para el error original que motivó este patrón.

---

## P8 — Caché en dos niveles

```typescript
// Siempre: memoria (warm Lambda) + DynamoDB (entre invocaciones)
export class HoldedService {
  // Nivel 1: Map en memoria — persiste en warm start
  private readonly contactosCache = new Map<string, string>();

  async obtenerContactId(code: string): Promise<string | null> {
    // Nivel 1: memoria
    if (this.contactosCache.has(code)) {
      return this.contactosCache.get(code)!;
    }

    // Nivel 2: DynamoDB (persistente entre invocaciones)
    const cached = await contactsService.obtenerContactIdCacheado(code);
    if (cached) {
      this.contactosCache.set(code, cached);  // Poblar nivel 1
      return cached;
    }

    // Nivel 3: API Holded (paginada, lenta)
    const contacto = await this.buscarContactoPaginado(code);
    if (contacto) {
      await contactsService.cachearContactId(code, contacto.id);
      this.contactosCache.set(code, contacto.id);
      return contacto.id;
    }

    return null;  // No existe → crear nuevo
  }
}
```

**Aplica a:** contactos Holded, cuentas contables (plan de cuentas), productos Holded.
El patrón evita llamadas API repetidas tanto en el mismo batch (memoria) como entre días (DynamoDB).

---

## P9 — Gate de feature opcional

```typescript
// Al inicio del MÓDULO (no dentro del handler) — se evalúa una vez
const ENABLE_ACCOUNTING   = process.env.ENABLE_ACCOUNTING   === 'true';
const ENABLE_PRODUCT_SYNC = process.env.ENABLE_PRODUCT_SYNC === 'true';

export const main = async (event: any) => {
  await cargarSecretos();
  // ...

  for (const pedido of pedidos) {
    // Feature opcional — no interrumpe si falla
    if (ENABLE_ACCOUNTING) {
      try {
        await resolverCuentasContables(pedido);
      } catch (e: any) {
        log.warn({ error: e.message }, 'ENABLE_ACCOUNTING: fallo — continuando sin cuenta');
      }
    }
  }
};
```

Ver [[patron-3-tiers]] y [[serverless-framework-v3]] para el patrón completo de tiers.

---

## P10 — BatchGet/BatchWrite en chunks

```typescript
// DynamoDB limits: BatchGet=100 items, BatchWrite=25 items
const BATCH_GET_SIZE   = 100;
const BATCH_WRITE_SIZE = 25;

// BatchGet paginado
async function batchGetProductos(skus: string[]): Promise<ProductMapping[]> {
  const results: ProductMapping[] = [];

  for (let i = 0; i < skus.length; i += BATCH_GET_SIZE) {
    const chunk = skus.slice(i, i + BATCH_GET_SIZE);
    const response = await docClient.send(new BatchGetCommand({
      RequestItems: {
        [process.env.DYNAMODB_TABLE_PRODUCTS!]: {
          Keys: chunk.map(sku => ({ product_reference: { S: sku } })),
        },
      },
    }));
    results.push(...(response.Responses?.[process.env.DYNAMODB_TABLE_PRODUCTS!] ?? []));
  }

  return results;
}
```

---

## P11 — Keep-alive en clientes HTTP (oficial AWS)

AWS recomienda explícitamente keep-alive para evitar errores en conexiones idle.

```typescript
// ── CORRECTO: keep-alive en axios — fuera del handler ────────────────────────
import https from 'https';
import axios from 'axios';

const httpsAgent = new https.Agent({ keepAlive: true });  // ← keep-alive

export class HoldedService {
  private readonly client = axios.create({
    baseURL: 'https://api.holded.com/api/v2/',
    httpsAgent,   // ← Pasar agente con keep-alive
    headers: {
      'Authorization': `Bearer ${process.env.HOLDED_API_KEY}`,
      'Content-Type': 'application/json',
    },
  });
}

// ── PROBLEMA SIN KEEP-ALIVE ───────────────────────────────────────────────────
// Lambda purga conexiones idle entre invocaciones.
// Sin keep-alive: primera llamada post-pausa = ECONNRESET.
// El singleton en module scope no ayuda si la conexión se cerró en el socket.
```

**Fuente:** AWS Best Practices docs oficiales Mayo 2026 — "Use a keep-alive directive to maintain persistent connections."

---

## P12 — Límites oficiales AWS Lambda (Mayo 2026)

Extraídos de [gettingstarted-limits](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html).

### Compute y ejecución

| Recurso | Límite |
|---------|--------|
| Memoria mínima | 128 MB |
| Memoria máxima | 10,240 MB (10 GB) |
| Timeout máximo | 900 s (15 minutos) |
| /tmp storage | 512 MB – 10,240 MB |
| File descriptors | 1,024 (Managed Instances: 4,096) |
| Concurrencia default (cuenta) | 1,000 (ampliable) |
| Escalado concurrencia | 1,000 nuevos entornos / 10 s por función |

### Payload

| Tipo | Límite |
|------|--------|
| Request/response sync | 6 MB cada uno |
| Async | 1 MB |
| Response streaming | Sin límite primeros 6 MB; 2 MB/s resto |
| Headers (request line + headers) | 1 MB total |

### Deploy

| Recurso | Límite |
|---------|--------|
| .zip via API/SDK | 50 MB comprimido |
| Contenido total (con layers) | 250 MB descomprimido |
| Container image | 10 GB |
| **Environment variables** | **4 KB total (todas combinadas)** |
| Layers por función | 5 máximo |
| Storage código (cuenta) | 75 GB |

**Gotchas críticos:**
- **4 KB env vars**: ARNs + URLs + nombres largos se acumulan. Si las vars superan 4 KB, el deploy falla. Usar Secrets Manager para valores grandes.
- **6 MB payload sync**: Step Functions pasa output de Lambda como input al siguiente estado. Si `FetchOrders` devuelve JSON de pedidos, puede superar 6 MB con catálogos grandes. Patrón S3 como bus es la solución (ya documentado en [[step-functions-express]]).
- **50 MB .zip**: `sls deploy` falla si el bundle comprimido supera el límite. node_modules bundleados sin tree-shaking son la causa habitual.

---

## P13 — Kill switch vía reserved concurrency

```bash
# Cortar todo el tráfico a una Lambda — efecto INMEDIATO
# Todos los requests reciben HTTP 429 (throttled)
aws lambda put-function-concurrency \
  --function-name {nombre-función} \
  --reserved-concurrent-executions 0

# Verificar estado
aws lambda get-function-concurrency --function-name {nombre-función}

# Reactivar — eliminar limitación (vuelve a concurrencia compartida de cuenta)
aws lambda delete-function-concurrency --function-name {nombre-función}
```

**Fórmula RPS para Function URLs:**
```
RPS máximo = 10 × reserved_concurrency

Ejemplo:
  Sin reserved concurrency  → RPS ilimitado (hasta concurrencia cuenta)
  reserved_concurrency = 100 → RPS máximo = 1,000
  reserved_concurrency = 0   → RPS = 0 (kill switch completo)
```

**Cuándo usar reserved_concurrency = 0:**
- Lambda generando duplicados por bug en producción — cortar mientras se hace fix
- Webhook bajo ataque — throttle sin eliminar la función
- Bug crítico desplegado — ganar tiempo para rollback

---

## P14 — top-level await (ES Modules) — recomendación AWS

AWS recomienda ES modules + `top-level await` para que la inicialización async ocurra durante la **fase de init** de Lambda (antes del primer invoke).

```typescript
// ── RECOMENDADO AWS (ES modules) ─────────────────────────────────────────────
// En package.json: { "type": "module" } o archivo .mjs
// top-level await corre en init phase — antes del primer invoke

import { cargarSecretos } from './secrets.service.js';

await cargarSecretos();  // ← init phase: más fiable, primer invoke más rápido

export const main = async (event: any) => {
  // secrets ya disponibles desde la init phase
  await procesarPedido(event);
};

// ── NUESTRO PATRÓN ACTUAL (válido) ───────────────────────────────────────────
// CommonJS + cargarSecretos() en handler con cache flag
// Funciona correctamente. Diferencia: primer invoke es ~200ms más lento.
// NO contradice las best practices — es un patrón alternativo aceptable.

let secretosCargados = false;
export const main = async (event: any) => {
  await cargarSecretos();  // primer invoke: carga; warmstart: skip por flag
  // ...
};
```

**Estado deuda técnica:** `serverless-plugin-typescript` usa CommonJS por defecto. Migrar a ES modules requiere evaluar compatibilidad con el plugin y `serverless-offline`. Pendiente para próximo proyecto.

---

## ⚠️ Breaking change — nodejs20.x deprecado (URGENTE)

```
Runtime actual en producción: nodejs20.x (prestashop-holded-middleware-prod)

Fechas oficiales AWS:
  Deprecación:        April 30, 2026   ← YA PASÓ (hoy: 2026-05-21)
  Block function create: June 1, 2026  ← EN 10 DÍAS
  Block function update: July 1, 2026  ← EN 40 DÍAS

Runtimes soportados (Mayo 2026):
  nodejs22.x — deprecación: April 30, 2027
  nodejs24.x — deprecación: April 30, 2028
```

**Impacto:** `sls deploy` crea/actualiza funciones Lambda. A partir del June 1, 2026, los deploys fallarán si el runtime es `nodejs20.x`.

**Fix — serverless.yml:**

```yaml
provider:
  runtime: nodejs22.x    # Era: nodejs20.x — CAMBIAR ANTES DEL 1 JUNIO 2026
```

**Fix — tsconfig.json:**

```json
{
  "compilerOptions": {
    "target": "es2022"   // nodejs22 soporta ES2022 — era es2020
  }
}
```

**Verificar compatibilidad antes de deploy:**
- `nodejs22` usa `npm 10` (nodejs20 usaba `npm 9`) — posibles conflictos en lock files
- V8 engine update puede cambiar comportamiento de edge cases numéricos
- Probar en `stage: dev` antes de `stage: prod`

Ver [[holded-auth-change-bearer]] para precedente de breaking change documentado en esta vault.

---

## P15 — Tipos oficiales Lambda con @types/aws-lambda

```typescript
// Instalación (dev dependency — no llega al bundle)
// npm install -D @types/aws-lambda

import { SQSEvent, SQSRecord, SQSBatchResponse, SQSBatchItemFailure,
         APIGatewayProxyEventV2, APIGatewayProxyResultV2,
         Context } from 'aws-lambda';

// Handler SQS tipado completo
export const handler = async (event: SQSEvent, _context: Context): Promise<SQSBatchResponse> => {
  const batchItemFailures: SQSBatchItemFailure[] = [];

  for (const record of event.Records) {
    try {
      // record.body: string — parsear con JSON.parse o zod
      const payload = PedidoSchema.parse(JSON.parse(record.body));
      await procesarPedido(payload);
    } catch (error: unknown) {
      const msg = error instanceof Error ? error.message : String(error);
      log.error({ messageId: record.messageId, error: msg }, 'Error procesando mensaje SQS');
      batchItemFailures.push({ itemIdentifier: record.messageId });
    }
  }

  return { batchItemFailures };  // Lambda solo reintenta los mensajes fallidos
};
```

**Tipos más usados en bt-engine:**
- `SQSEvent` / `SQSBatchResponse` / `SQSBatchItemFailure` — SQS triggers
- `APIGatewayProxyEventV2` / `APIGatewayProxyResultV2` — Function URL (v2 = HTTP API)
- `Context` — siempre como segundo arg aunque no se use (prefijo `_context`)

**Nota:** `import ... from 'aws-lambda'` importa tipos, NO el paquete npm `aws-lambda` (tercero, distinto).

---

## P16 — EMF metrics asíncronos (sin llamadas CloudWatch)

```typescript
// ── INCORRECTO: llamada API síncrona — latencia + coste por llamada ──────────
await cloudwatch.putMetricData({
  Namespace: 'bt-engine',
  MetricData: [{ MetricName: 'PedidosProcesados', Value: procesados }],
});

// ── CORRECTO: EMF vía logs — async, 0 latencia extra, CloudWatch lo ingesta ──
import { createMetricsLogger, Unit } from 'aws-embedded-metrics';

// Fuera del handler (warm: reutiliza instancia)
export const handler = async (event: SQSEvent): Promise<SQSBatchResponse> => {
  const metrics = createMetricsLogger();
  metrics.setNamespace('bt-engine');

  // ... lógica ...

  metrics.putMetric('PedidosProcesados', resultados.procesados, Unit.Count);
  metrics.putMetric('ErroresProcesamiento', resultados.errores.length, Unit.Count);
  await metrics.flush();  // Emite vía stdout — pino-lambda lo captura automáticamente

  return { batchItemFailures };
};
```

**Por qué EMF:** AWS official best practice (Mayo 2026).
Emitir métricas por logs = 0 llamadas API adicionales, 0 latencia extra.
CloudWatch Logs Insights las detecta automáticamente por el formato JSON del payload.
`npm install aws-embedded-metrics`

---

## P17 — SQS partial batch response (obligatorio)

Sin este patrón, cualquier error en un mensaje del batch → todos los mensajes del batch se reintentan.

```typescript
// serverless.yml — REQUERIDO para activar partial batch
functions:
  procesarPedidos:
    handler: src/handlers/procesar_pedidos.main
    timeout: 30
    events:
      - sqs:
          arn: !GetAtt PedidosQueue.Arn
          batchSize: 10
          functionResponseType: ReportBatchItemFailures  # ← Sin esto, partial batch no funciona
```

```typescript
// handler — siempre retornar SQSBatchResponse, nunca void ni throw
export const handler = async (event: SQSEvent): Promise<SQSBatchResponse> => {
  const batchItemFailures: SQSBatchItemFailure[] = [];

  for (const record of event.Records) {
    try {
      await procesarMensaje(JSON.parse(record.body));
    } catch (error: unknown) {
      const msg = error instanceof Error ? error.message : String(error);
      log.error({ messageId: record.messageId, error: msg }, 'Error en mensaje SQS');
      batchItemFailures.push({ itemIdentifier: record.messageId });
      // NO re-throw — continúa el batch
    }
  }

  return { batchItemFailures };
  // Si batchItemFailures vacío → Lambda borra todos del queue
  // Si tiene items → Lambda reintenta solo esos, borra los demás
};
```

**Idempotencia sigue siendo obligatoria** — SQS procesa "at least once" incluso con partial batch.

---

## P18 — SQS: visibility timeout y batch window

### Constraint crítico: visibility timeout

```
visibilityTimeout DEBE SER >= 3 × Lambda timeout

Si visibilityTimeout <= Lambda timeout:
  → Mensaje vuelve visible ANTES de que Lambda termine
  → Otra invocación Lambda lo lee
  → Duplicado garantizado (incluso con idempotencia = sobrecarga innecesaria)

Regla: timeout Lambda = 30s → visibilityTimeout mínimo = 90s (3×30)
```

```yaml
resources:
  Resources:
    PedidosQueue:
      Type: AWS::SQS::Queue
      Properties:
        VisibilityTimeout: 90       # 3 × Lambda timeout (30s)
        MessageRetentionPeriod: 86400  # 1 día
```

### Gotcha: batch window con tráfico bajo

```
Si configuras batchWindow para acumular mensajes antes de invocar Lambda:
  → En tráfico bajo, Lambda puede esperar hasta 20s AUNQUE el batchWindow sea menor
  → Ej: batchWindow=5 con 1 mensaje/hora → Lambda espera 20s (no 5s)
  → Causa: SQS polling interno de Lambda con back-off automático

Implicación: NO usar batchWindow si necesitas latencia < 20s en tráfico bajo.
Alternativa: batchSize=1, sin batchWindow (cada mensaje = una invocación).
```

---

## Anti-patrones documentados

| Anti-patrón | Problema | Corrección |
|---|---|---|
| Instanciar cliente dentro del handler | Nueva conexión por invocación — lento | Singleton en module scope |
| Axios sin keep-alive | ECONNRESET en conexiones idle — P11 | `https.Agent({ keepAlive: true })` |
| `console.log` en producción | No structurado, difícil de filtrar en CloudWatch | Pino con child loggers |
| `try/catch` en todo sin niveles | Fatal y recuperable tratados igual | 3 niveles explícitos |
| Verificar + insertar DynamoDB | Race condition con Lambdas paralelas | ConditionalCheck atómico |
| `any` en models de negocio | Pierde tipo tras frontera | Zod en boundary + tipos desde schema |
| Llamada API dentro de loop sin caché | N llamadas para N ítems | Caché 2 niveles |
| `forEach` con callbacks async | forEach no awaita — items se procesan en paralelo sin control | `for...of` o `await Promise.all()` |
| Env vars > 4 KB total | Lambda rechaza el deploy — P12 | Mover valores largos a Secrets Manager |
| `nodejs20.x` en serverless.yml | Block function create June 1, 2026 | Migrar a `nodejs22.x` |
| `visibilityTimeout <= Lambda timeout` | Mensajes duplicados garantizados — P18 | `visibilityTimeout >= 3 × Lambda timeout` |
| SQS sin `functionResponseType: ReportBatchItemFailures` | Error en 1 mensaje reintenta batch completo | Añadir en serverless.yml — P17 |
| CloudWatch API calls para métricas | Latencia extra + coste por llamada | EMF vía logs — P16 |
| CORS en Function URL + CORS en handler response | Headers duplicados → `Access-Control-Allow-Origin` tiene múltiples valores → error browser | Configurar CORS solo en Function URL, no en el handler |

---

## Convenciones de naming

```
Ficheros:         snake_case.ts  (fetch_orders_prestashop.ts)
Clases/tipos:     PascalCase     (HoldedService, StandardOrder)
Variables/métodos: camelCase     (idPedidoTienda, procesarPedido)
Constantes módulo: UPPER_SNAKE   (ENABLE_ACCOUNTING, ORDER_PAID_STATE_ID)
Campos DynamoDB:  snake_case ES  (id_pedido_tienda, estado_procesado)
Recursos AWS:     PascalCase EN  (OrdersTable, FetchOrdersPrestashop)
```

**Idioma:** Español para dominio de negocio (pedido, factura, cuenta).
Inglés para infraestructura AWS (handler, service, table).

---

## Relaciones

- [[architecture-decision-tree]] — cuándo usar Lambda Function URL vs Step Functions
- [[idempotencia-dynamodb]] — detalle del patrón ConditionalCheck (P7)
- [[degradacion-silenciosa]] — detalle del nivel 3 de error handling (P3)
- [[patron-3-tiers]] — detalle del gate de feature opcional (P9)
- [[serverless-framework-v3]] — IaC para desplegar estas Lambdas
- [[prestashop-holded-middleware-prod]] — proyecto donde todos estos patrones están activos

## Proyectos donde aparece

- [[prestashop-holded-middleware-prod]] — todos los patrones validados en producción
