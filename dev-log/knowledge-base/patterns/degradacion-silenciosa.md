---
tags: [patron, resiliencia, error-handling, lambda]
created: 2026-05-20
project: prestashop-holded-middleware-prod
fuente: PROJECT_DNA.md §6 P7, PROJECT_DNA_COMPLEMENT.md §4.3
---

# Patrón — Degradación silenciosa en enriquecimiento opcional

#patron #resiliencia #error-handling

El patrón de resiliencia más importante del ecosistema Bigtoone.
Garantiza que ningún fallo de enriquecimiento opcional impide crear la factura principal.

## Principio

Las fases opcionales (contabilidad, cobro, product_sync) usan `try/catch` con `log.warn`.
Si fallan, la operación principal continúa. No hay reversión.

## Cuándo aplicar

- Feature activada por env var (`ENABLE_ACCOUNTING`, `ENABLE_PRODUCT_SYNC`)
- Enriquecimiento que mejora la calidad pero no es esencial para la operación
- Operaciones post-principales cuyo fallo no invalida lo ya creado (ej: registrar cobro tras crear factura)

## Cuándo NO aplicar

- Pasos obligatorios del happy path (obtener contacto, crear factura)
- Operaciones cuyo fallo deja datos en estado incoherente irrecuperable

## Implementación validada

```typescript
// ── OBLIGATORIO — si falla, el pedido no se procesa ─────────────────────────
const contactId = await this.obtenerOCrearContacto(pedido.cliente);
const docId = await this.crearFactura(pedido, contactId); // propaga el error

// ── OPCIONAL — si falla, warn y continúa ────────────────────────────────────
if (ENABLE_ACCOUNTING) {
  try {
    await this.asignarCuentasContables(docId, pedido.lineas);
  } catch (error: unknown) {
    log.warn(
      { error: error instanceof Error ? error.message : String(error) },
      'Error en cuentas contables — factura creada sin asignación contable'
    );
    // No propagamos. La factura existe. El usuario puede asignar manualmente en el panel.
  }
}

// ── POST-PRINCIPAL — cobro después de la factura ─────────────────────────────
try {
  await this.registrarCobro(docId, pedido.total_pagado);
} catch (error: unknown) {
  log.warn(
    { error: error instanceof Error ? error.message : String(error) },
    'Factura creada pero fallo al registrar cobro'
  );
  // La factura existe en Holded. El cobro puede registrarse manualmente.
}
```

## Los 3 tipos de gate (del patrón 3-tiers)

Ver [[patron-3-tiers]] para el contexto completo.

| Tipo de gate | Cuándo | Mecanismo |
|-------------|--------|-----------|
| Infraestructura | Feature crea recursos AWS | `Condition` en CloudFormation |
| Código | Feature no crea recursos AWS | `const ENABLE_X = process.env.ENABLE_X === 'true'` a nivel de módulo |
| Degradación | Feature opcional que no debe romper el flujo | `try/catch` con `log.warn` |

## Invariante

La feature opcional **nunca rompe el flujo base**. Si falla:
- Infraestructura: no se crea (stack básico funciona igual)
- Código: `try/catch` → `log.warn` → continúa con valor por defecto

## Proyectos donde se validó

- [[prestashop-holded-middleware-prod]] — aplicado en accounting, product_sync, registro de cobros
