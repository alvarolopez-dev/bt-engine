---
tags: [typescript, errores, lambda, taxonomy, pino]
created: 2026-05-29
confidence: "high — patrón derivado de errores reales en producción"
---

# Error taxonomy bt-engine

#typescript #errores #lambda #taxonomy

[[index]] [[handler-structure]] [[lambda-patterns]]

Clases de error estructuradas para el ecosistema bt-engine.
Permite distinguir tipos de fallo programáticamente — sin parsear strings.

---

## El problema con errores genéricos

```typescript
// Actual — todo es Error genérico
throw new Error('CONFIG_ERROR: DYNAMODB_TABLE_ORDERS no definida');
throw new Error('VALIDATION_ERROR: total_pagado debe ser positivo');
throw new Error('Holded API error: 429 Too Many Requests');

// En el catch: imposible distinguir tipos sin parsear el message
} catch (error: unknown) {
  const msg = error instanceof Error ? error.message : String(error);
  // ¿Es un error de config? ¿De validación? ¿De API externa?
  // Solo se puede saber haciendo: msg.includes('CONFIG_ERROR')  ← frágil
}
```

---

## Clase base

```typescript
// src/lib/errors.ts

export class BtEngineError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly context: Record<string, unknown> = {}
  ) {
    super(message);
    this.name = this.constructor.name;
    // Mantiene el stack trace correcto en V8 (Node.js)
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, this.constructor);
    }
  }
}
```

---

## Subclases

### ConfigError — variables de entorno o configuración faltante

```typescript
export class ConfigError extends BtEngineError {
  constructor(varName: string, details?: string) {
    super(
      `CONFIG_ERROR: ${varName} no está definida${details ? ` — ${details}` : ''}`,
      'CONFIG_ERROR',
      { varName }
    );
  }
}

// Uso — reemplaza throws manuales con string
if (!process.env.DYNAMODB_TABLE_ORDERS) {
  throw new ConfigError('DYNAMODB_TABLE_ORDERS');
}
if (!process.env.HOLDED_API_KEY) {
  throw new ConfigError('HOLDED_API_KEY', 'Requerida para crear facturas en Holded');
}
```

**Comportamiento esperado:** error fatal → interrumpe handler → Step Functions Catch → SNS alerta → intervención humana.

---

### ValidationError — payload inválido en la frontera

```typescript
import { z } from 'zod';

export class ValidationError extends BtEngineError {
  constructor(schema: string, issues: z.ZodIssue[]) {
    const formatted = issues.map(i => `[${i.path.join('.')}] ${i.message}`).join(' | ');
    super(
      `VALIDATION_ERROR en ${schema}: ${formatted}`,
      'VALIDATION_ERROR',
      { schema, issues: formatted }
    );
  }
}

// Uso — desde safeParse
const result = StandardOrderSchema.safeParse(rawData);
if (!result.success) {
  throw new ValidationError('StandardOrderSchema', result.error.issues);
}
```

**Comportamiento esperado:** en batch → error de ítem (no fatal), se loguea y continúa.
En webhook → respuesta 400.

---

### ExternalApiError — API de plataforma externa falla

```typescript
export class ExternalApiError extends BtEngineError {
  constructor(
    platform: string,
    statusCode: number,
    endpoint: string,
    responseBody?: string
  ) {
    super(
      `EXTERNAL_API_ERROR: ${platform} respondió ${statusCode} en ${endpoint}`,
      'EXTERNAL_API_ERROR',
      { platform, statusCode, endpoint, responseBody }
    );
  }
}

// Uso — en service wrappers
async crearFactura(payload: HoldedInvoicePayload): Promise<string> {
  const response = await this.client.post('/invoicing/v2/invoices', payload);
  if (response.status >= 400) {
    throw new ExternalApiError(
      'Holded',
      response.status,
      '/invoicing/v2/invoices',
      JSON.stringify(response.data)
    );
  }
  return response.data.id;
}
```

**Comportamiento por código HTTP:**
- `429` → axiosRetry hace 3 reintentos con backoff exponencial antes de llegar aquí
- `5xx` → igual — axiosRetry primero
- `4xx` (exc. 429) → error de ítem, no reintenta (payload problema, no transient)

---

### DuplicateError — ConditionalCheck DynamoDB

```typescript
export class DuplicateError extends BtEngineError {
  constructor(entity: string, id: string) {
    super(
      `DUPLICATE: ${entity} ${id} ya existe — ignorando`,
      'DUPLICATE',
      { entity, id }
    );
  }
}

// Uso — en registrarPedido
} catch (error: unknown) {
  if (error instanceof ConditionalCheckFailedException) {
    throw new DuplicateError('pedido', pedido.id_pedido_tienda);
  }
  throw error;
}

// En el handler: DuplicateError NO es un error de ítem — es el mecanismo de idempotencia
try {
  await registrarPedido(pedido);
} catch (error: unknown) {
  if (error instanceof DuplicateError) {
    log.warn({ pedidoId: pedido.id_pedido_tienda }, 'Duplicado ignorado');
    saltados++;   // NO incrementar errores
    continue;     // continúa con el siguiente pedido
  }
  // Otros errores sí son errores de ítem
  const msg = error instanceof Error ? error.message : String(error);
  errores.push(`Pedido ${pedido.id_pedido_tienda}: ${msg}`);
}
```

