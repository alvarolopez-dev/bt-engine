---
tags: [plataforma, revo, flow, reservas, booking, restauracion]
created: 2026-05-20
auth_verified_date: 2026-05-20
auth_source: "official docs — api.revo.works/sections/flow.html"
auth_discrepancy: false
---

# Revo Flow — Perfil de integración

#revo #plataforma #reservas #booking

Software de gestión de reservas y aforo para hostelería y restauración.
Integración relevante: Revo Flow → [[holded]] (reservas cerradas → facturas).

```json
{
  "platform": "Revo Flow",
  "versions_validated": ["v1"],
  "confidence": "medium",
  "source": "[oficial — api.revo.works/sections/flow.html — 2026-05-20]",

  "auth": {
    "method": "Bearer Token + Header Tenant obligatorio",
    "headers_required": {
      "Tenant":        "{username_cuenta_revoflow}",
      "Authorization": "Bearer {token}",
      "Content-Type":  "application/json"
    },
    "warning": "Ambos headers son OBLIGATORIOS — falta cualquiera y la llamada falla. A diferencia de Revo XEF, NO hay client-token de integrador aquí.",
    "credentials_obtener": {
      "Tenant": "Nombre de usuario de la cuenta Revo Flow",
      "token":  "Panel de administración Revo Flow — Tokens"
    },
    "api_integracion_alternativa": {
      "method": "Basic Auth en body JSON",
      "body_shape": {
        "auth": {"tenant": "account", "password": "app_password"},
        "action": "action_name",
        "data": {}
      },
      "note": "Solo aplica a la API de integración legacy (integrations.revoflow.works). Diferente al header-based auth de la API externa principal."
    },
    "source": "[oficial]"
  },

  "base_urls": {
    "external_api":    "https://revoflow.works/api/v1/",
    "integration_api": "https://integrations.revoflow.works/api/v1/",
    "legacy_admin":    "https://admin.revo.works/apiFlow",
    "warning": "La API externa (revoflow.works) usa header auth Bearer. La API de integración (integrations.revoflow.works) usa body JSON con auth object. Son autenticaciones distintas — no intercambiar.",
    "source": "[oficial]"
  },

  "rate_limits": {
    "requests_per_minute": 120,
    "recommendation": "Cachear respuestas GET de productos y turnos — cambian raramente. Bookings deben refrescarse según el caso de uso.",
    "source": "[oficial]"
  },

  "pagination": {
    "type": "page+limit",
    "param_page":  "page",
    "param_limit": "limit",
    "response_shape": {
      "currentPage": "number",
      "pages":       "number",
      "left":        "number",
      "data":        "array"
    },
    "note": "Documentada solo en /customers. Verificar si otros endpoints la soportan antes de asumir.",
    "source": "[oficial]"
  },

  "date_format": {
    "format":  "YYYY-MM-DD para parámetros de filtro. YYYY-MM-DD HH:mm:ss para campos de fecha/hora en respuestas.",
    "warning": "No documentado si el cambio de día ocurre a medianoche o a la hora de apertura de caja (como en Revo XEF). Confirmar con el cliente antes del primer proyecto — si usan Revo XEF en paralelo, probablemente compartan la misma lógica de cierre.",
    "source": "[oficial]"
  },

  "http_codes": {
    "response_envelope": {
      "ok":      "boolean — true si OK, false si error",
      "message": "string — descripción del error cuando ok=false",
      "data":    "object o array con el resultado"
    },
    "warning": "La API usa un envelope {ok, message, data} — el HTTP status code puede ser 200 aunque ok=false. Verificar siempre el campo ok de la respuesta, no solo el HTTP status.",
    "standard_http": "No documentado de forma explícita — investigar antes del primer proyecto"
  },

  "webhooks": {
    "available": false,
    "note": "No hay webhooks documentados en la API de Revo Flow. La arquitectura debe ser polling.",
    "alternativa": "Polling con GET /bookings filtrando por rango de fechas. Usar EventBridge Scheduled para disparar la Lambda periódicamente.",
    "source": "[oficial — sin mención de webhooks en la documentación]"
  },

  "endpoints_relevantes_holded": {
    "descripcion": "Endpoints clave para integración Revo Flow → Holded (reservas cerradas con pago → facturas)",
    "endpoints": [
      {
        "name": "Listar reservas por rango de fechas",
        "method": "GET",
        "path": "/bookings",
        "params": "start=YYYY-MM-DD&end=YYYY-MM-DD",
        "note": "Principal endpoint para polling. La respuesta incluye payments[] y products[] — suficiente para construir la factura en Holded sin llamadas adicionales.",
        "response_fields_clave": ["id", "date", "time", "status", "guests", "customer_id", "payments[]", "products[]", "order_id", "total"]
      },
      {
        "name": "Obtener reserva individual",
        "method": "GET",
        "path": "/bookings/{id}",
        "note": "Para obtener detalles completos de una reserva específica durante el procesado."
      },
      {
        "name": "Obtener reserva por Order ID",
        "method": "GET",
        "path": "/orders/{orderId}/booking",
        "note": "Útil si se tiene el orderId de Revo XEF y se quiere cruzar con la reserva de Flow."
      },
      {
        "name": "Listar clientes",
        "method": "GET",
        "path": "/customers",
        "params": "page=N&limit=N",
        "note": "Para obtener datos del cliente (email, nombre) necesarios para crear el contacto en Holded antes de emitir la factura."
      },
      {
        "name": "Listar productos",
        "method": "GET",
        "path": "/products",
        "params": "shifts=id1,id2 (opcional — filtrar por turno)",
        "note": "Catálogo de productos para mapear los items del booking a líneas de factura en Holded."
      },
      {
        "name": "Obtener producto individual",
        "method": "GET",
        "path": "/products/{id}"
      },
      {
        "name": "Listar turnos",
        "method": "GET",
        "path": "/shifts",
        "note": "Para entender la estructura de turnos y filtrar bookings por turno si es necesario.",
        "response_fields_clave": ["id", "name", "startTime", "endTime", "weekdays[]", "active"]
      },
      {
        "name": "Reservas próximas (±2h)",
        "method": "GET",
        "path": "/nextBookings",
        "note": "Ventana -1h a +2h desde el momento actual. Util para dashboards en tiempo real, no para sync a Holded."
      },
      {
        "name": "Cerrar reserva con orden",
        "method": "POST",
        "path": "/bookings/closeWithOrder/{id}",
        "note": "Marca la reserva como cerrada con orden asociada. Verificar si esto es prerequisito antes de facturar."
      }
    ]
  },

  "arquitectura_recomendada": {
    "trigger": "polling — sin webhooks disponibles",
    "patron": "EventBridge Scheduled → Lambda → GET /bookings → POST Holded invoice",
    "flujo_revo_flow_holded": [
      "1. EventBridge dispara Lambda cada N minutos (ej: cada 15min o 1h)",
      "2. Lambda consulta GET /bookings con rango de fechas (ventana deslizante)",
      "3. Filtrar reservas con status cerrado/pagado (verificar valores de status con cliente)",
      "4. Para cada reserva nueva: extraer payments[] y products[] del response",
      "5. Buscar o crear contacto en Holded con customer_id",
      "6. Crear factura en Holded con los datos de la reserva",
      "7. Registrar booking.id procesado en DynamoDB para idempotencia"
    ],
    "frecuencia_recomendada": "Cada hora para facturación EOD. Cada 15min si el cliente necesita near-realtime.",
    "warning": "Sin webhooks, hay latencia inherente. Comunicar al cliente que la facturación en Holded no es instantánea."
  },

  "gotchas": [
    {
      "issue": "Sin webhooks — polling obligatorio",
      "impact": "No se puede reaccionar en tiempo real a eventos de reserva. Latencia entre reserva cerrada y factura en Holded depende del intervalo de polling.",
      "defensive_strategy": "Usar ventana deslizante con overlap para no perder reservas. Idempotencia con DynamoDB para no duplicar facturas ante repolling.",
      "source": "[oficial]"
    },
    {
      "issue": "La respuesta usa envelope {ok, message, data} — HTTP 200 no garantiza éxito",
      "impact": "Código que solo comprueba response.status === 200 procesará errores de negocio como si fueran éxitos.",
      "fix": "Siempre verificar response.data.ok === true antes de procesar data.",
      "source": "[oficial]"
    },
    {
      "issue": "Booking status usa valores numéricos no documentados explícitamente",
      "impact": "No se sabe qué valor de status corresponde a 'cerrado y pagado' sin validación con el cliente.",
      "defensive_strategy": "En fase de Intake: pedir al cliente un booking de ejemplo cerrado y verificar el valor de status. Documentado parcialmente: 1 y 4 mencionados en ejemplos.",
      "source": "[oficial — parcial]"
    },
    {
      "issue": "Dos APIs con autenticación diferente (externa vs integración)",
      "impact": "Confundir las URLs y los métodos de auth genera 401 sin mensaje claro.",
      "fix": "API externa (revoflow.works): headers Tenant + Authorization Bearer. API integración (integrations.revoflow.works): body JSON con auth object.",
      "source": "[oficial]"
    },
    {
      "issue": "Cambio de día — comportamiento respecto a horario de caja no documentado",
      "impact": "Si el cliente cierra reservas de madrugada (ej: restaurantes con turno noche), un filtro por fecha YYYY-MM-DD puede perder o duplicar reservas.",
      "defensive_strategy": "Preguntar al cliente en Intake si tienen turno de noche. Si la respuesta es sí, usar timestamps con overlap entre días en lugar de fechas exactas.",
      "source": "[inferido — comportamiento conocido en Revo XEF, pendiente confirmar en Flow]"
    },
    {
      "issue": "Productos sin shifts asignados aplican a todos los turnos",
      "impact": "El filtro GET /products?shifts=... incluye productos sin shifts + con shifts coincidentes — no excluye productos 'globales'. Tener en cuenta al mapear catálogo.",
      "source": "[oficial]"
    },
    {
      "issue": "Campo token en respuestas aparece como null en los ejemplos",
      "impact": "Uso interno de Revo. No confundir con el token de autenticación del cliente.",
      "source": "[oficial]"
    },
    {
      "issue": "API de integración legacy usa action strings en lugar de REST convencional",
      "impact": "Las acciones como sync, searchProducts, newOrder, updateOrder son strings en un body POST — no hay métodos HTTP diferenciados por recurso. Documentar bien qué actions existen.",
      "source": "[oficial]"
    }
  ]
}
```

## Arquitectura Lambda para Revo Flow → Holded

Sin webhooks — polling obligatorio. No hay evento push desde Revo Flow.

```
EventBridge (scheduled — cada 15min / 1h)
  → Lambda disparada por schedule
  → GET /bookings?start=YYYY-MM-DD&end=YYYY-MM-DD
  → Filtrar por status = cerrado/pagado
      → Para cada booking nuevo (no en DynamoDB):
          → Extraer payments[] y products[]
          → Buscar/crear contacto en Holded (customer_id)
          → POST Holded → crear factura
          → Marcar booking.id en DynamoDB (idempotencia)
```

Ver [[idempotencia-dynamodb]] para evitar facturas duplicadas ante repolling.
Ver [[eventbridge-patterns]] para configurar ventana deslizante con overlap.

## Proyectos donde aparece

*(Sin proyectos aún)*
