---
tags: [plataforma, business-central, erp, microsoft, dynamics365]
created: 2026-05-20
auth_verified_date: 2026-05-20
auth_source: "official docs — learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/"
auth_discrepancy: false
---

# Microsoft Dynamics 365 Business Central — Perfil de integración

#business-central #plataforma #erp #microsoft #dynamics365

ERP cloud de Microsoft para PYMES. API REST sobre OData v4.
Integración relevante: Business Central → [[holded]] (facturas de venta, clientes, productos).

```json
{
  "platform": "Microsoft Dynamics 365 Business Central",
  "versions_validated": ["v2.0"],
  "confidence": "high",
  "source": "[oficial — learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/api-reference/v2.0/ — 2026-05-20]",

  "auth": {
    "method": "OAuth 2.0 — Bearer Token vía Azure AD (Microsoft Entra ID)",
    "flow": "Client Credentials (service-to-service) o Delegated (usuario)",
    "headers_required": {
      "Authorization": "Bearer {access_token}",
      "Content-Type": "application/json"
    },
    "scopes": "https://api.businesscentral.dynamics.com/.default",
    "token_endpoint": "https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token",
    "prerequisito_bloqueante": "App registration en Azure AD (Microsoft Entra ID) obligatoria antes de cualquier trabajo con la API. Sin ella no hay token posible.",
    "credentials_obtener": {
      "tenantId": "Azure AD → Properties → Tenant ID",
      "clientId": "Azure AD → App registrations → Application (client) ID",
      "clientSecret": "Azure AD → App registrations → Certificates & Secrets",
      "permisos_requeridos": "Dynamics 365 Business Central → API permissions → Financials.ReadWrite.All (o específicos)"
    },
    "source": "[oficial]"
  },

  "base_urls": {
    "cloud": "https://api.businesscentral.dynamics.com/v2.0/{tenantId}/{environment}/api/v2.0/",
    "ejemplo_produccion": "https://api.businesscentral.dynamics.com/v2.0/abc-123/production/api/v2.0/",
    "ejemplo_sandbox": "https://api.businesscentral.dynamics.com/v2.0/abc-123/sandbox/api/v2.0/",
    "parametros_url": {
      "tenantId": "GUID del tenant Azure AD del cliente",
      "environment": "Nombre del entorno BC — típico 'production' o 'sandbox', pero puede ser custom (ej: 'PROD-ES'). NO es fijo."
    },
    "warning": "La URL requiere TANTO tenantId COMO nombre de entorno — diferente a casi todas las APIs REST. El nombre del entorno varía por cliente y no siempre es 'production'. Confirmar con el cliente antes de configurar.",
    "multi_company": "Todos los endpoints de datos van bajo /companies({companyId})/ — companyId es GUID y varía por empresa dentro del mismo tenant.",
    "source": "[oficial]"
  },

  "protocol": {
    "tipo": "OData v4",
    "query_params": {
      "$filter": "Filtrar registros — ej: $filter=lastModifiedDateTime gt 2024-01-01T00:00:00Z",
      "$top": "Limitar número de resultados",
      "$skip": "Saltar N registros (paginación offset)",
      "$select": "Seleccionar campos específicos",
      "$expand": "Expandir relaciones — ej: $expand=salesInvoiceLines,customer"
    },
    "source": "[oficial]"
  },

  "rate_limits": {
    "documentado": false,
    "nota": "No hay límites explícitos publicados. Existen límites de concurrencia por entorno (environment). Microsoft recomienda implementar retry con backoff exponencial ante 429 o 503.",
    "recomendacion": "No paralizar más de 5 requests simultáneos por entorno. Implementar retry con Retry-After header.",
    "source": "[inferido de docs + best practices Microsoft]"
  },

  "pagination": {
    "type": "cursor — @odata.nextLink",
    "response_shape": {
      "@odata.context": "string",
      "@odata.nextLink": "string | ausente si es la última página",
      "value": "array"
    },
    "uso": "Si existe @odata.nextLink en la respuesta, hacer GET a esa URL completa para la siguiente página. Repetir hasta que no aparezca.",
    "warning": "No asumir que todos los datos llegaron si no se verifica ausencia de @odata.nextLink.",
    "source": "[oficial]"
  },

  "date_format": {
    "format": "ISO 8601 — 2019-01-25T16:15:00Z",
    "campos_fecha": "invoiceDate, postingDate, dueDate usan YYYY-MM-DD. lastModifiedDateTime usa datetime completo con Z.",
    "source": "[oficial]"
  },

  "id_format": {
    "tipo": "GUID (UUID v4)",
    "ejemplo": "9e0f5c9c-44e3-ea11-bb43-000d3a2feca1",
    "warning": "Los IDs de companyId, customerId, itemId, etc. son todos GUIDs. Nunca usar números o códigos internos como IDs en la URL.",
    "source": "[oficial]"
  },

  "http_codes": {
    "get_success": "200 OK",
    "post_success": "201 Created",
    "patch_success": "200 OK",
    "delete_success": "204 No Content",
    "etag_conflict": "412 Precondition Failed — ETag no coincide, alguien modificó el registro antes",
    "not_found": "404",
    "unauthorized": "401"
  },

  "etag": {
    "required_for": ["PATCH", "DELETE"],
    "header": "If-Match",
    "como_obtener": "El ETag viene en la respuesta GET como header ETag o campo @odata.etag en el body",
    "ejemplo": "If-Match: W/\"JzQ0O0tvbXBhbnkx...\"",
    "warning": "PATCH y DELETE SIN If-Match devuelven error. ETag cambia con cada modificación del registro. Si entre el GET y el PATCH hay un cambio, el PATCH falla con 412 — implementar retry con GET + PATCH.",
    "source": "[oficial — OData v4 optimistic concurrency]"
  },

  "webhooks": {
    "available": true,
    "registro": {
      "method": "POST",
      "endpoint": "/api/v2.0/subscriptions",
      "body": {
        "notificationUrl": "https://{tu-endpoint-https}",
        "resource": "/api/v2.0/companies({companyId})/customers",
        "clientState": "secreto-opcional-para-verificar-origen"
      }
    },
    "handshake": {
      "descripcion": "Al crear o renovar una suscripción, BC hace GET al notificationUrl con ?validationToken=...",
      "respuesta_requerida": "El endpoint debe devolver el validationToken en el body con status 200 OK",
      "warning": "Sin el handshake correcto, la suscripción no se registra. El endpoint debe estar online ANTES de llamar al POST /subscriptions."
    },
    "expiracion": {
      "ttl": "3 días",
      "renovacion": "PATCH /api/v2.0/subscriptions({id}) — también requiere handshake validationToken",
      "campo": "expirationDateTime en la respuesta indica cuándo expira",
      "warning": "Suscripciones expiran a los 3 días. Sin renovación automática, la integración deja de recibir eventos silenciosamente. Implementar job periódico de renovación (cada 2 días máximo)."
    },
    "notificationUrl_requirements": "HTTPS obligatorio. Debe responder < timeout de BC. Responder con código no-5xx para evitar que BC abandone reintentos.",
    "retry_policy": {
      "intentos": "Múltiples reintentos durante 36 horas",
      "abandono": "Si el endpoint responde con código que NO sea 408, 429 o 5xx, BC NO reintenta y ELIMINA la suscripción",
      "warning": "Responder siempre 200 rápido aunque el procesado sea async. Un 400 o 500 permanente elimina la suscripción."
    },
    "delay": "BC espera 30 segundos tras el primer cambio antes de enviar notificación. Si >1000 registros cambian en ese periodo, envía una notificación 'collection' en lugar de individuales.",
    "change_types": ["created", "updated", "deleted", "collection"],
    "entidades_soportadas": [
      "accounts", "companyInformation", "countriesRegions", "currencies",
      "customerPaymentJournals", "customers", "dimensions", "employees",
      "generalLedgerEntries", "itemCategories", "items", "journals",
      "paymentMethods", "paymentTerms", "purchaseInvoices", "salesCreditMemos",
      "salesInvoices", "salesOrders", "salesQuotes", "shipmentMethods",
      "unitsOfMeasure", "vendors"
    ],
    "nota_lineas": "Un cambio en salesInvoiceLine dispara notificación en la suscripción de salesInvoice (cabecera).",
    "clientState": "Campo opcional en POST/PATCH — se incluye en cada notificación. Usar como secreto compartido para verificar origen.",
    "source": "[oficial — learn.microsoft.com/...dynamics-subscriptions — 2026-05-20]"
  },

  "endpoints_relevantes_holded": {
    "descripcion": "Endpoints clave para integración Business Central → Holded (facturas de venta, clientes, productos)",
    "base": "https://api.businesscentral.dynamics.com/v2.0/{tenantId}/{environment}/api/v2.0/companies({companyId})/",
    "endpoints": [
      {
        "name": "Listar facturas de venta",
        "method": "GET",
        "path": "salesInvoices",
        "params": "$filter=lastModifiedDateTime gt {datetime}&$expand=salesInvoiceLines,customer&$top=50",
        "note": "Usar lastModifiedDateTime para sync incremental. Expandir líneas y cliente para datos completos en una sola llamada."
      },
      {
        "name": "Obtener factura individual",
        "method": "GET",
        "path": "salesInvoices({id})",
        "params": "$expand=salesInvoiceLines,customer"
      },
      {
        "name": "Crear factura de venta",
        "method": "POST",
        "path": "salesInvoices",
        "campos_requeridos": ["customerId", "invoiceDate"],
        "note": "Crear cabecera primero, luego POST a salesInvoices({id})/salesInvoiceLines para las líneas."
      },
      {
        "name": "Listar clientes",
        "method": "GET",
        "path": "customers",
        "params": "$filter=lastModifiedDateTime gt {datetime}&$top=50"
      },
      {
        "name": "Obtener cliente individual",
        "method": "GET",
        "path": "customers({id})"
      },
      {
        "name": "Listar productos (items)",
        "method": "GET",
        "path": "items",
        "params": "$filter=lastModifiedDateTime gt {datetime}&$top=50"
      },
      {
        "name": "Actualizar registro (requiere ETag)",
        "method": "PATCH",
        "path": "customers({id})",
        "headers_extra": {
          "If-Match": "{etag-obtenido-del-GET-previo}"
        },
        "note": "Siempre hacer GET primero para obtener ETag actualizado antes del PATCH."
      }
    ]
  },

  "recursos_customer": {
    "campos_principales": {
      "id": "GUID — non-editable",
      "number": "string — código de cliente en BC",
      "displayName": "string — nombre",
      "type": "NAV.contactType — 'Company' o 'Person'",
      "addressLine1": "string",
      "city": "string",
      "country": "string",
      "postalCode": "string",
      "phoneNumber": "string",
      "email": "string",
      "taxRegistrationNumber": "string — NIF/CIF",
      "currencyCode": "string",
      "blocked": "NAV.customerBlocked — ' ', 'Ship', 'Invoice', 'All'",
      "lastModifiedDateTime": "datetime — read-only"
    },
    "navegacion": ["currency", "paymentTerm", "shipmentMethod", "paymentMethod", "customerFinancialDetail", "defaultDimensions"]
  },

  "gotchas": [
    {
      "issue": "ETag obligatorio en PATCH y DELETE — optimistic concurrency",
      "impact": "Sin If-Match header → error. Con ETag desactualizado → 412 Precondition Failed. La única forma correcta: GET → guardar ETag → PATCH inmediato.",
      "defensive_strategy": "Wrapper de PATCH que siempre hace GET previo, extrae ETag, luego hace PATCH. Ante 412, reintentar el ciclo completo GET→PATCH.",
      "source": "[oficial]"
    },
    {
      "issue": "URL contiene tenantId Y nombre de entorno — ambos variables por cliente",
      "impact": "El nombre del entorno NO es siempre 'production'. Clientes con entornos custom (ej: 'PROD-ES', 'BC-2024') rompen las URLs hardcodeadas.",
      "defensive_strategy": "Parametrizar TANTO tenantId COMO environment en la configuración por cliente. Confirmar ambos en fase de intake.",
      "source": "[oficial]"
    },
    {
      "issue": "Multi-empresa: companyId requerido en todos los endpoints de datos",
      "impact": "Un tenant puede tener múltiples empresas (companies). Sin companyId correcto, se accede a la empresa equivocada o error 404.",
      "defensive_strategy": "GET /companies al inicio para listar y seleccionar. Parametrizar companyId por cliente/proyecto.",
      "source": "[oficial]"
    },
    {
      "issue": "Webhook subscriptions expiran a los 3 días",
      "impact": "Sin renovación automática, la integración deja de recibir eventos sin aviso. Fallo silencioso.",
      "fix": "Job Lambda o Step Functions que ejecute PATCH /subscriptions cada 2 días. También manejar el handshake validationToken en el PATCH.",
      "source": "[oficial]"
    },
    {
      "issue": "App registration Azure AD obligatoria — tiempo de setup no trivial",
      "impact": "Sin el registro de app con permisos correctos no hay token ni API posible. El cliente necesita acceso de administrador a Azure AD.",
      "defensive_strategy": "Solicitar credenciales Azure AD en fase de Intake como prerequisito bloqueante. Mínimo 1-2 días de setup si el cliente no tiene experiencia.",
      "source": "[oficial]"
    },
    {
      "issue": "Webhook elimina suscripción si el endpoint responde con código inesperado",
      "impact": "Un 400 o error no-5xx permanente hace que BC elimine la suscripción — no reintenta.",
      "fix": "Endpoint Lambda debe responder 200 siempre y rápido. Procesar en background con SQS. Solo 408, 429 o 5xx activan reintentos.",
      "source": "[oficial]"
    },
    {
      "issue": "Webhook handshake requerido también al RENOVAR (PATCH)",
      "impact": "El PATCH de renovación también dispara validationToken challenge. Si el endpoint no maneja este caso, la renovación falla y la suscripción expira.",
      "fix": "El endpoint notificationUrl debe manejar GET con ?validationToken= en TODAS sus peticiones, devolviendo el token con 200.",
      "source": "[oficial]"
    },
    {
      "issue": "Notificación 'collection' cuando >1000 cambios en 30s",
      "impact": "En lugar de notificaciones individuales, BC envía una sola notificación 'collection' con un filtro. El handler debe detectar changeType='collection' y hacer polling para obtener todos los registros.",
      "defensive_strategy": "Implementar rama específica para changeType='collection' que ejecute GET con el filtro incluido en la notificación.",
      "source": "[oficial]"
    },
    {
      "issue": "Azure AD app requiere consentimiento de administrador del tenant cliente",
      "impact": "No basta con crear la app — el admin del tenant BC del cliente debe dar consent explícito a los permisos de la app.",
      "defensive_strategy": "Preparar URL de admin consent y solicitar al cliente que la apruebe. Sin este paso, el client credentials flow falla.",
      "source": "[inferido de Azure AD docs]"
    }
  ]
}
```

