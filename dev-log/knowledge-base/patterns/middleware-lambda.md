---
tags: [typescript, middleware, lambda, webhook, composicion]
created: 2026-05-29
confidence: "medium — patrón propuesto, no activo en producción aún"
---

# Middleware pattern — Lambda webhook handlers

#typescript #middleware #lambda #webhook

[[index]] [[handler-structure]] [[zod-validation]]

Compose pattern ligero para webhooks. Sin dependencias externas. Type-safe.
**Solo para webhooks** — polling handlers (Step Functions) no necesitan este patrón.

---

## El problema

Cada webhook handler repite el mismo código de seguridad:

```typescript
// webhook_receiver_revo.ts
export const main = async (event: APIGatewayProxyEventV2) => {
  await cargarSecretos();
  const rawBody = event.isBase64Encoded
    ? Buffer.from(event.body!, 'base64')
    : Buffer.from(event.body!, 'utf8');
  const sig = event.headers['x-revo-hmac-sha256'] ?? '';
  if (!validarHmac(rawBody, sig, process.env.REVO_WEBHOOK_SECRET!)) {
    return { statusCode: 401, body: 'Unauthorized' };
  }
  const payload = qs.parse(rawBody.toString('utf8'));
  // ... lógica específica de Revo
};

// webhook_receiver_stripe.ts — exactamente el mismo boilerplate
// webhook_receiver_woocommerce.ts — exactamente el mismo boilerplate
```

Con 5+ webhook handlers: 5 copias del código de HMAC validation.
Si hay un bug en la validación, hay que corregirlo en 5 sitios.

---

## La solución: compose

```typescript
// src/lib/middleware.ts

import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';

export type WebhookEvent = APIGatewayProxyEventV2 & {
  _rawBody?: Buffer;  // añadido por withRawBody
  _parsed?: unknown;  // añadido por withParsedBody
};

export type WebhookHandler = (event: WebhookEvent) => Promise<APIGatewayProxyResultV2>;
export type Middleware = (handler: WebhookHandler) => WebhookHandler;

// Compose: aplica middlewares de derecha a izquierda (el primero en la lista = más externo)
export function compose(...middlewares: Middleware[]): Middleware {
  return (handler) =>
    middlewares.reduceRight((next, mw) => mw(next), handler);
}
```

---

## Middlewares pre-construidos

### withSecrets — cargar secretos una vez

```typescript
// src/lib/middlewares/with-secrets.ts
import { cargarSecretos } from '../secrets.service';

export const withSecrets: Middleware = (handler) => async (event) => {
  await cargarSecretos();
  return handler(event);
};
```

### withRawBody — extraer body como Buffer (ANTES de parsear)

```typescript
// src/lib/middlewares/with-raw-body.ts
// CRÍTICO: el Buffer debe extraerse ANTES de cualquier parse para HMAC
export const withRawBody: Middleware = (handler) => async (event) => {
  const rawBody = event.body
    ? event.isBase64Encoded
      ? Buffer.from(event.body, 'base64')
      : Buffer.from(event.body, 'utf8')
    : Buffer.alloc(0);
  return handler({ ...event, _rawBody: rawBody });
};
```

### withHmacRevo — validar firma Revo XEF/Retail

```typescript
// src/lib/middlewares/with-hmac-revo.ts
import crypto from 'crypto';

export const withHmacRevo: Middleware = (handler) => async (event) => {
  const secret = process.env.REVO_WEBHOOK_SECRET!;
  const received = event.headers['x-revo-hmac-sha256'] ?? '';
  const rawBody = event._rawBody ?? Buffer.alloc(0);

  const expected = crypto
    .createHmac('sha256', secret)
    .update(rawBody)
    .digest('hex');

  // timingSafeEqual requiere buffers del mismo tamaño
  const ok =
    received.length === expected.length &&
    crypto.timingSafeEqual(
      Buffer.from(received, 'utf8'),
      Buffer.from(expected, 'utf8')
    );

  if (!ok) {
    log.warn({ receivedLength: received.length }, 'HMAC inválido — rechazando webhook');
    return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }) };
  }

  return handler(event);
};
```

### withFormBody — parsear x-www-form-urlencoded

```typescript
// src/lib/middlewares/with-form-body.ts
import qs from 'qs';

export const withFormBody: Middleware = (handler) => async (event) => {
  const rawBody = event._rawBody ?? Buffer.alloc(0);
  const parsed = qs.parse(rawBody.toString('utf8'));
  return handler({ ...event, _parsed: parsed });
};
```

