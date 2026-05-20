---
tags: [error, holded, auth, breaking-change, migracion]
created: 2026-05-20
confirmaciones: 1
proyectos: [deteccion-via-docs-oficiales]
severity: high
auth_discrepancy: true
---

# holded-auth-change-bearer — Holded API v2: auth incompatible con v1

#error #holded #breaking-change

Detectado: 2026-05-20 via auditoría de docs oficiales (`holded.com/es/desarrolladores`).
**Confirmaciones: 1 — [anécdota — confirmar en siguiente proyecto con Holded]**

## Qué cambió

| Campo | v1 (producción actual) | v2 (nueva) |
|-------|------------------------|------------|
| Header auth | `key: {API_KEY}` | `Authorization: Bearer sk_live_{API_KEY}` |
| URL base | `https://api.holded.com/api/invoicing/v1` | `https://api.holded.com/api/v2/` |
| Scopes | Ninguno (acceso total) | Granulares: `sales:invoices.read`, etc. |
| Estado | Deprecated (operativa) | Activa — docs oficiales |
| Error auth | Fallo opaco (sin 401) | HTTP 403 explícito |

## Proyectos afectados

- [[prestashop-holded-middleware-prod]] — usa v1, **en riesgo de deprecación futura**

## Impacto si no se migra

Cuando Holded retire v1 (fecha sin anunciar):
- Todas las llamadas a la API fallarán — sin facturas, sin abonos, sin sync
- El fallo será total y simultáneo, no gradual
- Sin avisos previos garantizados (deprecated ≠ aviso de shutdown)

## Cómo migrar — checklist

```
[ ] 1. Confirmar con el cliente si su cuenta Holded ya tiene v2 activa
[ ] 2. Obtener nueva API key v2 desde Ajustes → API en el panel Holded
       (formato: sk_live_...)
[ ] 3. Actualizar SECRETS_MANAGER_SECRET_NAME con la nueva key
[ ] 4. En holded.service.ts — cambiar el header de auth:
       ANTES:  headers: { 'key': process.env.HOLDED_API_KEY }
       DESPUÉS: headers: { 'Authorization': `Bearer ${process.env.HOLDED_API_KEY}` }
[ ] 5. Actualizar URL base:
       ANTES:  https://api.holded.com/api/invoicing/v1
       DESPUÉS: https://api.holded.com/api/v2/
[ ] 6. Verificar equivalencia de endpoints (estructura v2 aún en investigación)
[ ] 7. Actualizar API_PROFILE en Research para futuros proyectos
[ ] 8. Ejecutar suite QA completa antes de desplegar
[ ] 9. Despliegue con DevOps — protocolo estándar
```

## Código de migración

```typescript
// ── ANTES (v1) ──────────────────────────────────────────────────────────────
private readonly client = axios.create({
  baseURL: 'https://api.holded.com/api/invoicing/v1',
  headers: {
    'key': process.env.HOLDED_API_KEY!,
    'Content-Type': 'application/json',
  },
});

// ── DESPUÉS (v2) ─────────────────────────────────────────────────────────────
private readonly client = axios.create({
  baseURL: 'https://api.holded.com/api/v2',
  headers: {
    'Authorization': `Bearer ${process.env.HOLDED_API_KEY!}`,
    'Content-Type': 'application/json',
  },
});
```

## Variables de entorno afectadas

| Variable | v1 | v2 |
|----------|----|----|
| `HOLDED_API_KEY` | Key sin prefijo | Key con prefijo `sk_live_` |
| URL base | Hardcoded en servicio | Hardcoded en servicio (cambiar) |

## Pendiente de investigar (Research)

- Equivalencias exactas de endpoints v1 → v2 (¿`/documents/invoice` → `/invoices`?)
- Estructura de respuesta v2 — ¿sigue siendo `{ status: 1, id: "..." }`?
- Scopes necesarios para las operaciones del proyecto (facturas, abonos, contactos, cobros)
- Fecha estimada de shutdown de v1

## Señal de alerta en producción

Si los logs de CloudWatch muestran respuestas inesperadas de Holded sin cambiar código,
verificar si v1 fue retirada. Síntoma probable: HTTP 410 Gone o HTTP 404 en todos los endpoints.

## Relaciones

- [[holded]] — plataforma afectada
- [[prestashop-holded-middleware-prod]] — proyecto en riesgo
- [[handler-structure]] — handler a migrar (holded.service.ts)
- [[idempotencia-dynamodb]] — no afectado por este cambio

*Detectado por Scribe en auditoría de documentación oficial — 2026-05-20*
