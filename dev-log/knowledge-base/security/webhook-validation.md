---
tags: [security, webhooks, validacion, firma, hmac]
created: 2026-05-25
source: "10_agent_security.md + documentación oficial de cada plataforma"
---

# Validación de webhooks — código por plataforma

#security #webhooks #hmac #firma

Regla absoluta: **validar firma ANTES de procesar el payload. Siempre.**
Si la firma no es válida → responder 401 inmediatamente. No loguear el payload. No procesar nada.

El error más común: parsear el body como JSON antes de validar la firma.
Stripe, Shopify y WooCommerce usan el raw body (Buffer) para calcular el HMAC.
Parsear a JSON primero → firma inválida siempre → bypass accidental de seguridad.

---

## Patrón base — AWS Lambda con raw body

En Lambda (API Gateway o Function URL), el body llega como string base64 o string directo.
Para HMAC-SHA256 necesitas el raw body como Buffer:

```typescript
// handler de webhook — patrón base
import { APIGatewayProxyEventV2, APIGatewayProxyResultV2 } from 'aws-lambda';
import crypto from 'crypto';

export const main = async (event: APIGatewayProxyEventV2): Promise<APIGatewayProxyResultV2> => {
  // 1. Obtener raw body ANTES de cualquier parseo
  const rawBody = event.isBase64Encoded
    ? Buffer.from(event.body ?? '', 'base64')
    : Buffer.from(event.body ?? '', 'utf-8');

  // 2. Validar firma (específico por plataforma — ver secciones abajo)
  const isValid = validateSignature(rawBody, event.headers);
  if (!isValid) {
    return { statusCode: 401, body: 'Invalid signature' };
  }

  // 3. SOLO AQUÍ parsear el payload
  const payload = JSON.parse(rawBody.toString('utf-8'));

  // 4. Procesar
  // ...
};
```

---

## Stripe

**Documentación:** https://stripe.com/docs/webhooks/signatures

### Cabeceras relevantes

```
Stripe-Signature: t=1714000000,v1=abc123...,v0=xyz...
```

### Código de validación

```typescript
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2024-04-10',
});

function validateStripeWebhook(
  rawBody: Buffer,
  headers: Record<string, string | undefined>,
  webhookSecret: string
): Stripe.Event {
  const signature = headers['stripe-signature'];
  if (!signature) throw new Error('Missing Stripe-Signature header');

  // stripe.webhooks.constructEvent valida firma Y anti-replay (300s window)
  // Lanza StripeSignatureVerificationError si la firma no es válida
  return stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);
}

// En el handler:
export const main = async (event: APIGatewayProxyEventV2) => {
  const rawBody = event.isBase64Encoded
    ? Buffer.from(event.body ?? '', 'base64')
    : Buffer.from(event.body ?? '', 'utf-8');

  let stripeEvent: Stripe.Event;
  try {
    stripeEvent = validateStripeWebhook(rawBody, event.headers, process.env.STRIPE_WEBHOOK_SECRET!);
  } catch (err) {
    log.warn({ err }, 'Stripe webhook signature invalid');
    return { statusCode: 401, body: 'Invalid signature' };
  }

  // Procesar stripeEvent según stripeEvent.type
};
```

### Gotchas Stripe

- `constructEvent` incluye anti-replay de 300 segundos — no implementar manualmente
- El webhook secret (`whsec_...`) es diferente por endpoint — no reutilizar el de producción en staging
- Los eventos de Stripe pueden llegar duplicados — idempotencia obligatoria (ver [[idempotencia-dynamodb]])
- `v0` en el header es legacy — usar `v1`

---

## Shopify

**Documentación:** https://shopify.dev/docs/apps/build/webhooks/secure/validate-webhooks

### Cabeceras relevantes

```
X-Shopify-Hmac-SHA256: base64(HMAC-SHA256(secret, rawBody))
X-Shopify-Topic: orders/create
X-Shopify-Shop-Domain: myshop.myshopify.com
```

### Código de validación

```typescript
import crypto from 'crypto';

function validateShopifyWebhook(
  rawBody: Buffer,
  headers: Record<string, string | undefined>,
  webhookSecret: string
): boolean {
  const receivedHmac = headers['x-shopify-hmac-sha256'];
  if (!receivedHmac) return false;

  const expectedHmac = crypto
    .createHmac('sha256', webhookSecret)
    .update(rawBody)
    .digest('base64');

  // timingSafeEqual previene timing attacks
  return crypto.timingSafeEqual(
    Buffer.from(receivedHmac, 'base64'),
    Buffer.from(expectedHmac, 'base64')
  );
}

// En el handler:
const rawBody = event.isBase64Encoded
  ? Buffer.from(event.body ?? '', 'base64')
  : Buffer.from(event.body ?? '', 'utf-8');

if (!validateShopifyWebhook(rawBody, event.headers, process.env.SHOPIFY_WEBHOOK_SECRET!)) {
  return { statusCode: 401, body: 'Invalid signature' };
}

const payload = JSON.parse(rawBody.toString('utf-8'));
```

