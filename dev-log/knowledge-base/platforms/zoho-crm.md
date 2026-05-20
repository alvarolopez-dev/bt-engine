---
tags: [plataforma, zoho, crm, zoho-one]
created: 2026-05-20
auth_verified_date: 2026-05-20
auth_source: "official docs — zoho.com/crm/developer/docs/api/v7/"
auth_discrepancy: false
---

# Zoho CRM — Perfil de integración

#zoho #crm #plataforma #zoho-one

CRM B2B en la suite Zoho One. OAuth 2.0 compartido con el resto de apps Zoho.
Integración relevante: Zoho CRM → [[holded]] (contactos, deals, leads → facturas/clientes).

```json
{
  "platform": "Zoho CRM",
  "versions_validated": ["v7", "v3"],
  "confidence": "high",
  "source": "[oficial — zoho.com/crm/developer/docs/api/v7/ — 2026-05-20]",

  "auth": {
    "method": "OAuth 2.0 — Access Token + Refresh Token",
    "header": {
      "Authorization": "Zoho-oauthtoken {access_token}"
    },
    "token_expiry": "3600 segundos (1 hora)",
    "refresh_flow": {
      "endpoint": "https://accounts.zoho.{dc}/oauth/v2/token",
      "method": "POST",
      "params": {
        "refresh_token": "{refresh_token}",
        "client_id":     "{client_id}",
        "client_secret": "{client_secret}",
        "grant_type":    "refresh_token"
      },
      "warning": "Refresh token NO caduca (salvo revocación manual). Access token caduca en 1h. Toda Lambda debe refrescar el token antes de llamar a la API — almacenar en SSM/Secrets Manager con TTL."
    },
    "scopes_relevantes": [
      "ZohoCRM.modules.ALL",
      "ZohoCRM.modules.contacts.READ",
      "ZohoCRM.modules.deals.READ",
      "ZohoCRM.modules.leads.READ",
      "ZohoCRM.notifications.CREATE",
      "ZohoCRM.notifications.READ",
      "ZohoCRM.notifications.UPDATE",
      "ZohoCRM.notifications.DELETE"
    ],
    "credentials_obtener": {
      "client_id":     "Zoho Developer Console → API Console → Server-based App",
      "client_secret": "Zoho Developer Console → API Console → Server-based App",
      "refresh_token": "Flujo OAuth authorization code — intercambiar code por tokens"
    },
    "zoho_one_note": "OAuth credentials del Developer Console dan acceso a TODA la suite Zoho One (CRM, Books, Desk, etc.) con los scopes correspondientes. Un solo refresh_token puede servir para múltiples integraciones Zoho.",
    "source": "[oficial]"
  },

  "base_urls": {
    "us":        "https://www.zohoapis.com/crm/v7/",
    "eu":        "https://www.zohoapis.eu/crm/v7/",
    "india":     "https://www.zohoapis.in/crm/v7/",
    "australia": "https://www.zohoapis.com.au/crm/v7/",
    "japan":     "https://www.zohoapis.jp/crm/v7/",
    "canada":    "https://www.zohoapis.ca/crm/v7/",
    "accounts_dc": {
      "us":        "https://accounts.zoho.com",
      "eu":        "https://accounts.zoho.eu",
      "india":     "https://accounts.zoho.in",
      "australia": "https://accounts.zoho.com.au",
      "japan":     "https://accounts.zoho.jp",
      "canada":    "https://accounts.zoho.ca"
    },
    "warning": "CRÍTICO: El data center lo elige el cliente al crear la cuenta Zoho. Clientes españoles → EU (.eu). Usar .com con cuenta EU devuelve error de autenticación o datos vacíos. Preguntar siempre al cliente en qué región creó la cuenta antes de configurar la integración.",
    "source": "[oficial]"
  },

  "rate_limits": {
    "model": "API Credits — no rate-per-minute sino cuota diaria",
    "creditos_por_plan": {
      "standard":   "500 créditos/día",
      "professional": "1000 créditos/día",
      "enterprise": "2000 créditos/día",
      "ultimate":   "5000 créditos/día",
      "note": "Un GET de un registro = 1 crédito. Bulk API = diferente conteo."
    },
    "bulk_api": {
      "available": true,
      "endpoint":  "/crm/bulk/v7/",
      "note": "Para exports masivos — consume menos créditos que múltiples GETs individuales"
    },
    "header_remaining": "X-RATELIMIT-REMAINING — revisar en cada respuesta",
    "recommendation": "Cachear respuestas GET. Usar Notifications (webhooks) para sync reactiva en lugar de polling que consume créditos.",
    "source": "[oficial]"
  },

  "pagination": {
    "type": "page + per_page",
    "param_page":      "page (base 1)",
    "param_page_size": "per_page",
    "max_page_size":   200,
    "default_page_size": 200,
    "response_shape": {
      "info": {
        "page":         "number",
        "per_page":     "number",
        "count":        "number",
        "more_records": "boolean"
      },
      "data": "array"
    },
    "iteration_pattern": "Continuar mientras more_records === true, incrementando page",
    "source": "[oficial]"
  },

  "date_format": {
    "datetime": "ISO 8601 — yyyy-MM-ddTHH:mm:ss+HH:mm",
    "date_only": "yyyy-MM-dd",
    "timezone": "Los timestamps incluyen offset de timezone — respetar para clientes en distintos husos.",
    "source": "[oficial]"
  },

  "id_format": {
    "type":    "long integer",
    "digits":  "18-19 dígitos",
    "example": "5396877000000439001",
    "warning": "JavaScript Number pierde precisión con IDs > 15 dígitos. Siempre tratar IDs como strings, no como números. Usar BigInt o string en JSON.",
    "source": "[oficial]"
  },

  "http_codes": {
    "success_get":    "200 OK",
    "success_create": "201 Created",
    "no_content":     "204 No Content (DELETE exitoso)",
    "invalid_data":   "400 Bad Request",
    "unauthorized":   "401 — token expirado o data center incorrecto",
    "too_many":       "429 — cuota de créditos agotada"
  },

  "webhooks": {
    "available": true,
    "nombre_zoho": "Notifications API",
    "endpoint_crear": "POST /crm/v7/actions/watch",
    "endpoint_listar": "GET /crm/v7/actions/watch",
    "endpoint_actualizar": "PATCH /crm/v7/actions/watch",
    "endpoint_borrar": "DELETE /crm/v7/actions/watch",
    "expiration": {
      "max_hours": 72,
      "warning": "CRÍTICO: Las notificaciones expiran en máximo 72 horas. Si no se renuevan, Zoho deja de enviar eventos SIN aviso. La Lambda receptora debe tener un scheduled job (EventBridge) que renueve la suscripción cada 48h como máximo."
    },
    "request_body_crear": {
      "watch": [
        {
          "channel_id":      "string — ID único del canal (elegido por el integrador)",
          "channel_expiry":  "ISO 8601 datetime — máximo ahora+72h",
          "token":           "string — token para validar que el evento viene de Zoho",
          "notify_url":      "string — URL del endpoint receptor (HTTPS obligatorio)",
          "events":          ["array de eventos — ver lista"],
          "notify_on_related_action": false
        }
      ]
    },
    "eventos_soportados": {
      "leads":    ["Leads.create", "Leads.edit", "Leads.delete", "Leads.all"],
      "contacts": ["Contacts.create", "Contacts.edit", "Contacts.delete", "Contacts.all"],
      "deals":    ["Deals.create", "Deals.edit", "Deals.delete", "Deals.all"],
      "accounts": ["Accounts.create", "Accounts.edit", "Accounts.delete", "Accounts.all"],
      "note":     "Formato: {Module}.{action}. 'all' incluye create+edit+delete."
    },
    "payload_shape": {
      "channel_id":  "string",
      "token":       "string — verificar contra el token enviado al crear",
      "module":      "string — nombre del módulo (Contacts, Deals, etc.)",
      "operation":   "string — insert | update | delete",
      "ids":         "array de string — IDs de registros afectados",
      "channel_expiry": "ISO 8601"
    },
    "validation": "Comparar token del payload con el token configurado al crear la suscripción",
    "content_type": "application/json",
    "renewal_strategy": "EventBridge rule cada 48h → Lambda renews via PATCH /crm/v7/actions/watch",
    "source": "[oficial]"
  },

  "endpoints_relevantes_holded": {
    "descripcion": "Endpoints clave para integración Zoho CRM → Holded (contactos/deals → clientes/facturas)",
    "endpoints": [
      {
        "name": "Listar Contactos",
        "method": "GET",
        "path": "/crm/v7/Contacts",
        "params": "page=1&per_page=200&fields=First_Name,Last_Name,Email,Phone,Account_Name",
        "note": "Especificar fields para reducir payload y consumo de créditos"
      },
      {
        "name": "Obtener Contacto individual",
        "method": "GET",
        "path": "/crm/v7/Contacts/{id}"
      },
      {
        "name": "Crear Contacto",
        "method": "POST",
        "path": "/crm/v7/Contacts",
        "body_shape": { "data": [{ "First_Name": "", "Last_Name": "", "Email": "", "Phone": "" }] }
      },
      {
        "name": "Actualizar Deal",
        "method": "PATCH",
        "path": "/crm/v7/Deals/{id}",
        "body_shape": { "data": [{ "Stage": "Closed Won", "Amount": 0 }] }
      },
      {
        "name": "Listar Deals",
        "method": "GET",
        "path": "/crm/v7/Deals",
        "params": "page=1&per_page=200&fields=Deal_Name,Amount,Stage,Closing_Date,Contact_Name"
      },
      {
        "name": "Listar Leads",
        "method": "GET",
        "path": "/crm/v7/Leads",
        "params": "page=1&per_page=200"
      },
      {
        "name": "Convertir Lead a Contacto/Deal",
        "method": "POST",
        "path": "/crm/v7/Leads/{id}/actions/convert",
        "note": "Operación atómica — crea Contacto, Account y Deal en un solo call"
      },
      {
        "name": "Búsqueda por criterio",
        "method": "GET",
        "path": "/crm/v7/{Module}/search",
        "params": "criteria=((Email:equals:cliente@ejemplo.com))&fields=id,Email",
        "note": "Útil para deduplicación antes de crear registros"
      },
      {
        "name": "Crear suscripción Notifications",
        "method": "POST",
        "path": "/crm/v7/actions/watch",
        "note": "Requiere scope ZohoCRM.notifications.CREATE"
      }
    ]
  },

  "field_naming": {
    "convention": "API names difieren de display labels",
    "ejemplos": {
      "First Name":    "First_Name",
      "Last Name":     "Last_Name",
      "Account Name":  "Account_Name",
      "Deal Name":     "Deal_Name",
      "Closing Date":  "Closing_Date",
      "Contact Name":  "Contact_Name"
    },
    "obtener_api_names": "GET /crm/v7/settings/fields?module=Contacts — devuelve api_name de cada campo",
    "custom_fields": "Campos personalizados tienen prefijo automático (ej: Custom_Field__c en algunos planes)",
    "source": "[oficial]"
  },

  "gotchas": [
    {
      "issue": "Data center incorrecto — zohoapis.com vs zohoapis.eu",
      "impact": "Clientes con cuenta EU que usan .com reciben 401 o respuesta vacía. Error frecuente en configuración inicial.",
      "defensive_strategy": "Preguntar al cliente en qué región creó la cuenta Zoho. Configurar DC como variable de entorno, no hardcodeado. Los clientes españoles son casi siempre EU.",
      "source": "[oficial]"
    },
    {
      "issue": "Access token expira cada 1 hora",
      "impact": "Lambda que no renueva el token falla silenciosamente después de la primera hora de despliegue.",
      "fix": "Almacenar refresh_token en AWS Secrets Manager. Antes de cada llamada API, verificar si el access_token ha expirado (comparar timestamp de emisión + 3600s). Si expira → POST al endpoint de token para obtener uno nuevo.",
      "source": "[oficial]"
    },
    {
      "issue": "Notifications expiran en máximo 72 horas",
      "impact": "La integración event-driven deja de recibir eventos sin ningún aviso de error. Causa pérdida silenciosa de datos.",
      "fix": "EventBridge rule que ejecute Lambda de renovación cada 48h (margen de seguridad). Renovar con PATCH /crm/v7/actions/watch actualizando channel_expiry.",
      "source": "[oficial]"
    },
    {
      "issue": "IDs son enteros de 18-19 dígitos — overflow en JavaScript",
      "impact": "JSON.parse() convierte IDs a float64, perdiendo precisión. Los IDs quedan corruptos y las llamadas subsiguientes fallan.",
      "fix": "Usar json-bigint o extraer IDs como strings. En Node.js: JSON.stringify con replacer, o usar una librería como lossless-json.",
      "source": "[oficial]"
    },
    {
      "issue": "API Credits — modelo de cuota diaria, no rate-per-minute",
      "impact": "Un bucle de sync por polling puede agotar la cuota diaria en minutos en planes bajos. La API devuelve 429 y bloquea hasta el día siguiente.",
      "fix": "Usar Notifications (webhooks) para sync reactiva. Reservar polling solo para reconciliación nocturna con Bulk API.",
      "source": "[oficial]"
    },
    {
      "issue": "API names de campos difieren de los display labels",
      "impact": "Construir payloads usando display names (ej: 'First Name') falla con 400. Solo funcionan los api_names (ej: 'First_Name').",
      "fix": "GET /crm/v7/settings/fields?module={Module} al arrancar para obtener mapping completo. Cachear en S3 o DynamoDB.",
      "source": "[oficial]"
    },
    {
      "issue": "Zoho One — un refresh_token por app OAuth registrada, no por usuario",
      "impact": "Si se registran múltiples apps OAuth en el Developer Console, cada una tiene sus propios tokens. No mezclar client_id/secret entre apps.",
      "note": "Ventaja: un solo client_id bien scopeado puede integrar CRM + Books + Desk en una sola Lambda.",
      "source": "[oficial]"
    }
  ]
}
```

