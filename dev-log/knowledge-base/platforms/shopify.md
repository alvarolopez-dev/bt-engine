---
tags: [plataforma, shopify, ecommerce]
created: 2026-05-20
auth_verified_date: 2026-05-20
auth_source: "official docs — shopify.dev/docs/api/admin-rest"
auth_discrepancy: false
---

# Shopify Admin REST API — Perfil de integración

#shopify #plataforma #ecommerce

Plataforma de ecommerce B2C/B2B. Admin REST API versioned.
Integración relevante: Shopify → [[holded]] (pedidos pagados → facturas).

```json
{
  "platform": "Shopify Admin REST API",
  "versions_validated": ["2024-01"],
  "confidence": "high",
  "source": "[oficial — shopify.dev/docs/api/admin-rest — 2026-05-20]",

  "auth": {
    "method": "Access Token en header — dos modalidades según tipo de app",
    "header_custom_app": {
      "X-Shopify-Access-Token": "{admin_api_access_token}",
      "Content-Type": "application/json"
    },
    "modalidades": {
      "custom_app": {
        "descripcion": "App privada creada desde el panel del merchant. Genera Admin API access token directamente.",
        "token_obtener": "Shopify Admin → Settings → Apps → Develop apps → Create app → API credentials",
        "header": "X-Shopify-Access-Token: {token}"
      },
      "public_oauth_app": {
        "descripcion": "App pública distribuida a múltiples tiendas. Usa OAuth 2.0 — Authorization Code Flow.",
        "flujo": [
          "1. Redirigir a https://{shop}.myshopify.com/admin/oauth/authorize con client_id, scope, redirect_uri, state",
          "2. Merchant aprueba permisos",
          "3. Shopify redirige a redirect_uri con code temporal",
          "4. POST a https://{shop}.myshopify.com/admin/oauth/access_token con client_id, client_secret, code",
          "5. Respuesta incluye access_token permanente"
        ],
        "header": "X-Shopify-Access-Token: {access_token}"
      }
    },
    "warning": "Para integraciones B2B punto a punto (un merchant), usar Custom App — más simple, sin flujo OAuth. OAuth solo si la app se distribuye a múltiples tiendas.",
    "source": "[oficial]"
  },

  "base_url": {
    "pattern": "https://{shop}.myshopify.com/admin/api/{version}/",
    "example": "https://mi-tienda.myshopify.com/admin/api/2024-01/orders.json",
    "version_format": "YYYY-MM (trimestral)",
    "versions_soportadas": "2 años de soporte por versión antes de deprecación",
    "warning": "La versión va en la URL — no en un header. Cambiar version en URL es un breaking change. Ver gotcha de version pinning.",
    "source": "[oficial]"
  },

  "api_versioning": {
    "releases": "Trimestral: enero, abril, julio, octubre",
    "deprecation_window": "2 años desde release",
    "stable_vs_release_candidate": "Versiones con -rc son release candidates — no usar en producción",
    "recommendation": "Pinear versión explícita en todas las llamadas. Nunca usar 'latest' o 'unstable'.",
    "source": "[oficial]"
  },

  "rate_limits": {
    "modelo": "Leaky bucket",
    "bucket_size": 40,
    "refill_rate": "2 requests/segundo",
    "header_monitor": "X-Shopify-Shop-Api-Call-Limit: {used}/{bucket_size}",
    "ejemplo_header": "X-Shopify-Shop-Api-Call-Limit: 32/40",
    "graphql_model": "Points-based (diferente a REST)",
    "recommendation": "Monitorizar header en cada respuesta. Si used > 35, introducir delay antes de siguiente llamada. No usar burst sin control.",
    "retry_on_429": "Esperar el tiempo indicado en Retry-After header",
    "source": "[oficial]"
  },

  "pagination": {
    "type": "cursor-based",
    "mechanism": "Link header con rel=next y rel=prev",
    "param": "page_info (opaco — no manipular)",
    "max_page_size": 250,
    "default_page_size": 50,
    "ejemplo": "GET /orders.json?limit=250&status=any → Link: <https://...?page_info=abc123>; rel=\"next\"",
    "warning": "page_info es opaco — no combinar con otros filtros en páginas subsiguientes. Usar los parámetros de filtro solo en la primera llamada.",
    "source": "[oficial]"
  },

  "date_format": {
    "format": "ISO 8601 con timezone",
    "ejemplo": "2019-01-25T16:15:00-05:00",
    "filter_params": {
      "created_at_min": "ISO 8601",
      "created_at_max": "ISO 8601",
      "updated_at_min": "ISO 8601",
      "updated_at_max": "ISO 8601",
      "processed_at_min": "ISO 8601",
      "processed_at_max": "ISO 8601"
    },
    "warning": "Siempre incluir timezone en los filtros. Shopify almacena en UTC pero el merchant puede tener timezone propio.",
    "source": "[oficial]"
  },

  "id_format": {
    "type": "integer (64-bit)",
    "ejemplo": 450789469,
    "warning": "IDs son enteros — no strings. En JavaScript, usar BigInt o string para IDs > 2^53 para evitar pérdida de precisión.",
    "source": "[oficial]"
  },

  "webhooks": {
    "available": true,
    "signature": {
      "header": "X-Shopify-Hmac-Sha256",
      "algorithm": "HMAC-SHA256",
      "base64_encoded": true,
      "secret_scope": "Por webhook endpoint — cada webhook tiene su propio secret"
    },
    "content_type": "application/json",
    "delivery_requirements": {
      "protocol": "HTTPS obligatorio",
      "response_timeout": "5 segundos — mismo límite que Revo",
      "response_code_esperado": "200",
      "retry_policy": {
        "intentos": 19,
        "window": "48 horas",
        "nota": "Si todos los reintentos fallan, el webhook NO se desactiva automáticamente (diferencia con Revo)"
      }
    },
    "config_url": "Shopify Admin → Settings → Notifications → Webhooks",
    "api_create": "POST /admin/api/{version}/webhooks.json",
    "eventos_relevantes_holded": [
      "orders/create",
      "orders/updated",
      "orders/paid",
      "orders/fulfilled",
      "refunds/create",
      "products/create",
      "products/update"
    ],
    "todos_los_eventos_orden": [
      "orders/create",
      "orders/delete",
      "orders/edited",
      "orders/fulfilled",
      "orders/paid",
      "orders/partially_fulfilled",
      "orders/updated",
      "order_transactions/create"
    ],
    "source": "[oficial]"
  },

  "endpoints_relevantes_holded": {
    "descripcion": "Endpoints clave para integración Shopify → Holded (pedidos pagados → facturas)",
    "endpoints": [
      {
        "name": "Listar órdenes",
        "method": "GET",
        "path": "/admin/api/{version}/orders.json",
        "params_clave": "status=any&financial_status=paid&limit=250&created_at_min=ISO8601",
        "note": "financial_status=paid es el trigger para crear factura en Holded. Máx 250 por página."
      },
      {
        "name": "Obtener orden individual",
        "method": "GET",
        "path": "/admin/api/{version}/orders/{order_id}.json"
      },
      {
        "name": "Listar productos",
        "method": "GET",
        "path": "/admin/api/{version}/products.json",
        "params_clave": "limit=250&fields=id,title,variants,price"
      },
      {
        "name": "Listar clientes",
        "method": "GET",
        "path": "/admin/api/{version}/customers.json",
        "params_clave": "limit=250&fields=id,email,first_name,last_name"
      },
      {
        "name": "Listar transacciones de una orden",
        "method": "GET",
        "path": "/admin/api/{version}/orders/{order_id}/transactions.json",
        "note": "Para verificar gateway de pago (Shopify Payments vs externo)"
      },
      {
        "name": "Listar refunds de una orden",
        "method": "GET",
        "path": "/admin/api/{version}/orders/{order_id}/refunds.json"
      }
    ],
    "order_financial_status_values": [
      "pending",
      "authorized",
      "partially_paid",
      "paid",
      "partially_refunded",
      "refunded",
      "voided"
    ],
    "trigger_holded_invoice": "financial_status === 'paid'"
  },

  "arquitectura_recomendada": {
    "trigger": "event-driven (webhooks) — preferible a polling",
    "evento_clave": "orders/paid — se dispara cuando el pago está confirmado",
    "flujo_shopify_holded": [
      "1. Webhook orders/paid llega a Lambda",
      "2. Lambda valida firma HMAC-SHA256 del header X-Shopify-Hmac-Sha256",
      "3. Lambda responde 200 inmediatamente — CRÍTICO: < 5s",
      "4. Encola order_id en SQS para procesado async",
      "5. Lambda procesadora: GET /orders/{id}.json para detalles completos",
      "6. Verificar financial_status === 'paid' (idempotencia)",
      "7. Crear factura en Holded con datos del pedido"
    ],
    "alternativa_polling": "GET /orders.json?financial_status=paid&updated_at_min={last_sync} — útil para reconciliación o si webhooks fallan",
    "nota_multiwebhook": "Cada webhook tiene su propio secret. Almacenar por webhook_id, no global."
  },

  "gotchas": [
    {
      "issue": "Version pinning obligatorio — breaking changes cada trimestre",
      "impact": "Sin versión explícita o usando 'unstable', una release trimestral puede romper la integración sin previo aviso.",
      "fix": "Hardcodear versión en config (ej: '2024-01'). Establecer proceso de upgrade trimestral o semi-anual con testing.",
      "source": "[oficial]"
    },
    {
      "issue": "Leaky bucket: burst permitido pero luego throttle severo",
      "impact": "Consumir el bucket de 40 en segundos deja la integración bloqueada hasta refill a 2/s. Imports masivos o reconciliaciones fallan.",
      "fix": "Monitorizar X-Shopify-Shop-Api-Call-Limit. Introducir delay de 500ms cuando used > 35. Para cargas masivas, usar GraphQL Bulk Operations API.",
      "source": "[oficial]"
    },
    {
      "issue": "Webhook secret diferente por endpoint — no hay secret global",
      "impact": "Usar un secret único para validar todos los webhooks de la tienda es incorrecto. Cada webhook registrado tiene su propio secret.",
      "fix": "Almacenar secret por webhook_id. Al crear webhook via API, guardar el secret devuelto en ese momento (solo se muestra una vez).",
      "source": "[oficial]"
    },
    {
      "issue": "Shopify Payments vs gateway externo — diferencia en datos de transacción",
      "impact": "Con Shopify Payments los fondos llegan a Shopify y luego al merchant. Con gateway externo (Stripe, PayPal) el flujo es diferente. El campo gateway en la orden indica cuál aplica.",
      "fix": "Verificar order.gateway antes de mapear datos de pago a Holded. Shopify Payments: gateway='shopify_payments'. Externo: gateway=nombre del proveedor.",
      "source": "[oficial]"
    },
    {
      "issue": "Inventario multi-location — stock no es un valor único",
      "impact": "Con múltiples almacenes/ubicaciones, el stock se distribuye entre locations. GET /inventory_levels.json requiere location_id. El campo inventory_quantity en variant es la suma total.",
      "fix": "Para sync de stock con Holded, usar inventory_quantity del variant (suma global) salvo que Holded soporte multi-almacén.",
      "source": "[oficial]"
    },
    {
      "issue": "page_info opaco — no combinar con filtros en páginas subsiguientes",
      "impact": "Intentar añadir created_at_min o status a una URL con page_info devuelve error. Los filtros solo van en la primera llamada.",
      "fix": "Iterar usando solo el page_info de Link header. Guardar filtros originales solo para la primera request.",
      "source": "[oficial]"
    },
    {
      "issue": "Max 250 órdenes por página — tiendas con alto volumen requieren paginación eficiente",
      "impact": "Una tienda con 10.000 órdenes/día requiere 40+ llamadas para sync diario. Sin paginación correcta, se pierden órdenes.",
      "fix": "Siempre iterar hasta que Link header no incluya rel='next'. Combinar con updated_at_min para syncs incrementales.",
      "source": "[oficial]"
    },
    {
      "issue": "IDs de 64-bit enteros — riesgo de pérdida de precisión en JavaScript",
      "impact": "Number.MAX_SAFE_INTEGER = 2^53. IDs de Shopify pueden superarlo en tiendas grandes, causando IDs incorrectos silenciosamente.",
      "fix": "Tratar order.id, product.id, variant.id como strings en JavaScript. En JSON.parse usar revivor o librería json-bigint.",
      "source": "[oficial]"
    }
  ]
}
```

## Arquitectura Lambda para Shopify → Holded

Webhooks disponibles → event-driven preferible a polling.
Riesgo específico: endpoint Lambda debe responder < 5s o Shopify reintentará 19 veces en 48h.

```
orders/paid (webhook Shopify)
  → Lambda recibe payload JSON
  → Valida HMAC-SHA256 del header X-Shopify-Hmac-Sha256
  → Responde 200 inmediatamente ← CRÍTICO: < 5s
  → Encola order_id en SQS
      → Lambda procesadora: GET /orders/{id}.json
      → Verifica financial_status === 'paid' (idempotencia)
      → POST Holded invoice
```

Ver [[handler-structure]] para patrón de Lambda con respuesta rápida + procesado async.
Ver [[idempotencia-dynamodb]] para evitar facturas duplicadas ante reintentos de Shopify.

## Proyectos donde aparece

*(Sin proyectos aún — primer perfil de la plataforma)*
