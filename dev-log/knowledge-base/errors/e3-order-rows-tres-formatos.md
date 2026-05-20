---
tags: [error-resuelto, prestashop, parsing, order-rows]
created: 2026-05-20
project: prestashop-holded-middleware-prod
fuente: PROJECT_DNA.md §9 E3, §5 PRESTASHOP
---

# E3 — order_rows en 3 formatos distintos

#error-resuelto #prestashop #parsing

## Síntoma

`TypeError` en producción al procesar ciertos pedidos.
Pedidos con una sola línea fallaban mientras que pedidos multi-línea funcionaban correctamente.

## Evidencia en el código

`prestashop.mapper.ts` líneas 61-79 — 3 casos de extracción separados para manejar los formatos.

## Causa raíz

[[prestashop]] devuelve el campo `order_rows` en 3 formatos distintos según el número de líneas y la versión:

| Caso | Formato | Ejemplo |
|------|---------|---------|
| Sin líneas | String vacío | `""` |
| Una línea | Objeto singular | `{ order_row: { id: "1", product_name: "..." } }` |
| Múltiples líneas | Array | `[ { id: "1", ... }, { id: "2", ... } ]` |

El código original asumía siempre array. Al llegar un objeto singular, `.forEach()` fallaba con TypeError.

## Solución aplicada

Función `normalizarOrderRows()` que detecta el formato y devuelve siempre un array:

```typescript
function normalizarOrderRows(raw: unknown): OrderRow[] {
  // Caso 1: sin líneas
  if (!raw || raw === '') return [];

  // Caso 2: objeto singular { order_row: {...} }
  if (typeof raw === 'object' && !Array.isArray(raw) && 'order_row' in (raw as object)) {
    const inner = (raw as { order_row: unknown }).order_row;
    return Array.isArray(inner) ? inner as OrderRow[] : [inner as OrderRow];
  }

  // Caso 3: array directo
  if (Array.isArray(raw)) return raw as OrderRow[];

  return [];
}
```

## Relación con otros errores

- Mismo patrón de múltiples formatos afecta a nombres de producto → [[e1-object-object-nombres]]

## Plataforma involucrada

[[prestashop]] — gotcha G1 de la plataforma

## Proyecto donde ocurrió

[[prestashop-holded-middleware-prod]]