## Arquitectura Lambda para Zoho CRM → Holded

Notifications disponibles (webhooks) → event-driven preferible a polling.
Riesgo específico: las Notifications expiran cada 72h y requieren renovación activa.

```
Contacts.create / Deals.edit (Notification Zoho CRM)
  → Lambda recibe payload JSON
  → Valida token del payload contra token configurado
  → Responde 200 inmediatamente ← mantener Zoho contento
  → Encola en SQS
      → Lambda procesa:
          → Verifica/renueva access_token (SSM/Secrets Manager)
          → GET /crm/v7/Contacts/{id} para detalles completos
          → POST/PATCH Holded contacto o factura

EventBridge rule (cada 48h):
  → Lambda renueva suscripción Notifications
  → PATCH /crm/v7/actions/watch con nuevo channel_expiry
```

Token refresh flow:
```
Al arrancar Lambda:
  1. Leer access_token + issued_at de Secrets Manager
  2. Si (now - issued_at) > 3500s → POST accounts.zoho.{dc}/oauth/v2/token
  3. Guardar nuevo access_token + issued_at en Secrets Manager
  4. Usar access_token fresco para llamada CRM
```

Data center config (env var obligatoria):
```
ZOHO_DC=eu   → zohoapis.eu + accounts.zoho.eu
ZOHO_DC=com  → zohoapis.com + accounts.zoho.com
```

Ver [[handler-structure]] para patrón de Lambda con respuesta rápida + procesado async.
Ver [[idempotencia-dynamodb]] para evitar duplicados ante reintentos de Zoho Notifications.

## Proyectos donde aparece

*(Sin proyectos aún — primer perfil de la plataforma)*
