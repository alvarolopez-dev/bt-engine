---
tags: [plataforma, woocommerce, ecommerce, wordpress]
created: 2026-05-20
auth_verified_date: 2026-05-20
auth_source: "official docs — woocommerce.github.io/woocommerce-rest-api-docs/"
auth_discrepancy: false
---

# WooCommerce — Perfil de integración

#woocommerce #plataforma #ecommerce #wordpress

Plataforma eCommerce sobre WordPress (self-hosted).
Integración relevante: WooCommerce → [[holded]] (pedidos completados → facturas).

```json
{
  "platform": "WooCommerce",
  "versions_validated": ["v3"],
  "confidence": "high",
  "source": "[oficial — woocommerce.github.io/woocommerce-rest-api-docs/ — 2026-05-20]",

  "auth": {
    "method": "Basic Auth (HTTPS) o OAuth 1.0a (HTTP)",
    "credentials": {
      "consumer_key":    "ck_xxxxxxxxxxxxxxxxxxxx",
      "consumer_secret": "cs_xxxxxxxxxxxxxxxxxxxx",
      "obtener":         "WooCommerce → Ajustes → Avanzado → REST API → Añadir clave"
    },
    "basic_auth": {
      "descripcion": "Solo válido sobre HTTPS. Credenciales en header Authorization.",
      "header": "Authorization: Basic base64(consumer_key:consumer_secret)",
      "nota": "Alternativa: pasar como query params ?consumer_key=ck_...&consumer_secret=cs_... (menos seguro)"
    },
    "oauth_1a": {
      "descripcion": "Para conexiones HTTP (sin TLS). Más complejo — firma cada request.",
      "params_requeridos": [
        "oauth_consumer_key",
        "oauth_timestamp",
        "oauth_nonce",
        "oauth_signature",
        "oauth_signature_method=HMAC-SHA256",
        "oauth_version=1.0"
      ],
      "warning": "OAuth 1.0a es necesario solo en HTTP. En producción con HTTPS, siempre preferir Basic Auth."
    },
    "recomendacion": "Basic Auth sobre HTTPS — más simple, suficiente para integraciones server-to-server",
    "source": "[oficial]"
  },

  "base_url": {
    "pattern": "https://{store_url}/wp-json/wc/v3/",
    "ejemplos": [
      "https://mitienda.com/wp-json/wc/v3/orders",
      "https://shop.cliente.es/wp-json/wc/v3/products"
    ],
    "warning": "Self-hosted — la URL varía por cliente. No hay URL fija. Recopilar en fase de Intake.",
    "prerequisito": "WordPress debe tener los permalinks configurados como 'Nombre de la entrada' (Post name). Sin esto la REST API devuelve 404.",
    "source": "[oficial]"
  },

  "rate_limits": {
    "built_in": false,
    "descripcion": "WooCommerce no impone rate limits propios. El límite depende del hosting del cliente.",
    "recomendacion": "Asumir límites conservadores (10-30 req/s). Implementar retry con backoff exponencial.",
    "source": "[oficial + inferencia hosting]"
  },

  "pagination": {
    "type": "page",
    "param_page":      "page",
    "param_page_size": "per_page",
    "default_page_size": 10,
    "max_page_size":   100,
    "response_headers": {
      "X-WP-Total":      "Total de registros",
      "X-WP-TotalPages": "Total de páginas"
    },
    "nota": "Los totales están en headers de respuesta, no en el body.",
    "source": "[oficial]"
  },

  "date_format": {
    "format":    "ISO 8601 — 2019-01-25T16:15:00",
    "timezone":  "UTC preferiblemente, pero el sitio puede estar configurado en timezone local",
    "warning":   "El timezone depende de la configuración de WordPress del cliente. Un sitio con timezone Europe/Madrid devolverá fechas en CET/CEST, no UTC. Verificar en Ajustes → General → Zona horaria antes de filtrar por fecha.",
    "params_filtro": {
      "after":  "Pedidos creados después de esta fecha (ISO 8601)",
      "before": "Pedidos creados antes de esta fecha (ISO 8601)"
    },
    "source": "[oficial]"
  },

  "order_statuses": {
    "todos": [
      "pending",
      "processing",
      "on-hold",
      "completed",
      "cancelled",
      "refunded",
      "failed",
      "trash"
    ],
    "relevantes_holded": {
      "completed":  "Pedido completado y enviado — factura definitiva",
      "processing": "Pagado pero no enviado — pedido confirmado, pago recibido"
    },
    "warning": "'processing' significa PAGADO. No confundir con 'en proceso de pago'. Es el estado más común tras un pago exitoso online.",
    "source": "[oficial]"
  },

  "webhooks": {
    "available": true,
    "descripcion": "WooCommerce incluye webhooks nativos. Se configuran en WooCommerce → Ajustes → Avanzado → Webhooks.",
    "signature": {
      "header":    "X-WC-Webhook-Signature",
      "algorithm": "HMAC-SHA256",
      "secret":    "Definido al crear el webhook en el panel WooCommerce",
      "validacion": "base64(HMAC-SHA256(raw_body, secret))"
    },
    "content_type": "application/json",
    "payload": "JSON",
    "eventos": {
      "ordenes": [
        "woocommerce.order.created",
        "woocommerce.order.updated",
        "woocommerce.order.deleted",
        "woocommerce.order.restored"
      ],
      "productos": [
        "woocommerce.product.created",
        "woocommerce.product.updated",
        "woocommerce.product.deleted",
        "woocommerce.product.restored"
      ],
      "clientes": [
        "woocommerce.customer.created",
        "woocommerce.customer.updated",
        "woocommerce.customer.deleted"
      ],
      "cupones": [
        "woocommerce.coupon.created",
        "woocommerce.coupon.updated",
        "woocommerce.coupon.deleted"
      ]
    },
    "nota": "No hay evento específico por status. El evento 'order.updated' se dispara en cualquier cambio de estado — filtrar por order.status === 'completed' en Lambda.",
    "config_url": "https://{store_url}/wp-admin/admin.php?page=wc-settings&tab=advanced&section=webhooks",
    "source": "[oficial]"
  },

  "endpoints_relevantes_holded": {
    "descripcion": "Endpoints clave para integración WooCommerce → Holded (pedidos → facturas)",
    "endpoints": [
      {
        "name": "Listar pedidos",
        "method": "GET",
        "path": "/wp-json/wc/v3/orders",
        "params": "status=completed&after=2019-01-25T16:15:00&per_page=100&page=1",
        "note": "Filtrar por status=completed o status=processing según el flujo. Paginar con X-WP-TotalPages."
      },
      {
        "name": "Obtener pedido individual",
        "method": "GET",
        "path": "/wp-json/wc/v3/orders/{id}",
        "note": "IDs son integers. Usar para obtener detalles completos tras recibir webhook."
      },
      {
        "name": "Listar productos",
        "method": "GET",
        "path": "/wp-json/wc/v3/products",
        "params": "per_page=100&page=1"
      },
      {
        "name": "Obtener producto individual",
        "method": "GET",
        "path": "/wp-json/wc/v3/products/{id}"
      },
      {
        "name": "Listar clientes",
        "method": "GET",
        "path": "/wp-json/wc/v3/customers",
        "params": "per_page=100&page=1"
      },
      {
        "name": "Obtener cliente individual",
        "method": "GET",
        "path": "/wp-json/wc/v3/customers/{id}"
      }
    ]
  },

  "id_format": {
    "type": "integer",
    "ejemplos": [1, 42, 1023],
    "source": "[oficial]"
  },

  "arquitectura_recomendada": {
    "trigger": "event-driven (webhooks disponibles) — preferible a polling",
    "evento_clave": "woocommerce.order.updated — filtrar por order.status === 'completed' en Lambda",
    "flujo_woocommerce_holded": [
      "1. Webhook order.updated llega a Lambda",
      "2. Lambda valida firma X-WC-Webhook-Signature (HMAC-SHA256)",
      "3. Lambda filtra: si order.status !== 'completed' → ignorar",
      "4. Extraer line_items, billing, total del payload JSON",
      "5. Crear factura en Holded con los datos del pedido",
      "6. Responder 200 a WooCommerce rápido para evitar reintentos"
    ],
    "alternativa_polling": "GET /wp-json/wc/v3/orders?status=completed&after={timestamp} — útil para reconciliación inicial o backfill"
  },

  "gotchas": [
    {
      "issue": "URL varía por cliente — self-hosted, no hay dominio fijo",
      "impact": "Imposible hardcodear la base URL. Cada cliente tiene su propio dominio.",
      "defensive_strategy": "Recopilar store_url en fase de Intake como dato obligatorio. Guardar en Variables de entorno Lambda por cliente.",
      "source": "[oficial]"
    },
    {
      "issue": "Permalinks de WordPress deben estar en 'Post name' para que la REST API funcione",
      "impact": "Con permalinks en modo 'Plain' o 'Numeric', todas las llamadas a /wp-json/ devuelven 404.",
      "fix": "Verificar en WordPress → Ajustes → Enlaces permanentes → seleccionar 'Nombre de la entrada'. Guardar cambios activa el rewrite.",
      "source": "[oficial]"
    },
    {
      "issue": "Basic Auth solo funciona sobre HTTPS",
      "impact": "En sitios sin SSL/TLS, Basic Auth devuelve error o las credenciales viajan en claro.",
      "fix": "Exigir HTTPS al cliente antes de integrar. Alternativa: OAuth 1.0a (más complejo).",
      "source": "[oficial]"
    },
    {
      "issue": "Estado 'processing' = PAGADO, no 'en proceso'",
      "impact": "Confundir processing con un estado intermedio hace que se ignoren pedidos pagados pendientes de envío.",
      "fix": "Incluir status=processing en los filtros si se quiere facturar en el momento del pago, no del envío.",
      "source": "[oficial]"
    },
    {
      "issue": "No hay evento de webhook por cambio de status — solo order.updated",
      "impact": "El webhook order.updated se dispara en CUALQUIER cambio del pedido (nota interna, metadata, etc.), no solo en cambios de status.",
      "fix": "Leer order.status del payload en Lambda y descartar si no es 'completed' (o 'processing' según el flujo).",
      "source": "[inferencia + oficial]"
    },
    {
      "issue": "Timezone de fechas depende de la configuración WordPress del cliente",
      "impact": "Filtrar pedidos por rango de fechas sin conocer el timezone del sitio puede excluir o duplicar pedidos en cambios de hora.",
      "defensive_strategy": "Preguntar al cliente el timezone configurado en WordPress. Trabajar en UTC cuando sea posible. Usar after/before con margen de ±1h en franjas de cambio horario.",
      "source": "[oficial]"
    },
    {
      "issue": "Sin rate limits propios — el límite lo pone el hosting",
      "impact": "En hosting compartido o económico, rafagas de requests pueden generar errores 429 o 503 del servidor web.",
      "defensive_strategy": "Implementar retry con backoff exponencial. Respetar cabecera Retry-After si el servidor la devuelve.",
      "source": "[inferencia hosting]"
    },
    {
      "issue": "Totales de paginación en headers, no en el body",
      "impact": "Código que busca meta.total o pagination.total en el body no encontrará nada.",
      "fix": "Leer X-WP-Total y X-WP-TotalPages de los headers de respuesta HTTP.",
      "source": "[oficial]"
    }
  ]
}
```

## Arquitectura Lambda para WooCommerce → Holded

Webhooks disponibles → event-driven preferible a polling.
No hay evento específico por cambio de status: filtrar order.status en Lambda.

```
order.updated (webhook WooCommerce)
  → Lambda recibe payload JSON
  → Valida X-WC-Webhook-Signature (HMAC-SHA256)
  → Filtra: order.status !== 'completed' → return 200, no procesar
  → Extrae line_items + billing + total del payload
  → POST Holded invoice
  → Responde 200
```

Alternativa polling para backfill inicial o reconciliación:

```
GET /wp-json/wc/v3/orders?status=completed&after={last_sync_ts}&per_page=100
  → Iterar páginas hasta X-WP-TotalPages
  → Para cada pedido → POST Holded invoice
  → Guardar timestamp de último sync en DynamoDB
```

Ver [[idempotencia-dynamodb]] para evitar facturas duplicadas si el webhook se dispara múltiples veces para el mismo pedido.

## Proyectos donde aparece

*(Sin proyectos aún — primer perfil de la plataforma)*
