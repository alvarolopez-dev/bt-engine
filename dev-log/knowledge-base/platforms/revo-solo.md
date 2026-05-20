---
tags: [plataforma, revo, tpv, restauracion, pos, ordering, solo]
created: 2026-05-20
auth_verified_date: 2026-05-20
auth_source: "official docs — api.revo.works/sections/solo.html"
auth_discrepancy: false
---

# Revo SOLO — Perfil de integración

#revo #plataforma #tpv #pos #ordering

Software de pedidos online y quiosco para hostelería (versión simplificada de Revo XEF).
Gestiona catálogo, pedidos de cliente, tarjetas regalo y puntos de fidelización.
Integración relevante: Revo SOLO → [[holded]] (pedidos de cliente → facturas).

```json
{
  "platform": "Revo SOLO",
  "versions_validated": ["v1", "v2"],
  "confidence": "high",
  "source": "[oficial — api.revo.works/sections/solo.html — 2026-05-20]",

  "auth": {
    "method": "Bearer Token + Header de cuenta (sin client-token — diferencia clave vs XEF)",
    "modos": {
      "api_token": {
        "descripcion": "Server-to-server — para operaciones de backoffice y catálogo",
        "headers_required": {
          "Authorization": "Bearer {api-token}",
          "account":       "{account-username}"
        },
        "credentials_obtener": {
          "api-token":        "Back-Office > Others > Development",
          "account-username": "Nombre de usuario de la cuenta Revo SOLO"
        }
      },
      "customer_token": {
        "descripcion": "Sesión de cliente — para operaciones en nombre de un cliente final",
        "headers_required": {
          "Authorization": "Bearer {customer-token}",
          "account":       "{account-username}"
        },
        "credentials_obtener": {
          "customer-token": "POST /api/v1/customer/login o POST /api/v1/customer/register",
          "prerequisito":   "Requiere POS Integration activa con cuenta Xef: Settings > POS Integrations"
        }
      },
      "public": {
        "descripcion": "Endpoints públicos — catálogo, tiendas, turnos (sin token de autorización)",
        "headers_required": {
          "account": "{account-username}"
        }
      }
    },
    "warning": "SOLO NO requiere client-token de integrador — a diferencia de Revo XEF. Solo dos headers: Authorization + account. Confundir los dos productos genera errores de auth difíciles de diagnosticar.",
    "source": "[oficial]"
  },

  "base_urls": {
    "v2_api_token":  "https://revosolo.works/api/v2/",
    "v1_customer":   "https://revosolo.works/api/v1/",
    "v1_public":     "https://revosolo.works/api/v1/customer",
    "warning": "v2 para operaciones con API token (catálogo, tiendas, puntos). v1 para operaciones de cliente (pedidos, tarjetas, perfil) y endpoints públicos. No mezclar versiones.",
    "source": "[oficial]"
  },

  "rate_limits": {
    "requests_per_minute": "No documentado — investigar antes del primer proyecto",
    "max_payload_size":    "No documentado — investigar antes del primer proyecto",
    "recommendation":      "Cachear respuestas GET de catálogo y tiendas — especialmente los sync endpoints con patrón new/updated/deleted",
    "source": "[oficial — sin datos explícitos]"
  },

  "pagination": {
    "type":    "No documentada explícitamente",
    "warning": "Los endpoints de sync usan parámetro `from` (timestamp) para obtener cambios incrementales — patrón diferente a paginación clásica. Usar `from` en cada llamada para evitar re-procesar todo el catálogo.",
    "sync_pattern": {
      "param":            "from",
      "tipo":             "timestamp",
      "response_shape":   {"data": {"new": "array", "updated": "array", "deleted": "array"}}
    },
    "source": "[oficial]"
  },

  "date_format": {
    "format":   "YYYY-MM-DD o YYYY-MM-DD HH:mm:ss",
    "uso":      "Parámetro `until` en updateStatus acepta YYYY/MM/DD HH:mm (barras, no guiones)",
    "warning":  "Dos formatos de fecha según contexto: guiones para filtros generales, barras para el parámetro `until` de updateStatus. Verificar en cada endpoint.",
    "source":   "[oficial]"
  },

  "http_codes": {
    "success":   "200 OK (confirmado para POST /catalog/updateStatus)",
    "warning":   "Solo se documenta explícitamente 200. A diferencia de Revo XEF (que usa 201), SOLO parece usar 200. Verificar en primera integración real.",
    "source":    "[oficial — cobertura parcial]"
  },

  "webhooks": {
    "available": false,
    "warning":   "Revo SOLO NO tiene webhooks nativos documentados. La arquitectura debe ser polling, no event-driven. Diferencia crítica vs Revo XEF.",
    "alternativa": "Polling periódico sobre GET /customer/orders y endpoints de sync con parámetro `from`",
    "source":    "[oficial — ausencia confirmada en documentación]"
  },

  "endpoints_relevantes_holded": {
    "descripcion": "Endpoints clave para integración Revo SOLO → Holded (pedidos de cliente → facturas)",
    "endpoints": [
      {
        "name":    "Listar pedidos del cliente",
        "method":  "GET",
        "version": "v1",
        "path":    "/api/v1/customer/orders",
        "auth":    "customer_token",
        "note":    "Historial de pedidos del cliente autenticado. Principal fuente para sync → Holded."
      },
      {
        "name":    "Crear pedido",
        "method":  "POST",
        "version": "v1",
        "path":    "/api/v1/customer/orders",
        "auth":    "customer_token",
        "body_fields": [
          "order (JSON)",
          "contents (array: product_id, quantity, price, subtotal, tax, taxAmount, pointsSpent, modifiers, menuContents)",
          "card (uuid — tarjeta regalo)",
          "store (opcional)",
          "delivery (opcional: address, city, phone, geolocation lat/lon, time)"
        ]
      },
      {
        "name":    "Último pedido",
        "method":  "GET",
        "version": "v1",
        "path":    "/api/v1/customer/lastOrder",
        "auth":    "customer_token",
        "note":    "Útil para confirmar procesado del pedido más reciente sin paginar historial completo."
      },
      {
        "name":    "Cerrar pedido",
        "method":  "PUT",
        "version": "v1",
        "path":    "/api/v1/customer/orders/{id}",
        "auth":    "customer_token"
      },
      {
        "name":    "Productos del catálogo (sync)",
        "method":  "GET",
        "version": "v1",
        "path":    "/api/v1/customer/products",
        "auth":    "public",
        "note":    "Incluye `points`, `price`, `tax`, `pointsRequired`. Usar `from` para sync incremental."
      },
      {
        "name":    "Tiendas (sync)",
        "method":  "GET",
        "version": "v1",
        "path":    "/api/v1/customer/stores",
        "auth":    "public",
        "note":    "Devuelve new/updated/deleted. Usar `from` para incremental."
      },
      {
        "name":    "Estado de tienda",
        "method":  "GET",
        "version": "v2",
        "path":    "/api/v2/stores/{store}/status",
        "auth":    "api_token",
        "note":    "Verificar si la tienda está operativa antes de crear pedidos."
      },
      {
        "name":    "Actualizar disponibilidad de producto",
        "method":  "POST",
        "version": "v2",
        "path":    "/api/v2/catalog/updateStatus",
        "auth":    "api_token",
        "params":  "products[] (array de IDs), store (id), active (0/1), until (YYYY/MM/DD HH:mm opcional), alsoNested, reactivateInNested"
      },
      {
        "name":    "Puntos del cliente",
        "method":  "GET",
        "version": "v1",
        "path":    "/api/v1/customer/points",
        "auth":    "customer_token",
        "note":    "Devuelve {points: int}. Útil para mostrar saldo en factura Holded."
      },
      {
        "name":    "Tarjetas regalo",
        "method":  "GET",
        "version": "v1",
        "path":    "/api/v1/customer/cards",
        "auth":    "customer_token",
        "note":    "Lista tarjetas. PUT /{card_uuid} para recargar (importe en céntimos). POST para crear."
      },
      {
        "name":    "URLs de acceso SOLO",
        "method":  "GET",
        "version": "v2",
        "path":    "/api/v2/solo/urls",
        "auth":    "api_token",
        "params":  "stores[] (array opcional)",
        "note":    "Devuelve todas las URLs de acceso al frontend SOLO por tienda."
      }
    ]
  },

  "arquitectura_recomendada": {
    "trigger": "polling — sin webhooks nativos en Revo SOLO",
    "warning": "Sin webhooks, no hay forma de recibir notificación push de pedidos cerrados. El polling debe ser frecuente para minimizar latencia en facturación.",
    "flujo_revo_holded": [
      "1. Scheduled Lambda cada N minutos (o EventBridge cron)",
      "2. GET /api/v1/customer/orders para cada cuenta — filtrar por pedidos no procesados",
      "3. Comparar con registro en DynamoDB (idempotencia) para evitar duplicados",
      "4. Para cada pedido nuevo cerrado: POST Holded invoice con datos del pedido",
      "5. Marcar pedido como procesado en DynamoDB con timestamp"
    ],
    "alternativa_sync_catalogo": "GET /customer/products y /customer/stores con param `from` — incremental, eficiente",
    "intervalo_recomendado": "5-15 minutos según SLA del cliente — no documentado límite mínimo de Revo SOLO"
  },

  "gotchas": [
    {
      "issue":   "Revo SOLO NO usa client-token — confundir con Revo XEF es error frecuente",
      "impact":  "Añadir client-token (requerido en XEF) a llamadas SOLO puede causar errores o comportamiento inesperado. Los dos productos tienen esquemas de auth distintos.",
      "fix":     "SOLO: Authorization + account únicamente. XEF: tenant + Authorization + client-token.",
      "source":  "[oficial]"
    },
    {
      "issue":   "Sin webhooks — arquitectura obligatoriamente por polling",
      "impact":  "Latencia en facturación Holded proporcional al intervalo de polling. No hay push nativo.",
      "defensive_strategy": "Documentar en acuerdo con cliente el intervalo de sync y latencia esperada. SLA mínimo realista: 5 min.",
      "source":  "[oficial — ausencia confirmada]"
    },
    {
      "issue":   "Importe de tarjetas regalo expresado en céntimos (int)",
      "impact":  "PUT /customer/cards/{uuid} espera `amount` en céntimos. Enviar euros genera importes 100x incorrectos.",
      "fix":     "Multiplicar por 100 antes de enviar. Dividir por 100 al mostrar.",
      "source":  "[oficial]"
    },
    {
      "issue":   "Tax expresado en puntos base (basis points): 1000 = 10%",
      "impact":  "Interpretar `tax: 1000` como 1000% destruye el cálculo de factura.",
      "fix":     "Dividir entre 10000 para obtener el porcentaje decimal (1000 / 10000 = 0.10 = 10%).",
      "source":  "[oficial]"
    },
    {
      "issue":   "Delivery shifts sobreescriben turnos estándar cuando `store.use_delivery_shifts=true`",
      "impact":  "Llamar a /customer/shifts cuando la tienda usa delivery shifts devuelve horarios incorrectos para pedidos a domicilio.",
      "fix":     "Verificar `store.use_delivery_shifts` y llamar a /customer/deliveryShifts en ese caso.",
      "source":  "[oficial]"
    },
    {
      "issue":   "Customer token requiere integración POS activa con cuenta Xef",
      "impact":  "Sin activar Settings > POS Integrations en el panel SOLO, el endpoint /customer/login no funciona.",
      "defensive_strategy": "Verificar en fase de Intake que el cliente tiene la integración POS activada antes de comenzar desarrollo.",
      "source":  "[oficial]"
    },
    {
      "issue":   "Endpoints de sync usan patrón new/updated/deleted con param `from`, no paginación clásica",
      "impact":  "Sin `from`, se obtiene el catálogo completo en cada llamada. Con muchos productos, es ineficiente y puede acercarse a límites no documentados.",
      "fix":     "Persistir el timestamp de la última sync en DynamoDB y pasar `from` en cada llamada.",
      "source":  "[oficial]"
    },
    {
      "issue":   "Parámetro `until` en updateStatus usa formato YYYY/MM/DD HH:mm (barras), diferente al formato general YYYY-MM-DD (guiones)",
      "impact":  "Enviar fecha con guiones en `until` puede causar error de parseo silencioso.",
      "fix":     "Usar barras exclusivamente para el parámetro `until`.",
      "source":  "[oficial]"
    },
    {
      "issue":   "Rate limits y tamaño máximo de payload no documentados",
      "impact":  "Desconocido hasta primera integración en producción. Riesgo de throttling inesperado.",
      "defensive_strategy": "Implementar exponential backoff desde el inicio. Cachear agresivamente catálogo y tiendas.",
      "source":  "[oficial — ausencia confirmada]"
    }
  ]
}
```

## Arquitectura Lambda para Revo SOLO → Holded

Sin webhooks nativos → polling obligatorio. Diferencia fundamental vs Revo XEF.

```
EventBridge cron (cada 5-15 min)
  → Lambda polling
      → GET /api/v1/customer/orders (por cuenta)
      → Filtrar pedidos no procesados
      → Consultar DynamoDB (idempotencia) ← CRÍTICO: evita facturas duplicadas
          → Para cada pedido nuevo cerrado:
              → POST Holded invoice
              → Marcar procesado en DynamoDB con timestamp
```

Para sync de catálogo (independiente del flujo de pedidos):

```
EventBridge cron (cada hora o bajo demanda)
  → Lambda sync catálogo
      → Leer `last_sync_at` de DynamoDB
      → GET /customer/products?from={last_sync_at}
      → GET /customer/stores?from={last_sync_at}
      → Procesar new/updated/deleted
      → Actualizar `last_sync_at` en DynamoDB
```

Ver [[idempotencia-dynamodb]] para patrón de deduplicación.
Ver [[handler-structure]] para estructura base de Lambda.

## Proyectos donde aparece

*(Sin proyectos aún)*
