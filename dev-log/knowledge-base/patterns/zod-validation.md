---
tags: [typescript, zod, validacion, lambda, boundary]
created: 2026-05-29
confidence: "high — patrón activo en prestashop-holded-middleware-prod"
---

# Zod — Validación en la frontera

#typescript #zod #validacion #lambda

[[index]] [[lambda-patterns]] [[handler-structure]]

Validar solo donde llegan datos externos al sistema. Adentro, los tipos TypeScript son de confianza.

---

## Principio de frontera

```
Sistema bt-engine
┌─────────────────────────────────────────────────────────────┐
│  SQS body ──► VALIDAR AQUÍ (zod)                           │
│  Webhook body ─► VALIDAR AQUÍ (zod)                         │
│  API response ─► VALIDAR AQUÍ (zod)                         │
│                                                             │
│  Todo lo de aquí adentro: TypeScript strict confía el tipo  │
└─────────────────────────────────────────────────────────────┘
```

**Regla:** Una vez que `safeParse` o `parse` tiene éxito, no vuelves a validar el mismo dato.
Validar dentro del sistema = desconfianza del propio código = over-engineering.

---

## Derivar el tipo TypeScript del schema

```typescript
import { z } from 'zod';

// Define el schema — la fuente de verdad
const StandardOrderSchema = z.object({
  id_pedido_tienda:  z.string().min(1),
  total_pagado:      z.coerce.number().positive('El total pagado debe ser positivo'),
  metodo_pago:       z.string(),
  lineas:            z.array(z.object({
    sku:             z.string(),
    cantidad:        z.coerce.number().int('La cantidad debe ser entera'),
    precio_unitario: z.coerce.number(),
  })),
  fecha_pedido:      z.string().datetime({ offset: true }),
});

// Deriva el tipo — no duplicar con una interface separada
type StandardOrder = z.infer<typeof StandardOrderSchema>;
// Equivale exactamente a:
// { id_pedido_tienda: string; total_pagado: number; metodo_pago: string; lineas: { sku: string; cantidad: number; precio_unitario: number; }[]; fecha_pedido: string; }
```

**Regla:** Nunca declarar `type StandardOrder = { ... }` por separado si existe `StandardOrderSchema`.
`z.infer<>` evita que el tipo y el schema queden desincronizados.

---

## safeParse vs parse

```typescript
// parse — lanza ZodError si falla
// Usar cuando el fallo debe interrumpir el flujo (error fatal)
const pedido = StandardOrderSchema.parse(rawData);
// Si falla: lanza ZodError → handler lo recibe como error de ítem → log.error → continúa batch

// safeParse — devuelve { success, data } o { success: false, error }
// Usar cuando quieres formatear el error (log estructurado, respuesta 400, etc.)
const resultado = StandardOrderSchema.safeParse(rawData);
if (!resultado.success) {
  const issues = resultado.error.issues.map(i => `${i.path.join('.')}: ${i.message}`).join(' | ');
  log.warn({ issues, rawData }, 'Payload inválido — descartando');
  return { statusCode: 400, body: JSON.stringify({ error: issues }) };
}
const pedido = resultado.data; // StandardOrder — garantizado
```

**Cuándo usar cada uno:**

| Situación | Función |
|-----------|---------|
| SQS consumer — payload corrupto = fallo de ítem | `parse` — lanza, se añade a `batchItemFailures` |
| Webhook — payload inválido = responder 400 | `safeParse` — formatea y responde |
| API response — campo inesperado = log + continuar | `safeParse` — degradación silenciosa |
| Env var — falta = error fatal config | `parse` — interrumpe proceso completo |

---

## Schema para webhook x-www-form-urlencoded (Revo)

```typescript
// qs.parse() devuelve Record<string, string | string[]> — todo como strings
// z.coerce convierte strings a number/boolean donde sea necesario

const RevoOrderClosedSchema = z.object({
  event:        z.literal('order.closed'),           // solo este evento
  order_id:     z.string().min(1),
  client_token: z.string().min(1),                   // campo obligatorio (gotcha #1)
  tenant:       z.string().optional(),
}).passthrough();                                    // otros campos Revo → ignorar, no rechazar

type RevoOrderClosed = z.infer<typeof RevoOrderClosedSchema>;

// En el handler:
const parsed = qs.parse(rawBody.toString('utf8'));
const result = RevoOrderClosedSchema.safeParse(parsed);
```

**Por qué `.passthrough()`:** Revo añade campos sin previo aviso. `.strict()` rompería el webhook
con cada campo nuevo de Revo. `.passthrough()` los conserva sin romper; `.strip()` (default) los ignora.