## Arquitectura Lambda para Business Central → Holded

Webhooks disponibles (event-driven) — preferible a polling para volúmenes altos.
Riesgo específico: suscripciones expiran a los 3 días — requieren renovación periódica.
Riesgo crítico: ETag obligatorio en escritura — siempre GET → PATCH, nunca PATCH directo.

```
[Opción A — Event-driven via webhooks]
salesInvoice updated (webhook BC)
  → Lambda recibe notificación JSON
  → Responde 200 inmediatamente ← CRÍTICO: rápido o BC elimina suscripción
  → Encola en SQS
      → Lambda procesa:
          GET salesInvoice({id})?$expand=salesInvoiceLines,customer
          → POST/PATCH factura en Holded
          → DynamoDB: marcar como procesado (idempotencia)

[Opción B — Polling incremental]
EventBridge (cada N minutos)
  → Lambda:
      GET salesInvoices?$filter=lastModifiedDateTime gt {last_sync}
      → Iterar @odata.nextLink hasta agotar páginas
      → POST/PATCH facturas en Holded
      → Actualizar last_sync en Parameter Store

[Job de renovación de webhooks — OBLIGATORIO]
EventBridge (cada 2 días)
  → Lambda: PATCH /subscriptions({id})
      → Responder validationToken handshake
      → Log confirmación de renovación
```

Ver [[handler-structure]] para patrón de Lambda con respuesta rápida + procesado async.
Ver [[idempotencia-dynamodb]] para evitar duplicados ante reintentos o notificaciones 'collection'.
Ver [[etag-retry-pattern]] para patrón GET→PATCH con retry ante 412.

## Proyectos donde aparece
