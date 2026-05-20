---
tags: [plataforma, prestashop, ecommerce]
created: 2026-05-20
project: prestashop-holded-middleware-prod
fuente: PROJECT_DNA.md §5, PROJECT_DNA_COMPLEMENT.md ADR-6 ADR-7
---

# PrestaShop — Perfil de integración

#prestashop #plataforma

Plataforma de ecommerce. Integrada con [[holded]] en [[prestashop-holded-middleware-prod]].

## Autenticación

- Método: **ws_key como query param** en cada request
- URL base: `https://{shop_domain}/api`
- Formato: `?ws_key={API_KEY}&output_format=JSON&display=full`
- `[confirmado en producción]`

> ⚠️ La documentación oficial describe Basic Auth (base64 de 'apikey:'). El proyecto real usa ws_key como query param. Ambos funcionan pero no mezclar.

## Formato de respuesta

- **XML por defecto** — SIEMPRE añadir `?output_format=JSON` a cada request
- Sin `output_format=JSON` el parseo falla silenciosamente
- Añadir `&display=full` para obtener todos los campos del recurso
- `[confirmado en producción]`

## Paginación

- Tipo: `limit` + `offset` como query params
- Tamaño de página recomendado: 100
- `[oficial]`

## Fechas

- Formato: ISO 8601 sin timezone — asumir UTC
- **Campo de polling: `date_upd`, no `date_add`**
- Razón: un pedido puede crearse semanas antes de pagarse. `date_upd` captura el momento del cambio de estado. `date_add` perdería pedidos antiguos que acaban de pagarse.
- Fuente: ADR-7 en [[prestashop-holded-middleware-prod]]
- `[confirmado en producción]`

## Rate limits

- No documentados oficialmente
- Aplicar retry ×3 con backoff exponencial ante 429 o 5xx
- Fuente: ADR-6 en [[prestashop-holded-middleware-prod]]
- `[confirmado en producción]`

## Endpoints validados en producción

```
GET /orders?filter[id]={id}&output_format=JSON&display=full
GET /orders?filter[date_upd]=[desde,hasta]&sort=date_upd_DESC&output_format=JSON&display=full
GET /customers?filter[id]={id}&output_format=JSON&display=full
GET /addresses?filter[id]={id}&output_format=JSON&display=full
GET /products?output_format=JSON&display=full&limit=100&offset={n}
GET /products?filter[id]=[id1|id2|id3]&output_format=JSON&display=full
GET /categories?filter[id]=[3,99999]&limit=100&output_format=JSON
```

## Gotchas críticos

### G1 — order_rows en 3 formatos distintos
→ Ver [[e3-order-rows-tres-formatos]]

PrestaShop devuelve `order_rows` en formato distinto según número de líneas:
- Formato 1: string vacío `""` — pedido sin líneas
- Formato 2: objeto singular `{ order_row: { id, nombre, ... } }` — pedido con una línea
- Formato 3: array `[ { id, ... }, { id, ... } ]` — pedido con múltiples líneas

Si solo manejas el array, rompes en producción con pedidos de una sola línea. `[confirmado en producción]`

### G2 — Caracteres invisibles U+200E (LTR mark)
→ Ver [[e4-caracteres-invisibles]]

PrestaShop inyecta U+200E en strings de nombres de cliente y producto.
Impacto: comparaciones fallan silenciosamente. `cleanStr()` necesario antes de guardar o comparar. `[confirmado en producción]`

### G3 — Nombres multi-idioma en 3 formatos
→ Ver [[e1-object-object-nombres]]

El campo `name` de un producto puede llegar como:
- Formato 1: `"Camiseta azul"` — string directo
- Formato 2: `[ { id: "1", value: "Camiseta azul" } ]` — array con objetos
- Formato 3: `{ language: [ { value: "Camiseta azul" } ] }` — objeto anidado

Serializar directamente produce `[object Object]` en DynamoDB. `[confirmado en producción]`

### G4 — IVA no viene como porcentaje explícito

PrestaShop expone precio con IVA y precio sin IVA. El porcentaje se infiere:
```
raw = ((precioConIVA - precioSinIVA) / precioSinIVA) * 100
snap a tipos españoles: [0, 4, 10, 21]
```
`[confirmado en producción]`

### G5 — product_id es inestable

`product_id` puede cambiar si el producto se recrea en PrestaShop.
Clave estable: `product_reference` (SKU).
Impacto: usar `product_id` como PK genera duplicados o pérdidas al recrear productos.
Fuente: ADR-2 (ProductsTable con PK = product_reference) en [[prestashop-holded-middleware-prod]].
`[confirmado en producción]`

### G6 — 404 es caso normal

Un pedido o cliente eliminado devuelve 404. No es error fatal.
Tratar como `null` o array vacío `[]` y continuar.
`[confirmado en producción]`

### G7 — SSL autofirmado en instancias de desarrollo

Las HTTPS requests pueden fallar en entornos de test del cliente.
Configurar agente HTTP con `rejectUnauthorized: false` solo en dev.
`[confirmado en producción]`

### G8 — Algunos campos devuelven string vacío en lugar de array vacío

Validación defensiva necesaria antes de iterar sobre cualquier campo de tipo array.
`[confirmado en producción]`

## Relación con [[holded]]

- Los contactos de PrestaShop se buscan en Holded por el campo `code` (= ID del cliente en PrestaShop)
- Los pedidos pagados generan facturas en Holded
- Los pedidos reembolsados generan abonos en Holded

## Proyectos donde aparece

- [[prestashop-holded-middleware-prod]] — integración principal validada en producción