### Gotchas Shopify

- El secret es por webhook registrado — Shopify genera uno diferente para cada suscripción
- Shopify rota el secret al año — documentar fecha de renovación
- `X-Shopify-Shop-Domain` permite filtrar por tienda si recibes webhooks de múltiples shops

---

## WooCommerce

**Documentación:** https://woocommerce.github.io/woocommerce-rest-api-docs/#webhooks

### Cabeceras relevantes

```
X-WC-Webhook-Signature: base64(HMAC-SHA256(secret, rawBody))
X-WC-Webhook-Topic: order.created
X-WC-Webhook-Source: https://mitienda.com
```

### Código de validación

```typescript
import crypto from 'crypto';

function validateWooCommerceWebhook(
  rawBody: Buffer,
  headers: Record<string, string | undefined>,
  webhookSecret: string
): boolean {
  const receivedSignature = headers['x-wc-webhook-signature'];
  if (!receivedSignature) return false;

  const expectedSignature = crypto
    .createHmac('sha256', webhookSecret)
    .update(rawBody)
    .digest('base64');

  return crypto.timingSafeEqual(
    Buffer.from(receivedSignature, 'base64'),
    Buffer.from(expectedSignature, 'base64')
  );
}
```

### Gotchas WooCommerce

- El secret se configura manualmente en WooCommerce admin → WooCommerce → Settings → Advanced → Webhooks
- WooCommerce requiere que el endpoint responda 200 en < 5 segundos — procesar async si la lógica es lenta
- Prerequisito: WordPress permalinks deben estar en "Post name" o similar — no "Plain" (ver [[woocommerce]] gotchas)
- Timezone de los timestamps en el payload es la del sitio WordPress — no UTC

---

## Revo XEF / Revo Retail

**Documentación:** docs oficiales Revo (acceso privado)

Revo no usa HMAC — usa autenticación por header custom.

### Revo XEF

```typescript
function validateRevoXEFWebhook(
  headers: Record<string, string | undefined>,
  expectedToken: string
): boolean {
  const authHeader = headers['authorization'] ?? headers['x-revo-token'];
  if (!authHeader) return false;

  // timingSafeEqual para prevenir timing attacks
  return crypto.timingSafeEqual(
    Buffer.from(authHeader),
    Buffer.from(expectedToken)
  );
}
```

### Revo Retail

```typescript
function validateRevoRetailWebhook(
  headers: Record<string, string | undefined>,
  username: string,    // header 'username' ≠ tenant — ver gotcha Revo Retail
  expectedToken: string
): boolean {
  const receivedUsername = headers['username'];
  const receivedToken = headers['authorization'] ?? headers['x-api-key'];

  if (!receivedUsername || !receivedToken) return false;

  const usernameValid = crypto.timingSafeEqual(
    Buffer.from(receivedUsername),
    Buffer.from(username)
  );
  const tokenValid = crypto.timingSafeEqual(
    Buffer.from(receivedToken),
    Buffer.from(expectedToken)
  );

  return usernameValid && tokenValid;
}
```

### Gotchas Revo

- Revo no tiene webhooks outbound en todos los productos — verificar en [[revo-xef]] y [[revo-retail]]
- Revo XEF: sin webhooks nativos (polling necesario) — no aplica validación de firma
- Revo Retail: el header `username` es el username de la cuenta, no el tenant ID
- Si Revo no tiene webhooks → validar autenticación de los requests de polling (API key en header)

---

## Zoho CRM

**Documentación:** https://www.zoho.com/crm/developer/docs/api/v7/notifications/overview.html

Zoho CRM usa un token de verificación en el payload, no HMAC.

### Cabeceras / payload relevantes

```json
{
  "token": "tu-token-de-verificacion",
  "channel_id": "1234567890",
  "event": "Leads.create",
  "data": { ... }
}
```

### Código de validación

