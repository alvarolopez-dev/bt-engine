---
tags: [error-resuelto, prestashop, dynamodb, serialización]
created: 2026-05-20
project: prestashop-holded-middleware-prod
fuente: PROJECT_DNA.md §9 E1, §6 P1
---

# E1 — Nombres `[object Object]` en ProductsTable

#error-resuelto #prestashop #dynamodb

## Síntoma

El panel de administración mostraba `[object Object]` como nombre de producto en lugar del nombre real.
Los registros en DynamoDB `ProductsTable` tenían el campo `name` con el valor literal `"[object Object]"`.

## Evidencia en el código

`product_mapping.service.ts` líneas 141-149:
```typescript
if (existente.name?.includes('[object Object]')) {
  aArreglar.push(p);
}
```
Se añadió corrección automática en cada sincronización para detectar y reparar registros corruptos.

## Causa raíz

[[prestashop]] devuelve el nombre de producto en el campo `name` en **3 formatos distintos** según la versión y configuración de idioma:

- Formato 1: `"Camiseta azul"` — string directo
- Formato 2: `[ { id: "1", value: "Camiseta azul" } ]` — array de objetos
- Formato 3: `{ language: [ { value: "Camiseta azul" } ] }` — objeto anidado

El código original llamaba `.toString()` sobre el campo `name` sin detectar el formato.
Cuando el campo llegaba en Formato 2 o 3 (objeto), `.toString()` producía `"[object Object]"`.

## Solución aplicada

Función `extraerNombre()` que detecta el formato y extrae el string correcto:
```typescript
function extraerNombre(name: unknown): string {
  if (typeof name === 'string') return name;
  if (Array.isArray(name)) return name[0]?.value ?? '';
  if (typeof name === 'object' && name !== null && 'language' in name) {
    const lang = (name as { language: Array<{ value: string }> }).language;
    return Array.isArray(lang) ? lang[0]?.value ?? '' : '';
  }
  return '';
}
```

Además: corrección automática en `syncProducts()` que detecta registros con `[object Object]` y los repara.

## Relación con otros errores

- Mismo patrón de 3 formatos afecta a `order_rows` → ver [[e3-order-rows-tres-formatos]]
- La inestabilidad de `product_id` es relacionada → campo `product_reference` (SKU) como clave estable

## Plataforma involucrada

[[prestashop]] — comportamiento de la API de productos multi-idioma

## Proyecto donde ocurrió

[[prestashop-holded-middleware-prod]]
