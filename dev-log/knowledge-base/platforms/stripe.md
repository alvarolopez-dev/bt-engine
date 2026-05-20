---
tags: [plataforma, stripe, pagos, payment-gateway]
created: 2026-05-20
auth_verified_date: 2026-05-20
auth_source: "official docs — stripe.com/docs/api + stripe.com/docs/webhooks"
auth_discrepancy: false
---

# Stripe — Perfil de integración

#stripe #plataforma #pagos #payment-gateway

Payment gateway global líder. Usado tanto en modo directo (cobros propios) como en modo plataforma (Connect).
Integración relevante: Stripe → [[holded]] (eventos de pago confirmado → facturas).

```json
{
  "platform": "Stripe",
  "versions_validated": ["2024-06-20", "2023-10-16"],
  "confidence": "high",
  "source": "[oficial — stripe.com/docs/api — 2026-05-20 (conocimiento entrenamiento)]",

  "auth": {
    "method": "API Key via HTTP Basic Auth o header Authorization Bearer",
    "header_format": "Authorization: Bearer {sk_live_...}",
    "key_types": {
      "secret_key": {
        "prefix": "sk_live_",
        "uso": "Solo en servidor — nunca exponer en cliente. Para todas las llamadas API server-side.",
        "test_prefix": "sk_test_"
      },
      "publishable_key": {
        "prefix": "pk_live_",
        "uso": "Cliente (browser/app) — para tokenizar tarjetas con Stripe.js. No sirve para llamadas API.",
        "test_prefix": "pk_test_"
      },
      "restricted_key": {
        "prefix": "rk_live_",
        "uso": "API keys con permisos limitados por recurso — recomendado para integraciones específicas"
      },
      "webhook_secret": {
        "prefix": "whsec_",
        "uso": "Solo para validar firma de webhooks — no sirve para llamadas API"
      }
    },
    "idempotency": {
      "header": "Idempotency-Key",
      "valor": "UUID v4 único por intento de operación",
      "aplica_a": "Todas las peticiones POST",
      "warning": "Sin Idempotency-Key en POST, un reintento por timeout puede crear dos cargos o dos facturas"
    },
    "versioning_header": {
      "header": "Stripe-Version",
      "valor": "2024-06-20",
      "nota": "Si no se envía, Stripe usa la versión configurada en el dashboard de la cuenta. Fijar versión explícita en producción."
    },
    "source": "[oficial]"
  },

  "base_urls": {
    "api": "https://api.stripe.com/v1/",
    "webhook_test_cli": "stripe listen --forward-to localhost:3000/webhook",
    "dashboard": "https://dashboard.stripe.com",
    "test_dashboard": "https://dashboard.stripe.com/test",
    "warning": "No existe entorno de staging separado — se usa la misma API con claves sk_test_ para pruebas. Los objetos creados con sk_test_ son completamente independientes de sk_live_.",
    "source": "[oficial]"
  },

  "rate_limits": {
    "live_mode": {
      "read_per_second": 100,
      "write_per_second": 100
    },
    "test_mode": {
      "read_per_second": 25,
      "write_per_second": 25
    },
    "http_code_on_limit": "429 Too Many Requests",
    "header_retry": "Retry-After",
    "recommendation": "Implementar exponential backoff. En webhooks, procesar async para no bloquear endpoint.",
    "source": "[oficial]"
  },

  "pagination": {
    "type": "cursor-based (list API)",
    "param_limit": "limit",
    "param_after": "starting_after",
    "param_before": "ending_before",
    "default_limit": 10,
    "max_limit": 100,
    "response_shape": {
      "object": "list",
      "data": "array",
      "has_more": "boolean",
      "url": "string"
    },
    "patron_paginacion": "Si has_more === true, usar el id del último objeto en data como starting_after en la siguiente llamada",
    "warning": "No hay número de página ni total de registros — la paginación es estrictamente por cursor. No se puede saltar a página N.",
    "source": "[oficial]"
  },

  "date_format": {
    "format": "Unix timestamp en segundos (integer)",
    "ejemplo": 1716220800,
    "nota": "Igual que Holded — ambas APIs usan Unix timestamps en segundos. Conversión directa sin transformación.",
    "filtros_lista": {
      "created[gte]": "Unix timestamp inicio",
      "created[lte]": "Unix timestamp fin"
    },
    "source": "[oficial]"
  },

  "http_codes": {
    "200": "OK — operación exitosa (GET, POST, DELETE)",
    "400": "Bad Request — parámetros inválidos o faltantes",
    "401": "Unauthorized — API key inválida o ausente",
    "402": "Request Failed — parámetros válidos pero la operación falló (ej: tarjeta rechazada)",
    "403": "Forbidden — API key sin permisos para el recurso",
    "404": "Not Found — recurso no existe",
    "409": "Conflict — Idempotency-Key reutilizada con parámetros distintos",
    "429": "Too Many Requests — rate limit superado",
    "500": "Server Error — error interno de Stripe (raro, reintentar con backoff)",
    "warning": "402 es específico de Stripe para fallos de negocio (no HTTP genérico). Diferenciar 400 (bug) de 402 (lógica de negocio)."
  },

  "id_format": {
    "prefijos": {
      "pi_": "PaymentIntent",
      "in_": "Invoice",
      "cus_": "Customer",
      "ch_": "Charge",
      "re_": "Refund",
      "sub_": "Subscription",
      "si_": "SubscriptionItem",
      "pm_": "PaymentMethod",
      "cs_": "CheckoutSession",
      "evt_": "Event (webhook)",
      "prod_": "Product",
      "price_": "Price",
      "txn_": "BalanceTransaction"
    },
    "nota": "Los IDs son strings con prefijo fijo — útil para detectar el tipo de objeto sin hacer lookup"
  },

  "webhooks": {
    "available": true,
    "signature": {
      "header": "Stripe-Signature",
      "algorithm": "HMAC-SHA256",
      "formato_header": "t=TIMESTAMP,v1=HASH_HEX",
      "construccion_payload": "'{timestamp}.{raw_body}'",
      "secret_prefix": "whsec_",
      "replay_attack_protection": {
        "mecanismo": "El campo 't' contiene el Unix timestamp del envío. Stripe recomienda rechazar eventos con t > 300 segundos de antigüedad.",
        "tolerancia_default": 300,
        "warning": "Usar el raw body (bytes sin parsear) para validar la firma — si se parsea y re-serializa el JSON antes de validar, la firma no coincide aunque el contenido sea idéntico"
      }
    },
    "content_type": "application/json",
    "payload_shape": {
      "id": "evt_...",
      "object": "event",
      "type": "string (ej: payment_intent.succeeded)",
      "created": "Unix timestamp",
      "livemode": "boolean",
      "data": {
        "object": "el recurso Stripe completo (PaymentIntent, Invoice, etc.)"
      }
    },
    "retry_policy": {
      "intentos": "hasta 25 reintentos durante 3 días",
      "schedule": "exponential backoff — 5s, 1min, 5min, 30min, 2h, 5h, 10h...",
      "warning": "Si el endpoint devuelve cualquier código que no sea 2xx, Stripe lo considera fallo y reintenta. El endpoint DEBE responder 200 en < 30s — procesar async si el procesado es lento."
    },
    "config_url": "https://dashboard.stripe.com/webhooks",
    "cli_test": "stripe trigger payment_intent.succeeded",
    "eventos_clave": {
      "pagos": [
        "payment_intent.succeeded",
        "payment_intent.payment_failed",
        "payment_intent.canceled",
        "payment_intent.requires_action"
      ],
      "facturas": [
        "invoice.paid",
        "invoice.payment_failed",
        "invoice.created",
        "invoice.finalized"
      ],
      "checkout": [
        "checkout.session.completed",
        "checkout.session.expired"
      ],
      "reembolsos": [
        "charge.refunded",
        "charge.dispute.created"
      ],
      "suscripciones": [
        "customer.subscription.created",
        "customer.subscription.updated",
        "customer.subscription.deleted"
      ],
      "clientes": [
        "customer.created",
        "customer.updated",
        "customer.deleted"
      ]
    },
    "source": "[oficial]"
  },

  "endpoints_relevantes_holded": {
    "descripcion": "Endpoints clave para integración Stripe → Holded (pago confirmado → factura)",
    "currency_nota": "Todos los importes en centavos/cents (integer). EUR 10.00 → 1000. NUNCA decimales.",
    "endpoints": [
      {
        "name": "Crear PaymentIntent",
        "method": "POST",
        "path": "/v1/payment_intents",
        "body_fields": ["amount (cents, requerido)", "currency (requerido, ej: eur)", "customer (opcional)", "metadata (key-value libre)", "idempotency_key (header)"],
        "note": "Flujo moderno — sustituye a Charges. El cliente confirma en frontend con Stripe.js."
      },
      {
        "name": "Recuperar PaymentIntent",
        "method": "GET",
        "path": "/v1/payment_intents/{pi_id}",
        "note": "Usado en webhook handler para obtener detalles completos tras payment_intent.succeeded"
      },
      {
        "name": "Listar PaymentIntents",
        "method": "GET",
        "path": "/v1/payment_intents",
        "params": "limit, starting_after, created[gte], created[lte], customer",
        "note": "Útil para reconciliación / polling fallback"
      },
      {
        "name": "Listar Invoices (facturas Stripe)",
        "method": "GET",
        "path": "/v1/invoices",
        "params": "limit, starting_after, customer, status (paid|open|draft|uncollectible|void)",
        "note": "Relevante si el cliente usa Stripe Billing. El evento invoice.paid es el trigger para crear factura en Holded."
      },
      {
        "name": "Recuperar Invoice",
        "method": "GET",
        "path": "/v1/invoices/{in_id}",
        "note": "Para obtener line items, importes y datos de cliente completos"
      },
      {
        "name": "Listar Customers",
        "method": "GET",
        "path": "/v1/customers",
        "params": "limit, starting_after, email"
      },
      {
        "name": "Crear Customer",
        "method": "POST",
        "path": "/v1/customers",
        "body_fields": ["email", "name", "metadata", "address"]
      },
      {
        "name": "Crear Refund",
        "method": "POST",
        "path": "/v1/refunds",
        "body_fields": ["charge o payment_intent (requerido)", "amount (parcial si se omite → reembolso total)", "reason", "idempotency_key (header)"]
      },
      {
        "name": "Listar Refunds",
        "method": "GET",
        "path": "/v1/refunds",
        "params": "payment_intent, charge, limit"
      },
      {
        "name": "Recuperar Charge",
        "method": "GET",
        "path": "/v1/charges/{ch_id}",
        "note": "Incluye billing_details (nombre, email, dirección) necesarios para factura Holded"
      }
    ]
  },

  "arquitectura_recomendada": {
    "trigger": "event-driven via webhooks — Stripe tiene el sistema de webhooks más maduro del mercado",
    "evento_clave_b2c": "payment_intent.succeeded — para cobros directos (checkout, ecommerce)",
    "evento_clave_b2b": "invoice.paid — para Stripe Billing (suscripciones, facturas recurrentes)",
    "flujo_stripe_holded": [
      "1. Webhook payment_intent.succeeded o invoice.paid llega a Lambda",
      "2. Lambda valida firma Stripe-Signature con whsec_ (HMAC-SHA256 + timestamp anti-replay)",
      "3. Lambda responde 200 INMEDIATAMENTE — procesar en background",
      "4. Lambda encola evento en SQS con el raw event_id (evt_...)",
      "5. Lambda procesadora hace GET /v1/payment_intents/{id} o GET /v1/invoices/{id} para datos completos",
      "6. Mapear amount (cents → EUR decimal), customer, metadata → formato Holded",
      "7. POST a Holded API para crear factura",
      "8. Idempotencia: verificar en DynamoDB si evt_id ya fue procesado antes de crear factura"
    ],
    "alternativa_polling": "GET /v1/payment_intents con created[gte] — útil para reconciliación nocturna o recovery tras fallo de webhook"
  },

  "gotchas": [
    {
      "issue": "Importes en centavos (cents), NO en decimales",
      "impact": "EUR 10.00 → enviar 1000, no 10.0. Error silencioso: si se envía 10 en lugar de 1000, se cobra 0.10€ en lugar de 10€.",
      "fix": "Siempre multiplicar por 100 al construir el payload. Dividir por 100 al leer para mostrar o mapear a Holded.",
      "source": "[oficial]"
    },
    {
      "issue": "Idempotency-Key obligatoria en todos los POST",
      "impact": "Sin ella, un reintento por timeout de red crea objetos duplicados: dos cargos, dos clientes, dos facturas.",
      "fix": "Generar UUID v4 por operación. Para reintentos, reusar el mismo UUID. Stripe guarda el resultado 24h.",
      "source": "[oficial]"
    },
    {
      "issue": "Validación de firma webhook requiere raw body (sin parsear)",
      "impact": "Si se parsea el JSON y luego se re-serializa para validar, la firma no coincide aunque el contenido sea idéntico (diferencias en espacios, orden de claves).",
      "fix": "Leer el body como buffer/string crudo ANTES de JSON.parse. En Express: express.raw({type: 'application/json'}) en la ruta de webhooks.",
      "source": "[oficial]"
    },
    {
      "issue": "Anti-replay: rechazar webhooks con timestamp > 300 segundos",
      "impact": "Sin esta validación, un atacante puede reenviar un webhook válido capturado para disparar acciones (crear factura duplicada, activar servicio ya pagado).",
      "fix": "Extraer 't' del header Stripe-Signature. Si Math.floor(Date.now()/1000) - t > 300 → rechazar con 400.",
      "source": "[oficial]"
    },
    {
      "issue": "sk_test_ y sk_live_ son entornos completamente separados",
      "impact": "Un customer_id creado en test no existe en live y viceversa. Mezclar claves genera 404 en objetos que sí existen.",
      "fix": "Usar variables de entorno separadas. Nunca hardcodear el prefijo del entorno.",
      "source": "[oficial]"
    },
    {
      "issue": "PaymentIntents (moderno) vs Charges (legacy)",
      "impact": "El API de Charges está deprecated para cuentas nuevas. Usar Charges implica perder soporte para 3D Secure / SCA obligatorio en Europa.",
      "fix": "Usar siempre PaymentIntents + Stripe.js para confirmación en cliente. Charges solo para lectura de histórico.",
      "source": "[oficial]"
    },
    {
      "issue": "Stripe-Version debe fijarse explícitamente en producción",
      "impact": "Si no se fija, Stripe usa la versión del dashboard. Stripe puede actualizar esa versión y cambiar el shape del payload de webhooks sin aviso.",
      "fix": "Enviar header Stripe-Version: 2024-06-20 en todas las llamadas. Fijar también en dashboard para webhooks.",
      "source": "[oficial]"
    },
    {
      "issue": "Webhook endpoint debe responder 200 en < 30s o Stripe reintenta",
      "impact": "Si el procesado de factura en Holded tarda > 30s (por ejemplo, si Holded está lento), Stripe interpreta el timeout como fallo y reintenta — creando facturas duplicadas.",
      "fix": "Responder 200 inmediatamente y procesar en SQS/Lambda async. Usar idempotencia (evt_id en DynamoDB) para deduplicar.",
      "source": "[oficial]"
    }
  ]
}
```

## Arquitectura Lambda para Stripe → Holded

Webhooks event-driven — arquitectura recomendada. Dos triggers según modelo de negocio del cliente:
- B2C / ecommerce: `payment_intent.succeeded`
- B2B / suscripciones: `invoice.paid`

```
payment_intent.succeeded (webhook Stripe)
  → Lambda recibe JSON raw body
  → Valida Stripe-Signature (HMAC-SHA256 + anti-replay 300s)  ← CRÍTICO
  → Responde 200 INMEDIATAMENTE                               ← CRÍTICO: < 30s
  → Encola evt_id en SQS
      → Lambda procesadora:
          → Verifica evt_id en DynamoDB (idempotencia)
          → GET /v1/payment_intents/{pi_id} — datos completos
          → Convierte amount cents → EUR decimal
          → POST Holded API — crear factura
          → Marca evt_id como procesado en DynamoDB
```

Ver [[handler-structure]] para patrón Lambda respuesta rápida + procesado async.
Ver [[idempotencia-dynamodb]] para deduplicación por evt_id.

## Proyectos donde aparece

*(Sin proyectos aún — primer perfil de la plataforma)*
