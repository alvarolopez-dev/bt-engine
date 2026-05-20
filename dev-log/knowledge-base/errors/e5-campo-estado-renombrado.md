---
tags: [error-resuelto, dynamodb, migracion, campo-renombrado]
created: 2026-05-20
project: prestashop-holded-middleware-prod
fuente: PROJECT_DNA.md §9 E5
---

# E5 — Campo `estado` renombrado a `estado_procesado` sin migración

#error-resuelto #dynamodb #migracion

## Síntoma

Pedidos ya procesados correctamente volvían a procesarse al día siguiente.
Se creaban facturas duplicadas en [[holded]] para pedidos que ya tenían factura.
El stuckOrdersChecker reportaba pedidos como `pending` cuando deberían estar `invoice_created`.

## Evidencia en el código

Commit `8c5e93e`: `fix(dynamodb): corregir campo estado→estado_procesado`

La función `obtenerPedidosYaProcesados()` filtraba por `estado_procesado` pero los registros existentes en DynamoDB tenían el campo `estado`. El `FilterExpression` no devolvía nada → el sistema asumía que no había pedidos procesados → los reprocesaba todos.

## Causa raíz

El campo DynamoDB `estado` fue renombrado a `estado_procesado` en el código sin migrar los registros existentes en la tabla. Los registros antiguos seguían teniendo `estado`, los nuevos tenían `estado_procesado`. El `FilterExpression` solo buscaba `estado_procesado`.

## Solución aplicada

1. Corrección inmediata: usar ambos nombres en el `FilterExpression` transitoriamente
2. Script de migración para actualizar todos los registros existentes
3. Tras confirmar migración completa: eliminar el nombre antiguo del código

```typescript
// Transición (durante migración):
FilterExpression: 'estado_procesado = :val OR estado = :val',

// Post-migración (solo el nombre nuevo):
FilterExpression: 'estado_procesado = :val',
```

## Regla derivada

**Nunca renombrar un campo de DynamoDB sin plan de migración.**
Los registros existentes no se renombran automáticamente.
Protocolo seguro:
1. Mantener compatibilidad con ambos nombres en el código
2. Ejecutar script de migración sobre todos los registros existentes
3. Verificar que no quedan registros con el nombre antiguo
4. Solo entonces eliminar el nombre antiguo del código

## Proyecto donde ocurrió

[[prestashop-holded-middleware-prod]]