```typescript
interface ZohoWebhookPayload {
  token: string;
  channel_id: string;
  event: string;
  data: unknown;
}

function validateZohoWebhook(
  payload: ZohoWebhookPayload,
  expectedToken: string
): boolean {
  if (!payload.token) return false;

  return crypto.timingSafeEqual(
    Buffer.from(payload.token),
    Buffer.from(expectedToken)
  );
}

// En el handler — Zoho envía JSON directamente (no raw body para HMAC)
const payload = JSON.parse(rawBody.toString('utf-8')) as ZohoWebhookPayload;

if (!validateZohoWebhook(payload, process.env.ZOHO_WEBHOOK_TOKEN!)) {
  return { statusCode: 401, body: 'Invalid token' };
}
```

### Gotchas Zoho CRM

- Las notificaciones de Zoho expiran en 72 horas — requieren renovación automática (cron o EventBridge)
- Data center `.eu` para clientes en España — URL base: `https://www.zohoapis.eu/crm/v7/`
- El token se configura al crear la suscripción de notificaciones — guardar en Secrets Manager

---

## Business Central

**Documentación:** https://learn.microsoft.com/dynamics365/business-central/dev-itpro/api-reference/v2.0/

Business Central usa OAuth 2.0 o API key (Basic Auth) — no HMAC en webhooks.

### Webhooks (subscripciones)

Business Central llama al endpoint de validación inicial con `validationToken` en query param.

```typescript
export const main = async (event: APIGatewayProxyEventV2) => {
  // Paso 1: validación inicial de suscripción
  const validationToken = event.queryStringParameters?.validationToken;
  if (validationToken) {
    // BC envía validationToken — responder con el token en body, Content-Type text/plain
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'text/plain' },
      body: validationToken,
    };
  }

  // Paso 2: webhook real — validar que viene de BC
  // BC no firma el payload — validar por IP o por API key en header
  const apiKey = event.headers['x-api-key'] ?? event.headers['authorization'];
  if (apiKey !== process.env.BC_WEBHOOK_API_KEY) {
    return { statusCode: 401, body: 'Unauthorized' };
  }

  const payload = JSON.parse(event.body ?? '{}');
  // Procesar...
};
```

### Gotchas Business Central

- Las suscripciones expiran en 3 días — renovación automática obligatoria
- ETag/If-Match obligatorio en todas las mutaciones (PATCH/DELETE)
- Business Central puede enviar duplicados — idempotencia obligatoria
- La validación inicial con `validationToken` es el handshake de suscripción — no ignorar

---

## Tabla resumen

| Plataforma | Método | Raw body necesario | Anti-replay incluido |
|---|---|---|---|
| Stripe | HMAC-SHA256 | ✅ Sí — obligatorio | ✅ Sí (300s) |
| Shopify | HMAC-SHA256 | ✅ Sí — obligatorio | ❌ No — implementar si necesario |
| WooCommerce | HMAC-SHA256 | ✅ Sí — obligatorio | ❌ No |
| Revo XEF | Token header | ❌ No | ❌ No |
| Revo Retail | Token + username header | ❌ No | ❌ No |
| Zoho CRM | Token en payload | ❌ No (JSON directo) | ❌ No |
| Business Central | API key / OAuth | ❌ No | ❌ No |

---

## Principios transversales

**1 — timingSafeEqual siempre para comparar tokens/firmas**

```typescript
// MAL — vulnerable a timing attack
if (receivedHmac === expectedHmac) { ... }

// BIEN — tiempo constante
crypto.timingSafeEqual(Buffer.from(received), Buffer.from(expected))
```

**2 — Responder 401, no 403, en firma inválida**

- `401 Unauthorized`: credenciales ausentes o inválidas (correcto aquí)
- `403 Forbidden`: credenciales válidas pero sin permisos (no aplica en webhooks)

**3 — No loguear el payload si la firma falla**

```typescript
if (!isValid) {
  log.warn({ source: 'stripe-webhook' }, 'Invalid signature — payload not logged');
  return { statusCode: 401, body: 'Invalid signature' };
  // NO: log.warn({ payload }, ...) — podría ser un payload malicioso
}
```

**4 — Idempotencia post-validación**

Todos los webhooks pueden llegar duplicados. Una vez validada la firma:
→ Verificar si ya se procesó (ConditionalCheck DynamoDB)
→ Si ya existe → responder 200 sin re-procesar
Ver [[idempotencia-dynamodb]]

---

## Relaciones

- [[checklist-pre-deploy]] — Capa 2 del checklist
- [[idempotencia-dynamodb]] — manejo de duplicados post-validación
- [[revo-xef]], [[revo-retail]], [[shopify]], [[woocommerce]], [[zoho-crm]], [[business-central]] — gotchas por plataforma
- [[lambda-patterns]] — P6 (retry), estructura de handlers

*Última actualización: 2026-05-25*
