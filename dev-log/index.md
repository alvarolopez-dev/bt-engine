---
tags: [index, mapa, ecosistema]
created: 2026-05-20
---

# Bigtoone Knowledge Base — Mapa de la red

Memoria permanente del ecosistema de agentes Bigtoone.
Gestionada por el agente Scribe. Actualizada tras cada proyecto.

---

## Plataformas integradas

| Plataforma | Proyectos | Gotchas documentados |
|-----------|-----------|---------------------|
| [[prestashop]] | [[prestashop-holded-middleware-prod]] | 8 gotchas confirmados en producción |
| [[holded]] | [[prestashop-holded-middleware-prod]] | 5 gotchas confirmados en producción |

---

## Patrones técnicos validados

| Patrón | Descripción | Proyectos |
|--------|-------------|-----------|
| [[degradacion-silenciosa]] | Features opcionales que no rompen el flujo principal | [[prestashop-holded-middleware-prod]] |
| [[idempotencia-dynamodb]] | ConditionalExpression para evitar duplicados con Lambdas paralelas | [[prestashop-holded-middleware-prod]] |
| [[patron-3-tiers]] | Features opcionales como tiers comerciales por env vars | [[prestashop-holded-middleware-prod]] |
| [[handler-structure]] | Estructura cargarSecretos → guard → loop → return | [[prestashop-holded-middleware-prod]] |

---

## Errores resueltos

| Error | Plataforma | Síntoma | Patrón |
|-------|-----------|---------|--------|
| [[e1-object-object-nombres]] | [[prestashop]] | `[object Object]` en DynamoDB | `extraerNombre()` |
| [[e2-race-condition-facturas-duplicadas]] | [[holded]] | Facturas duplicadas | [[idempotencia-dynamodb]] |
| [[e3-order-rows-tres-formatos]] | [[prestashop]] | TypeError en pedidos con una línea | `normalizarOrderRows()` |
| [[e4-caracteres-invisibles]] | [[prestashop]] | Contactos no encontrados por nombre | `cleanStr()` |
| [[e5-campo-estado-renombrado]] | DynamoDB | Pedidos re-procesados tras renombrar campo | Migración + compatibilidad |
| [[e6-panel-router-sin-url]] | Serverless v3 | Lambda no condicional por limitación CF | Lambda siempre + URL condicional |

---

## Histórico de costes reales

| Referencia | Integración | Volumen | Coste/mes |
|-----------|-------------|---------|-----------|
| [[prestashop-holded-prod]] | PrestaShop → Holded | ~30 pedidos/día | $0.00–$0.82 |

> El coste dominante en integraciones de bajo volumen es Secrets Manager, no Lambda.

---

## Proyectos documentados

| Proyecto | Estado | Región | Desplegado |
|---------|--------|--------|-----------|
| [[prestashop-holded-middleware-prod]] | Operativo | eu-west-2 | 2026-05-15 |

---

## Correcciones críticas documentadas

> ⚠️ **ADR-3 en prestashop-holded-middleware-prod**: La configuración del panel usa `AuthType: NONE` (Lambda URL pública detrás de CloudFront). CLAUDE.md del proyecto documenta `AuthType: AWS_IAM` incorrectamente. CloudFront OAC+SigV4 fue descartado por un bug de AWS con POST/PUT. **El `serverless.yml` es siempre la fuente de verdad**, no CLAUDE.md ni la documentación narrativa.

---

## Estadísticas de la red

- **Total nodos:** 15
- **Plataformas:** 2
- **Patrones:** 4
- **Errores resueltos:** 6
- **Históricos de coste:** 1
- **Proyectos:** 1
- **Índice:** 1

### Nodos con más enlaces entrantes

| Nodo | Enlaces entrantes | Por qué es central |
|------|------------------|--------------------|
| [[prestashop-holded-middleware-prod]] | 12 | Referenciado por todos los errores, patrones y costes |
| [[prestashop]] | 7 | Fuente de 4 de los 6 errores resueltos |
| [[holded]] | 5 | Destino de la integración, referenciado en patrones y errores |

---

*Última actualización: 2026-05-20*
*Próximo proyecto a documentar: añadir entrada en `projects/` y actualizar este índice.*