---

### WebhookAuthError — firma HMAC inválida

```typescript
export class WebhookAuthError extends BtEngineError {
  constructor(platform: string, headerName: string) {
    super(
      `WEBHOOK_AUTH_ERROR: Firma inválida de ${platform} (header: ${headerName})`,
      'WEBHOOK_AUTH_ERROR',
      { platform, headerName }
    );
  }
}

// Uso — en middleware HMAC o handler webhook
if (!signaturesMatch) {
  throw new WebhookAuthError('Revo', 'X-Revo-Hmac-SHA256');
}

// En el handler de webhook: traducir a respuesta HTTP 401
} catch (error: unknown) {
  if (error instanceof WebhookAuthError) {
    log.warn({ platform: error.context.platform }, 'Webhook rechazado — firma inválida');
    return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }) };
  }
  throw error;
}
```

---

## Integración con pino — logging estructurado

```typescript
// src/lib/log-error.ts
import pino from 'pino';
import { BtEngineError } from './errors';

// Serializar BtEngineError para pino — incluye code y context además de message+stack
export function logError(log: pino.Logger, error: unknown, msg: string): void {
  if (error instanceof BtEngineError) {
    log.error(
      {
        errorCode:    error.code,
        errorMessage: error.message,
        errorContext: error.context,
        stack:        error.stack,
      },
      msg
    );
  } else if (error instanceof Error) {
    log.error({ errorMessage: error.message, stack: error.stack }, msg);
  } else {
    log.error({ errorRaw: String(error) }, msg);
  }
}

// Uso en handler:
} catch (error: unknown) {
  logError(log, error, 'Error procesando pedido');
  errores.push(error instanceof Error ? error.message : String(error));
}
```

**CloudWatch output con `BtEngineError`:**
```json
{
  "level": "error",
  "errorCode": "EXTERNAL_API_ERROR",
  "errorMessage": "EXTERNAL_API_ERROR: Holded respondió 429 en /invoicing/v2/invoices",
  "errorContext": { "platform": "Holded", "statusCode": 429 },
  "msg": "Error procesando pedido"
}
```

**CloudWatch output con Error genérico:**
```json
{
  "level": "error",
  "errorMessage": "Cannot read properties of undefined",
  "msg": "Error procesando pedido"
}
```

Diferencia: con `BtEngineError` puedes hacer CloudWatch Insights queries por `errorCode`.

---

## instanceof guards — orden correcto

```typescript
// Orden: de más específico a más general
} catch (error: unknown) {
  if (error instanceof DuplicateError) {
    saltados++;
    continue;  // no es un error real
  }
  if (error instanceof WebhookAuthError) {
    return { statusCode: 401, body: 'Unauthorized' };
  }
  if (error instanceof ValidationError) {
    log.warn({ issues: error.context.issues }, 'Payload inválido');
    errores.push(error.message);
    continue;
  }
  if (error instanceof ExternalApiError) {
    log.error({ platform: error.context.platform, status: error.context.statusCode }, 'API externa falló');
    errores.push(error.message);
    continue;
  }
  if (error instanceof ConfigError) {
    // Fatal — re-throw para que Step Functions lo capture
    throw error;
  }
  // Error desconocido — también fatal
  throw error;
}
```

---

## Tabla resumen

| Clase | Code | Fatal | Log level | Acción en handler |
|-------|------|-------|-----------|-------------------|
| `ConfigError` | `CONFIG_ERROR` | Sí | `error` | re-throw → Step Functions Catch |
| `ValidationError` | `VALIDATION_ERROR` | No | `warn` | push a errores, continúa batch |
| `ExternalApiError` | `EXTERNAL_API_ERROR` | No | `error` | push a errores, continúa batch |
| `DuplicateError` | `DUPLICATE` | No | `warn` | saltados++, no es error |
| `WebhookAuthError` | `WEBHOOK_AUTH_ERROR` | No | `warn` | responde 401, no re-throw |

---

## Anti-patrones

| Anti-patrón | Problema | Corrección |
|---|---|---|
| `msg.includes('CONFIG_ERROR')` | Frágil — un cambio de mensaje rompe la lógica | `error instanceof ConfigError` |
| `throw new Error('DUPLICATE: ...')` | No distinguible sin parsear | `throw new DuplicateError(entity, id)` |
| Mismo catch para todos los errores | DuplicateError y ExternalApiError necesitan comportamiento distinto | Múltiples instanceof guards |
| Log.error para DuplicateError | Es un evento esperado — ruido en CloudWatch | `log.warn` + `saltados++` |

---

## Relaciones

- [[handler-structure]] — los 3 niveles de error handling
- [[lambda-patterns]] P3 — jerarquía de errores (Nivel 1/2/3)
- [[zod-validation]] — `ValidationError` se lanza desde `safeParse` failures
- [[middleware-lambda]] — `WebhookAuthError` se lanza desde `withHmac*`
- [[dynamodb-patterns]] Regla 3 — `DuplicateError` desde ConditionalCheck
