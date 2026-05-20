---
tags: [plataforma, revo, tpv, retail, pos]
created: 2026-05-20
auth_verified_date: 2026-05-20
auth_source: "official docs — api.revo.works/sections/retail.html"
auth_discrepancy: false
---

# Revo Retail — Perfil de integración

#revo #plataforma #tpv #pos #retail

Software TPV para comercio minorista (retail).
Integración relevante: Revo Retail → [[holded]] (órdenes cerradas → facturas, productos → catálogo).

```json
{
  "platform": "Revo Retail",
  "versions_validated": ["v3 (reports)"],
  "confidence": "high",
  "source": "[oficial — api.revo.works/sections/retail.html — 2026-05-20]",

  "auth": {
    "method": "Bearer Token + Header username obligatorio",
    "headers_required": {
      "username":      "{username_cuenta_revoretail}",
      "Authorization": "Bearer {token}",
      "Content-Type":  "application/json"
    },
    "warning": "Dos headers obligatorios además de Content-Type — username + Authorization. Falta cualquiera y la llamada falla. A diferencia de Revo XEF, NO requiere client-token de integrador.",
    "credentials_obtener": {
      "username": "Nombre de usuario de la cuenta Revo Retail",
      "token":    "Account Management → Crear token en revoretail.works/admin/account/tokens"
    },
    "source": "[oficial]"
  },

  "base_urls": {
    "api_principal":  "https://revoretail.works/api/external",
    "integraciones":  "https://integrations.revoretail.works/api/external",
    "reports_v3":     "https://revoretail.works/api/external/v3/reports/{reportName}",
    "webhooks_panel": "https://revoretail.works/account/webhooks",
    "warning": "Los reportes usan /v3/reports/{reportName} — endpoint diferente al resto de operaciones. El endpoint antiguo /api/external/reports está DEPRECADO.",
    "source": "[oficial]"
  },

  "rate_limits": {
    "catalog_api": "40 requests por minuto",
    "other_endpoints": "No documentado — investigar antes del primer proyecto",
    "recommendation": "Cachear respuestas GET — especialmente catálogo. 40 req/min es bajo para syncs masivos.",
    "source": "[oficial]"
  },

  "pagination": {
    "type": "page",
    "param_page":       "page",
    "param_page_size":  "pagination",
    "default_page_size": 50,
    "max_page_size":    200,
    "response_shape": {
      "current_page": "number",
      "last_page":    "number",
      "from":         "number",
      "to":           "number",
      "total":        "number",
      "data":         "array"
    },
    "source": "[oficial]"
  },

  "date_format": {
    "dates":       "YYYY-MM-DD",
    "datetime":    "YYYY-MM-DD HH:mm:ss",
    "time_only":   "H:i (ej: '14:30')",
    "report_filters": {
      "start_date": "YYYY-MM-DD (requerido)",
      "end_date":   "YYYY-MM-DD (requerido)",
      "start_time": "HH:mm (opcional)",
      "end_time":   "HH:mm (opcional)"
    },
    "warning": "Cambio de día a medianoche no confirmado explícitamente — verificar si aplica el mismo patrón de apertura de caja que Revo XEF antes del primer proyecto.",
    "source": "[oficial]"
  },

  "http_codes": {
    "success":   "200 OK",
    "error_validacion": "422 Unprocessable Entity",
    "error_format": "{\"error\": \"message\", \"code\": 0, \"data\": []}",
    "warning": "A diferencia de Revo XEF, éxito devuelve 200 (no 201). Verificar el código correcto al migrar código entre plataformas Revo.",
    "source": "[oficial]"
  },

  "webhooks": {
    "available": true,
    "signature": {
      "header":    "X-Revo-Hmac-SHA256",
      "algorithm": "HMAC-SHA256",
      "detail":    "Hash SHA256 del cuerpo del request usando la secret key"
    },
    "content_type": "application/x-www-form-urlencoded",
    "warning": "El payload llega como form-data, NO como JSON. Parsear con URLSearchParams o qs, no con JSON.parse.",
    "payload_shape": {
      "username": "string",
      "event":    "string",
      "data":     "object"
    },
    "config_url": "https://revoretail.works/account/webhooks",
    "secret_key_note": "La secret key se genera en la primera creación de webhook — guardar inmediatamente.",
    "retry_policy": {
      "intentos": 5,
      "detalle":  "5 reintentos automáticos hasta recibir respuesta HTTP exitosa",
      "warning":  "Si los 5 reintentos fallan, el evento puede desactivarse. El endpoint debe responder < 5s. Reactivar manualmente en el panel si ocurre."
    },
    "eventos": {
      "productos": [
        "product.created",
        "product.updated",
        "product.deleted",
        "product.*"
      ],
      "clientes": [
        "customer.created",
        "customer.updated",
        "customer.deleted",
        "customer.*"
      ],
      "ordenes": [
        "order.closed"
      ],
      "turnos": [
        "turn.closed"
      ],
      "pagos": [
        "payment.updated"
      ],
      "inout": [
        "inout.created"
      ],
      "impuestos": [
        "tax.created",
        "tax.updated",
        "tax.deleted",
        "tax.*"
      ],
      "transferencias_stock": [
        "stockTransfer.created",
        "stockTransfer.updated",
        "stockTransfer.*"
      ],
      "presupuestos": [
        "quotation.created",
        "quotation.updated",
        "quotation.deleted",
        "quotation.*"
      ],
      "pedidos_cliente": [
        "customerOrder.created",
        "customerOrder.updated",
        "customerOrder.deleted",
        "customerOrder.*"
      ],
      "albaran": [
        "deliveryNote.created",
        "deliveryNote.updated",
        "deliveryNote.deleted",
        "deliveryNote.*"
      ]
    },
    "source": "[oficial]"
  },

  "endpoints_relevantes_holded": {
    "descripcion": "Endpoints clave para integración Revo Retail → Holded (órdenes → facturas, productos → catálogo)",
    "endpoints": [
      {
        "name": "Orden cerrada — disparada por webhook order.closed",
        "trigger": "webhook",
        "note": "El payload del webhook contiene los datos del pedido. Usar order_id para hacer GET si se necesitan detalles adicionales."
      },
      {
        "name": "Crear orden con pago",
        "method": "POST",
        "path": "/api/external/orders",
        "body_fields": [
          "notes", "shippingAmount", "sum", "subtotal", "discount",
          "tax", "total", "customer_id", "employee_id", "closed_at",
          "order_contents[]"
        ]
      },
      {
        "name": "Crear factura/pago en orden",
        "method": "POST",
        "path": "/api/external/orders/{order_id}/invoices",
        "body_fields": [
          "payments[].amount",
          "payments[].payment_method_id"
        ]
      },
      {
        "name": "Listar métodos de pago",
        "method": "GET",
        "path": "/api/external/config/payment_methods",
        "note": "Obtener al arrancar y cachear el mapeo por cuenta."
      },
      {
        "name": "Listar clientes",
        "method": "GET",
        "path": "/api/external/config/customers",
        "params": "page, pagination"
      },
      {
        "name": "Crear cliente",
        "method": "POST",
        "path": "/api/external/config/customers",
        "body_fields": [
          "name (requerido)", "address (requerido)", "city", "state",
          "country", "postalCode", "nif", "email", "phone", "notes"
        ]
      },
      {
        "name": "Actualizar cliente",
        "method": "PATCH",
        "path": "/api/external/config/customers/{customer_id}"
      },
      {
        "name": "Listar productos",
        "method": "GET",
        "path": "/api/external/catalog/products",
        "params": "page, pagination, filters",
        "note": "Sujeto al límite de 40 req/min del Catalog API."
      },
      {
        "name": "Crear productos (batch)",
        "method": "POST",
        "path": "/api/external/catalog/products",
        "body_fields": [
          "name (requerido)", "category_id (requerido)", "photo", "price",
          "costPrice", "barcode", "brand", "type (0-8)", "tax_id",
          "reference", "weight", "active"
        ],
        "note": "Max 100 objetos por request. Operación all-or-nothing."
      },
      {
        "name": "Listar impuestos",
        "method": "GET",
        "path": "/api/external/config/taxes",
        "note": "Devuelve id, name, taxPercentage. Necesario para mapear taxes a Holded."
      },
      {
        "name": "Reporte de órdenes (polling fallback)",
        "method": "GET",
        "path": "/api/external/v3/reports/orders",
        "params": "start_date=YYYY-MM-DD&end_date=YYYY-MM-DD&page&pagination",
        "note": "Útil para reconciliación o si webhooks fallan."
      },
      {
        "name": "Reporte de pagos",
        "method": "GET",
        "path": "/api/external/v3/reports/payments",
        "params": "start_date=YYYY-MM-DD&end_date=YYYY-MM-DD"
      },
      {
        "name": "Reporte de clientes",
        "method": "GET",
        "path": "/api/external/v3/reports/customers",
        "params": "start_date=YYYY-MM-DD&end_date=YYYY-MM-DD"
      },
      {
        "name": "Stocks actuales",
        "method": "GET",
        "path": "/api/external/catalog/stocks",
        "params": "page, pagination"
      },
      {
        "name": "Actualizar stock",
        "method": "POST",
        "path": "/api/external/stocks/add",
        "body_fields": ["warehouse_id (requerido)", "product_id (requerido)", "quantity (requerido)"],
        "note": "Responde solo con la cantidad actual: {\"quantity\": value}."
      }
    ]
  },

  "arquitectura_recomendada": {
    "trigger": "event-driven (webhooks disponibles) — preferible a polling",
    "evento_clave": "order.closed — se dispara cuando el pedido está cerrado",
    "flujo_revo_retail_holded": [
      "1. Webhook order.closed llega a Lambda",
      "2. Lambda valida firma X-Revo-Hmac-SHA256",
      "3. Lambda extrae datos de pedido del payload form-data",
      "4. Lambda responde 200 inmediatamente — CRÍTICO: < 5s",
      "5. Encola en SQS / Step Functions para procesado async",
      "6. Lambda procesadora: mapea datos → POST factura en Holded"
    ],
    "alternativa_polling": "GET /api/external/v3/reports/orders con filtro de fecha — útil para reconciliación o si webhooks fallan",
    "nota_productos": "Para sync de catálogo: webhook product.* → actualizar catálogo en Holded. Batch max 100 items; respetar límite de 40 req/min."
  },

  "gotchas": [
    {
      "issue": "Dos headers obligatorios — username + Authorization (sin client-token a diferencia de XEF)",
      "impact": "Código reutilizado de Revo XEF fallará si incluye client-token o usa 'tenant' en lugar de 'username'.",
      "fix": "Header se llama 'username' en Retail, 'tenant' en XEF. No son intercambiables.",
      "source": "[oficial]"
    },
    {
      "issue": "Éxito devuelve 200, no 201 (diferente a Revo XEF)",
      "impact": "Código compartido entre integraciones XEF y Retail fallará si verifica status === 201.",
      "fix": "Verificar status >= 200 && status < 300, o separar la lógica de verificación por plataforma.",
      "source": "[oficial]"
    },
    {
      "issue": "Batch operations son all-or-nothing",
      "impact": "Si uno de los 100 objetos de un batch falla validación, NINGUNO se procesa. Sin rollback parcial.",
      "defensive_strategy": "Validar datos antes de enviar. Implementar retry individual para el objeto fallido.",
      "source": "[oficial]"
    },
    {
      "issue": "Máximo 100 objetos por request en operaciones batch",
      "impact": "Syncs iniciales de catálogos grandes requieren paginación de envío además de recepción.",
      "fix": "Chunking: dividir array en lotes de 100 y enviar secuencialmente respetando rate limit.",
      "source": "[oficial]"
    },
    {
      "issue": "Catalog API tiene límite de 40 req/min — muy bajo",
      "impact": "Un catálogo de 500 productos = mínimo 5 llamadas GET. Con variants y stocks, fácil superar el límite.",
      "defensive_strategy": "Cachear GET catalog agresivamente. Usar webhooks product.* para invalidar cache selectivamente.",
      "source": "[oficial]"
    },
    {
      "issue": "Webhook payload es application/x-www-form-urlencoded, NO JSON",
      "impact": "JSON.parse() falla silenciosamente. El campo 'username' sustituye a 'tenant' de XEF.",
      "fix": "Usar express urlencoded middleware o qs.parse(body) antes de procesar.",
      "source": "[oficial]"
    },
    {
      "issue": "Webhook secret key se genera solo en la primera creación",
      "impact": "Si no se guarda en ese momento, no se puede recuperar — hay que regenerar y actualizar todos los endpoints.",
      "defensive_strategy": "Guardar inmediatamente en AWS Secrets Manager / Zoho Vault al crear el webhook.",
      "source": "[oficial]"
    },
    {
      "issue": "Endpoint de reportes antiguo está DEPRECADO",
      "impact": "Usar /api/external/reports (sin v3) devuelve datos pero puede dejar de funcionar sin aviso.",
      "fix": "Siempre usar /api/external/v3/reports/{reportName}.",
      "source": "[oficial]"
    },
    {
      "issue": "Jerarquía de catálogo obligatoria: Groups → Categories → Products",
      "impact": "No se puede crear un producto sin categoría, ni una categoría sin grupo. Sync parcial falla.",
      "defensive_strategy": "Orden de sync: 1) Groups, 2) Categories, 3) Products. Nunca saltar pasos.",
      "source": "[oficial]"
    },
    {
      "issue": "POST /stocks/add solo devuelve la cantidad actual — no confirma el delta aplicado",
      "impact": "Si la llamada se reintenta por error de red, el stock puede sumarse dos veces.",
      "defensive_strategy": "Idempotencia: verificar stock actual con GET /catalog/stocks antes de aplicar delta.",
      "source": "[oficial]"
    },
    {
      "issue": "Cambio de día — no documentado explícitamente si aplica apertura de caja como en XEF",
      "impact": "Si el comportamiento es igual a XEF, pedidos entre medianoche y apertura pertenecen al día anterior.",
      "defensive_strategy": "Preguntar al cliente su horario de cierre antes del primer proyecto. Verificar con datos reales.",
      "source": "[inferido — no documentado en Retail, confirmar]"
    }
  ]
}
```

## Arquitectura Lambda para Revo Retail → Holded

Webhooks disponibles → event-driven preferible a polling.
Riesgo específico: payload llega como form-data (no JSON) y endpoint debe responder < 5s.

```
order.closed (webhook Revo Retail)
  → Lambda recibe payload form-data
  → Valida X-Revo-Hmac-SHA256
  → Parsea con qs.parse() — NO JSON.parse()
  → Responde 200 inmediatamente ← CRÍTICO: < 5s
  → Encola en SQS / Step Functions
      → Lambda procesa: mapea orden → POST Holded invoice

product.* (webhook catálogo)
  → Lambda recibe evento
  → Invalida cache de catálogo
  → Responde 200 inmediatamente
  → Encola actualización async → PATCH/POST catálogo Holded
```

Ver [[handler-structure]] para patrón de Lambda con respuesta rápida + procesado async.
Ver [[idempotencia-dynamodb]] para evitar facturas duplicadas ante reintentos de Revo.

## Proyectos donde aparece

*(Sin proyectos aún)*