---

## Schema para respuesta API externa (campos desconocidos)

```typescript
// Holded API — solo nos importan algunos campos; el resto puede variar
const HoldedContactResponseSchema = z.object({
  id:    z.string(),
  name:  z.string(),
  email: z.string().email().optional(),
  nif:   z.string().optional(),
}).passthrough(); // campos adicionales de Holded → preservar sin romper

// Paginated list response
const HoldedContactListSchema = z.object({
  data:  z.array(HoldedContactResponseSchema),
  total: z.number().optional(),
  page:  z.number().optional(),
});
```

---

## Coerción — form-data y query params

```typescript
// x-www-form-urlencoded entrega TODO como string
// z.coerce convierte automáticamente: "42" → 42, "true" → true

const WebhookQuerySchema = z.object({
  page:     z.coerce.number().int().min(1).default(1),
  limit:    z.coerce.number().int().min(1).max(100).default(50),
  desde:    z.coerce.date(),                     // "2026-05-01" → Date
  activo:   z.coerce.boolean().default(true),    // "true" → true
  ids:      z.union([
    z.string().transform(s => s.split(',')),     // "1,2,3" → ["1","2","3"]
    z.array(z.string()),
  ]),
});
```

---

## Schema para mensaje SQS (Lambda B consumer)

```typescript
// Lambda A encola con JSON.stringify — Lambda B recibe record.body: string
const SqsOrderMessageSchema = z.object({
  orderId:      z.string().min(1),
  tenant:       z.string(),
  receivedAt:   z.string().datetime({ offset: true }),
  source:       z.enum(['revo-xef', 'revo-retail', 'stripe', 'woocommerce']),
});

type SqsOrderMessage = z.infer<typeof SqsOrderMessageSchema>;

// En Lambda B:
for (const record of event.Records) {
  try {
    const msg = SqsOrderMessageSchema.parse(JSON.parse(record.body));
    await procesarPedido(msg);
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    log.error({ messageId: record.messageId, error: msg }, 'Mensaje SQS inválido o error');
    batchItemFailures.push({ itemIdentifier: record.messageId });
  }
}
```

---

## Formatear errores Zod para pino

```typescript
// Evitar log de ZodError raw (verbose, difícil de leer en CloudWatch)
function formatZodError(error: z.ZodError): string {
  return error.issues
    .map(issue => `[${issue.path.join('.')}] ${issue.message}`)
    .join(' | ');
}

// Uso:
const result = StandardOrderSchema.safeParse(raw);
if (!result.success) {
  log.warn(
    { issues: formatZodError(result.error), rawKeys: Object.keys(raw) },
    'Validación fallida en frontera'
  );
}
// CloudWatch log: { "issues": "[total_pagado] Expected number | [lineas.0.sku] Required", "rawKeys": [...] }
```

---

## Donde poner los schemas

```
src/
├── schemas/
│   ├── order.schema.ts       ← StandardOrderSchema, z.infer<> types
│   ├── revo.schema.ts        ← RevoOrderClosedSchema
│   └── sqs.schema.ts         ← SqsOrderMessageSchema
├── handlers/
│   ├── webhook_receiver.ts   ← importa revo.schema + sqs.schema
│   └── order_processor.ts   ← importa order.schema
```

**Regla:** Un schema por entidad, no un schema por handler.
`StandardOrderSchema` es la misma en Lambda A, Lambda B y en tests.

---

## Anti-patrones

| Anti-patrón | Problema | Corrección |
|---|---|---|
| `z.any()` en campos de negocio | Zod sin tipado = inútil | Tipos específicos o `.passthrough()` |
| Validar dentro del handler después de la frontera | Over-engineering — el tipo ya está garantizado | Solo validar en la frontera |
| Type assertion `as StandardOrder` sin validar | Runtime crash si datos no coinciden | `safeParse` o `parse` antes del cast |
| Schema duplicado con la interface TypeScript | Los dos se desincronizarán | Solo `z.infer<typeof Schema>` |
| `.strict()` en respuestas de API externas | Rompe con cada campo nuevo de la API | `.strip()` (default) o `.passthrough()` |

---

## Relaciones

- [[handler-structure]] — validación en el Paso 1 del handler (frontera)
- [[lambda-patterns]] P15 — uso de zod en SQS typed handler
- [[developer-style]] — `safeParse` básico en la guía de estilo
- [[error-taxonomy]] — `ValidationError` cuando zod falla en frontera
