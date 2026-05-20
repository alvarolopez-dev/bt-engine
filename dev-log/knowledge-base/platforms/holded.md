---
tags: [plataforma, holded, erp, contabilidad, breaking-change]
created: 2026-05-20
auth_verified_date: 2026-05-20
auth_source: "official docs (holded.com/es/desarrolladores) + proyecto real prestashop-holded-middleware-prod"
auth_discrepancy: true
project: prestashop-holded-middleware-prod
fuente: PROJECT_DNA.md §5, PROJECT_DNA_COMPLEMENT.md ADR-3 ADR-5
---

# Holded — Perfil de integración

#holded #plataforma

ERP y software de contabilidad. Recibe datos de [[prestashop]] en [[prestashop-holded-middleware-prod]].

## ⚠️ BREAKING CHANGE — Holded API v2 (mayo 2026)

> Ver nodo completo: [[holded-auth-change-bearer]]

Holded lanzó API v2 en mayo 2026 con **autenticación incompatible** con v1.
El proyecto de referencia (`prestashop-holded-middleware-prod`) usa v1 y **está en riesgo de deprecación**.
v1 sigue operativa pero es deprecated. No hay fecha de shutdown publicada.

## Autenticación

### v1 — En producción actual `[confirmado en producción]`

- Header: `key: {HOLDED_API_KEY}` — literal minúscula `key`
- URL base: `https://api.holded.com/api/invoicing/v1`
- **Sin** `Authorization`, sin `Bearer`, sin `X-API-Key`
- Fallo opaco si el header está mal (no devuelve 401 — simplemente falla)

```typescript
// v1 — proyecto actual
headers: { 'key': process.env.HOLDED_API_KEY }
```

### v2 — Docs oficiales, mayo 2026 `[oficial]`

- Header: `Authorization: Bearer sk_live_{HOLDED_API_KEY}`
- URL base: `https://api.holded.com/api/v2/`
- Permisos granulares por scope: `sales:invoices.read`, `sales:invoices.write`, etc.
- Formato de API key: prefijo `sk_live_`
- Respuesta correcta ante error: **HTTP 403** si permisos insuficientes

```typescript
// v2 — nueva
headers: { 'Authorization': `Bearer ${process.env.HOLDED_API_KEY}` }
```

### Cuándo usar cada versión

| Escenario | Versión | Header |
|-----------|---------|--------|
| Proyecto existente (prestashop-holded-middleware-prod) | v1 | `key: ...` |
| Proyecto nuevo desde mayo 2026 | v2 | `Authorization: Bearer ...` |
| Migración de proyecto existente | v1 → v2 | Ver [[holded-auth-change-bearer]] |

> ⚠️ Research debe preguntar al cliente qué versión usa su cuenta antes de definir el API_PROFILE.

## Detección de éxito

- **HTTP 200 no garantiza éxito**
- El único indicador fiable: `response.data.status === 1` con campo `id` presente
- Si `status !== 1`, la operación falló aunque el código HTTP sea 200
- `[confirmado en producción]`

```typescript
// Patrón correcto de verificación de éxito en Holded
if (response.data?.status !== 1 || !response.data?.id) {
  throw new Error(`Holded error: ${JSON.stringify(response.data)}`);
}
const docId = response.data.id; // ID interno de 24 chars
```

## Formato de fechas

- **Unix timestamp (segundos)** — NO acepta ISO 8601
- Convertir siempre antes de enviar: `Math.floor(new Date(fechaISO).getTime() / 1000)`
- `[confirmado en producción]`

## Formato de IDs

- Todos los IDs internos de Holded son **strings alfanuméricos de 24 caracteres**
- No son UUIDs estándar
- Ejemplo: `"5f3a2b1c4d8e9f0a1b2c3d4e"`
- `[confirmado en producción]`

## Paginación de contactos

- 100 contactos por página
- Parámetro: `page` (entero)
- **Empieza en `page=1`, no `page=0`**
- Máximo recomendado: ~10 páginas (1.000 contactos)
- Búsqueda: por campo `code` del contacto (= ID del cliente en [[prestashop]])
- `[confirmado en producción]`

## Rate limits