---

## Uso en webhook handler

```typescript
// src/handlers/webhook_receiver.ts
import { compose, withSecrets, withRawBody, withHmacRevo, withFormBody } from '../lib/middleware';
import { RevoOrderClosedSchema } from '../schemas/revo.schema';
import { SqsOrderMessageSchema } from '../schemas/sqs.schema';

const handler: WebhookHandler = async (event) => {
  // event._parsed ya está disponible — validado por zod
  const result = RevoOrderClosedSchema.safeParse(event._parsed);
  if (!result.success) {
    log.warn({ issues: formatZodError(result.error) }, 'Payload Revo inválido');
    return { statusCode: 400, body: JSON.stringify({ error: 'Bad Request' }) };
  }

  const { order_id, client_token } = result.data;

  await sqsClient.send(new SendMessageCommand({
    QueueUrl: process.env.SQS_QUEUE_URL!,
    MessageBody: JSON.stringify({
      orderId: order_id,
      tenant: client_token,
      receivedAt: new Date().toISOString(),
      source: 'revo-xef',
    } satisfies SqsOrderMessage),
  }));

  return { statusCode: 200, body: 'OK' };
};

// Composición — el orden importa: secrets → rawBody → hmac → parse → handler
export const main = compose(
  withSecrets,
  withRawBody,
  withHmacRevo,
  withFormBody,
)(handler);
```

**Ventaja:** añadir un nuevo webhook handler Stripe solo requiere:
```typescript
export const main = compose(withSecrets, withRawBody, withHmacStripe, withJsonBody)(handler);
```

---

## Orden de middlewares (regla fija)

```
withSecrets      ← 1º siempre — necesario para leer REVO_WEBHOOK_SECRET
withRawBody      ← 2º siempre — Buffer ANTES de parsear (R-SEC-2)
withHmac*        ← 3º siempre — validar firma sobre raw body
withFormBody     ← 4º — solo si x-www-form-urlencoded
withJsonBody     ← 4º — solo si application/json
handler          ← 5º — lógica específica del webhook
```

**Nunca cambiar el orden de los 3 primeros.** Si HMAC se evalúa después de parsear,
el body puede haber sido modificado y la firma no coincide.

---

## Cuándo NO usar middleware

| Situación | Por qué no |
|-----------|------------|
| Lambda polling (Step Functions) | No hay webhook, no hay HMAC. Usar anatomía R-CODE-2 directamente |
| Lambda SQS consumer | SQS gestiona autenticación. Solo `cargarSecretos()` + guard |
| Lambda de utilidad interna | No hay frontera externa. Middleware innecesario |

---

## Testear middlewares por separado

```typescript
// test: with-hmac-revo.test.ts
describe('withHmacRevo', () => {
  it('acepta firma válida', async () => {
    const body = Buffer.from('event=order.closed&order_id=123');
    const secret = 'test-secret';
    const sig = crypto.createHmac('sha256', secret).update(body).digest('hex');

    const mockHandler = jest.fn().mockResolvedValue({ statusCode: 200, body: 'OK' });
    const wrapped = withHmacRevo(mockHandler);

    const result = await wrapped({
      _rawBody: body,
      headers: { 'x-revo-hmac-sha256': sig },
    } as WebhookEvent);

    expect(result.statusCode).toBe(200);
    expect(mockHandler).toHaveBeenCalledTimes(1);
  });

  it('rechaza firma inválida', async () => {
    const wrapped = withHmacRevo(jest.fn());
    const result = await wrapped({
      _rawBody: Buffer.from('tampered body'),
      headers: { 'x-revo-hmac-sha256': 'bad-sig' },
    } as WebhookEvent);

    expect(result.statusCode).toBe(401);
  });
});
```

**Beneficio clave:** cada middleware testeable de forma aislada.
Sin middleware, el HMAC está enterrado en el handler = solo testeable con mocks del evento completo.

---

## Relaciones

- [[handler-structure]] — anatomía R-CODE-2 para handlers no-webhook
- [[zod-validation]] — validación del payload dentro del handler después del middleware
- [[lambda-patterns]] P7 — HMAC validation detalle
- [[security/webhook-validation]] — checklist de seguridad para webhooks
