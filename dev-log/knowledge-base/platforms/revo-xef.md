---
tags: [plataforma, revo, tpv, restauracion, pos]
created: 2026-05-20
auth_verified_date: 2026-05-20
auth_source: "official docs — api.revo.works/sections/xef.html"
auth_discrepancy: false
---

# Revo XEF — Perfil de integración

#revo #plataforma #tpv #pos

Software TPV para hostelería y restauración.
Integración relevante: Revo XEF → [[holded]] (pedidos cerrados → facturas).

```json
{
  "platform": "Revo XEF",
  "versions_validated": ["v2", "v3"],
  "confidence": "high",
  "source": "[oficial — api.revo.works/sections/xef.html — 2026-05-20]",

  "auth": {
    "method": "Bearer Token + Headers adicionales obligatorios",
    "headers_required": {
      "tenant":        "{username_cuenta_revo}",
      "Authorization": "Bearer {token}",
      "client-token":  "{token_integrador}",
      "Content-Type":  "application/json"
    },
    "warning": "Los 3 headers son OBLIGATORIOS — falta cualquiera y la llamada falla sin mensaje claro",
    "credentials_obtener": {
      "tenant":       "Nombre de usuario de la cuenta Revo XEF",
      "token":        "Account Management → Tokens en el panel Revo",
      "client-token": "Contactar con Revo para obtener token de integrador"
    },
    "source": "[oficial]"
  },

  "base_urls": {
    "catalog_loyalty": "https://revoxef.works/api/external/v2/",
    "reports":         "https://revoxef.works/api/external/v3/",
    "booking":         "https://revoxef.works/apiFlow",
    "integration_env": "https://integrations.revoxef.works/api/external/v2/",
    "warning": "Dos versiones de base URL según el recurso — v2 para catálogo/pedidos, v3 para reportes. Error frecuente mezclar versiones.",
    "source": "[oficial]"
  },

  "rate_limits": {
    "requests_per_minute": 120,
    "max_payload_size": "2MB",
    "recommendation": "Cachear respuestas GET — especialmente catálogo",
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
      "next_page_url":"string | null",
      "per_page":     "number",
      "total":        "number",
      "data":         "array"
    },
    "source": "[oficial]"
  },

  "date_format": {
    "format":  "YYYY-MM-DD o YYYY-MM-DD HH:MM:SS",
    "warning": "El cambio de día NO ocurre a medianoche — ocurre a la hora de apertura de caja (típicamente 04:00). Un pedido de las 03:30 pertenece al día anterior. Filtrar por fecha sin tener esto en cuenta genera datos incorrectos.",
    "source": "[oficial]"
  },

  "http_codes": {
    "success": "201 HTTP_CREATED",
    "error":   "422 HTTP_UNPROCESSABLE_ENTITY",
    "not_found": "404",
    "warning": "Éxito devuelve 201, no 200. Verificar el código de respuesta correctamente."
  },

  "webhooks": {
    "available": true,
    "signature": {
      "header":    "X-Revo-Hmac-SHA256",
      "algorithm": "SHA256"
    },
    "content_type": "application/x-www-form-urlencoded",
    "warning": "El payload llega como form-data, NO como JSON. Parsear con URLSearchParams o qs, no con JSON.parse.",
    "payload_shape": {
      "tenant": "string",
      "event":  "string",
      "data":   "object"
    },
    "config_url": {
      "produccion":  "https://revoxef.works/account/webhooks",
      "integracion": "https://integrations.revoxef.works/account/webhooks"
    },
    "retry_policy": {
      "intentos": [0, 10, 30, 60, 120, 300],
      "unidad":   "segundos",
      "warning":  "Si los 5 reintentos fallan, el evento se DESACTIVA automáticamente. El endpoint debe responder < 5s. Si desactiva → reactivar manualmente en el panel."
    },
    "eventos": {
      "ordenes": [
        "order.created",
        "order.updated",
        "order.closed",
        "order.moved",
        "order.merged",
        "order.cancelled"
      ],
      "productos": [
        "product.created",
        "product.updated",
        "product.deleted"
      ],
      "clientes": [
        "customer.created",
        "customer.updated",
        "customer.deleted"
      ],
      "stock": [
        "stocks.created",
        "stocks.updated"
      ],
      "pagos": ["orderPayment.updated"],
      "compras": ["purchaseOrder.created", "purchaseOrder.updated"],
      "tarjetas_regalo": ["giftCard.created"],
      "turnos": ["turn.opened", "turn.closed"],
      "kds": ["kds.contentsReady"]
    },
    "source": "[oficial]"
  },

  "endpoints_relevantes_holded": {
    "descripcion": "Endpoints clave para integración Revo XEF → Holded (pedidos cerrados → facturas)",
    "endpoints": [
      {
        "name": "Obtener órdenes con pagos (polling)",
        "method": "GET",
        "version": "v3",
        "path": "/api/external/v3/reports/orders",
        "params": "start_date=YYYY-MM-DD&end_date=YYYY-MM-DD&withInvoices=&withPayments=&withContents=",
        "note": "Principal endpoint para sync por polling. Incluir withPayments para totales y métodos de pago."
      },
      {
        "name": "Obtener orden individual",
        "method": "GET",
        "version": "v2",
        "path": "/api/external/v2/loyalty/orders/{orderId}"
      },
      {
        "name": "Crear pago en orden",
        "method": "POST",
        "version": "v2",
        "path": "/api/external/v2/loyalty/orders/{orderId}/payments",
        "body_fields": ["amount (requerido)", "payment_method_id (opcional)", "payment_reference (opcional)", "tip (opcional)"]
      },
      {
        "name": "Listar ítems del catálogo",
        "method": "GET",
        "version": "v2",
        "path": "/api/external/v2/catalog/items"
      },
      {
        "name": "Listar métodos de pago",
        "method": "GET",
        "version": "v2",
        "path": "/api/external/v2/paymentMethods",
        "note": "Card=1, Cash=2 son fijos. El resto varía por cuenta."
      },
      {
        "name": "Reporte de pagos",
        "method": "GET",
        "version": "v3",
        "path": "/api/external/v3/reports/payments",
        "params": "start_date=YYYY-MM-DD&end_date=YYYY-MM-DD"
      }
    ]
  },

  "arquitectura_recomendada": {
    "trigger": "event-driven (webhooks disponibles) — preferible a polling",
    "evento_clave": "order.closed — se dispara cuando el pedido está cerrado y pagado",
    "flujo_revo_holded": [
      "1. Webhook order.closed llega a Lambda",
      "2. Lambda valida firma X-Revo-Hmac-SHA256",
      "3. Lambda extrae order_id del payload",
      "4. GET /api/external/v2/loyalty/orders/{orderId} para detalles completos",
      "5. Crear factura en Holded con los datos del pedido",
      "6. Responder 200 a Revo en < 5s para evitar reintentos"
    ],
    "alternativa_polling": "GET /api/external/v3/reports/orders con filtro de fecha — útil para reconciliación o si webhooks fallan"
  },

  "gotchas": [
    {
      "issue": "G-CRITICO: client-token no se auto-genera",
      "impact": "Sin client-token la integración es imposible. No hay workaround.",
      "fix": "Solicitar explícitamente a Revo antes de arrancar cualquier trabajo técnico.",
      "responsable": "INTAKE — pregunta obligatoria Nivel 1: '¿Tienes el client-token de Revo? Sin él la integración no puede empezar.'",
      "tiempo_obtencion": "No documentado por Revo. Puede bloquear días.",
      "source": "[oficial]"
    },
    {
      "issue": "Tres headers obligatorios — tenant + Authorization + client-token",
      "impact": "Falta cualquiera → fallo sin mensaje claro. Diferente a APIs que solo usan Authorization.",
      "source": "[oficial]"
    },
    {
      "issue": "Cambio de día a hora de apertura de caja, NO a medianoche",
      "impact": "Pedidos entre medianoche y la apertura de caja (ej: 00:00–04:00) pertenecen al día anterior. Filtrar por fecha YYYY-MM-DD sin compensar esto genera datos incorrectos y facturas duplicadas o perdidas.",
      "defensive_strategy": "Siempre preguntar al cliente a qué hora abre caja. Filtrar con margen o usar timestamps exactos.",
      "source": "[oficial]"
    },
    {
      "issue": "Webhook payload es application/x-www-form-urlencoded, NO JSON",
      "impact": "JSON.parse() falla silenciosamente. El contenido llega como form-data.",
      "fix": "Usar express urlencoded middleware o qs.parse(body) antes de procesar",
      "source": "[oficial]"
    },
    {
      "issue": "Webhook se DESACTIVA si 5 reintentos consecutivos fallan",
      "impact": "La integración deja de recibir eventos sin aviso visible. Requiere reactivación manual en panel Revo.",
      "defensive_strategy": "Lambda debe responder 200 en < 5s siempre, aunque procese en background. Usar SQS o Step Functions para desacoplar recepción de procesado.",
      "source": "[oficial]"
    },
    {
      "issue": "Dos base URLs según el recurso — v2 y v3",
      "impact": "Mezclar versiones devuelve 404 o datos incorrectos sin mensaje claro.",
      "fix": "Catálogo/pedidos/loyalty → v2. Reportes → v3. Nunca mezclar.",
      "source": "[oficial]"
    },
    {
      "issue": "Respuesta de éxito es 201, no 200",
      "impact": "Código que verifica response.status === 200 considerará todos los CREATEs como errores",
      "fix": "Verificar status >= 200 && status < 300, o exactamente 201 para operaciones POST",
      "source": "[oficial]"
    },
    {
      "issue": "payment_method_id 1 y 2 son fijos (Card y Cash), el resto varía por cuenta",
      "impact": "Mapear métodos de pago hardcodeando IDs > 2 genera errores en cuentas distintas",
      "defensive_strategy": "Obtener GET /paymentMethods al arrancar y cachear el mapeo por cuenta",
      "source": "[oficial]"
    },
    {
      "issue": "client-token requiere solicitud explícita a Revo — no se auto-genera",
      "impact": "Sin este token no hay integración posible. Tiempo de espera para obtenerlo: no documentado.",
      "note": "Solicitar en fase de Intake, antes de que Research lo marque como prerequisito bloqueante.",
      "source": "[oficial]"
    }
  ]
}
```

## Arquitectura Lambda para Revo → Holded

Webhooks disponibles → event-driven preferible a polling.
Riesgo específico: si el endpoint Lambda no responde en < 5s, Revo desactiva el evento.

```
order.closed (webhook Revo)
  → Lambda recibe payload form-data
  → Valida X-Revo-Hmac-SHA256
  → Responde 200 inmediatamente ← CRÍTICO: < 5s
  → Encola en SQS / Step Functions
      → Lambda procesa: GET order details → POST Holded invoice
```

Ver [[handler-structure]] para patrón de Lambda con respuesta rápida + procesado async.
Ver [[idempotencia-dynamodb]] para evitar facturas duplicadas ante reintentos de Revo.

## Proyectos donde aparece

*(Sin proyectos aún — primer perfil de la plataforma)*