- 60 requests por minuto
- Con múltiples Lambdas concurrentes puede saturarse
- Comportamiento al superar: no documentado explícitamente — aplicar estrategia defensiva
- `[confirmado en producción]`

## Endpoints validados en producción

### v1 `[confirmado en producción]`

```
GET  /contacts?page={n}                    ← búsqueda paginada
POST /contacts                             ← crear contacto (campo type obligatorio: 'client' | 'supplier')
GET  /chartaccounts                        ← plan de cuentas
GET  /products                             ← catálogo completo
POST /products                             ← crear producto
POST /documents/invoice                    ← crear factura
POST /documents/creditnote                 ← crear abono
POST /documents/{id}/paymentcreate        ← registrar cobro
```

### v2 `[oficial — sin validar en producción]`

```
Base: https://api.holded.com/api/v2/
GET  /invoices                             ← equivalente a /documents/invoice en v1
POST /invoices                             ← crear factura
```

> ⚠️ Estructura de endpoints v2 en investigación. Research debe documentar equivalencias completas antes de cualquier migración.

## Gotchas críticos

### G1 — accountingAccountId requiere ID interno de 24 chars
→ Ver [[e6-panel-router-sin-url]] para contexto de infraestructura relacionada

El número de cuenta visible en la interfaz (ej: `"700"`) NO funciona como `accountingAccountId`.
Se necesita el ID interno de 24 chars del plan de cuentas (`GET /chartaccounts` → campo `id`).
**Si se envía el número visible, Holded lo ignora silenciosamente** y asigna la cuenta por defecto.
No hay error. La factura se crea. Pero en la cuenta equivocada.
`[confirmado en producción]`

### G2 — Cobro fallido no revierte la factura

Las operaciones de factura y cobro son independientes.
Si `POST /documents/{id}/paymentcreate` falla, la factura ya existe y no se revierte.
Patrón correcto: log.warn + continuar. Ver [[degradacion-silenciosa]].
`[confirmado en producción]`

### G3 — Contacto no encontrado → crear nuevo, no fallar

Si el contacto no existe en Holded, crearlo en el momento.
El pedido no debe fallar por esto.
La búsqueda de contactos es paginada — buscar hasta ~10 páginas antes de declarar "no existe".
`[confirmado en producción]`

### G4 — productId en facturas vincula al catálogo de Holded

El campo `productId` en líneas de factura referencia el catálogo interno de Holded.
El producto debe existir en el catálogo antes de referenciar su ID.
Si `ENABLE_PRODUCT_SYNC=false`, no incluir `productId` en las líneas.
`[confirmado en producción]`

### G5 — Algunos planes requieren companyId

En planes Enterprise con múltiples empresas, las llamadas sin `companyId` afectan a la empresa por defecto.
Confirmar con el cliente si tiene plan multi-empresa.
`[inferido — confirmar si aparece en nuevos proyectos]`

### G6 — API v2 lanzada mayo 2026 — auth incompatible con v1

v1 usa `key: ...`. v2 usa `Authorization: Bearer sk_live_...`.
No hay compatibilidad entre versiones.
Proyectos existentes que usen v1 seguirán funcionando mientras Holded no retire v1.
**Proyectos nuevos deben usar v2 desde el inicio.**
Ver [[holded-auth-change-bearer]] para análisis completo e impacto de migración.
`[oficial — detectado 2026-05-20]`

## Panel de administración (tier Pro/Pro+)

Expone endpoints REST para gestión manual. Ver ADR-3 en [[prestashop-holded-middleware-prod]].

> ⚠️ **Corrección crítica ADR-3**: El panel usa `AuthType: NONE` en la Lambda Function URL, NO `AuthType: AWS_IAM`. CloudFront OAC+SigV4 fue descartado por un bug de AWS donde POST/PUT usan `UNSIGNED-PAYLOAD` en el header de autenticación, rompiendo la firma. CLAUDE.md del proyecto documenta AWS_IAM incorrectamente — el `serverless.yml` es la fuente de verdad.

## Relación con [[prestashop]]

- Recibe pedidos pagados como facturas
- Recibe pedidos reembolsados como abonos
- Los contactos se buscan por el campo `code` (= ID de cliente en PrestaShop)

## Proyectos donde aparece

- [[prestashop-holded-middleware-prod]] — integración principal validada en producción
