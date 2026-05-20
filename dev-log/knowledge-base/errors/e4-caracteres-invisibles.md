---
tags: [error-resuelto, prestashop, encoding, strings]
created: 2026-05-20
project: prestashop-holded-middleware-prod
fuente: PROJECT_DNA.md §9 E4, §5 PRESTASHOP
---

# E4 — Caracteres invisibles U+200E en strings de PrestaShop

#error-resuelto #prestashop #encoding

## Síntoma

Contactos existentes en [[holded]] no encontrados aunque el nombre parecía idéntico visualmente.
La búsqueda paginada de contactos devolvía 0 resultados para nombres que claramente existían en Holded.

## Evidencia en el código

`prestashop.mapper.ts` — función `cleanStr()` con regex `/[‎‏]/g`:
```typescript
function cleanStr(str: string): string {
  // Elimina caracteres de dirección de texto (LTR/RTL marks) invisibles
  // U+200E (LEFT-TO-RIGHT MARK) y U+200F (RIGHT-TO-LEFT MARK)
  return str.replace(/[‎‏]/g, '').trim();
}
```

## Causa raíz

[[prestashop]] inyecta el carácter Unicode U+200E (LEFT-TO-RIGHT MARK, LTR mark) en strings de nombres de cliente y producto. Este carácter es **completamente invisible** en la mayoría de interfaces pero rompe las comparaciones de string.

```
"Juan García"  ← string de PrestaShop con U+200E invisible
"Juan García"  ← string en Holded sin U+200E
→ comparación falla aunque se vea igual
```

Impacto concreto: el sistema creaba contactos duplicados en Holded porque no encontraba el existente por el nombre corrompido.

## Solución aplicada

`cleanStr()` aplicado a todos los strings de nombre antes de:
1. Guardar en DynamoDB
2. Comparar con datos de Holded
3. Enviar a Holded como parte de la factura

## Regla derivada

**Nunca comparar strings de PrestaShop directamente.**
Siempre pasar por `cleanStr()` antes de cualquier comparación o persistencia.

## Plataforma involucrada

[[prestashop]] — gotcha G2 de la plataforma

## Proyecto donde ocurrió

[[prestashop-holded-middleware-prod]]
