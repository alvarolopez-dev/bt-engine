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
| [[holded]] | [[prestashop-holded-middleware-prod]] | 6 gotchas confirmados en producción |
| [[revo-xef]] | *(sin proyectos aún)* | 7 gotchas documentados (docs oficiales) |
| [[revo-retail]] | *(sin proyectos aún)* | 7 gotchas — `username` header (≠ tenant), 200 no 201, batch all-or-nothing |
| [[revo-flow]] | *(sin proyectos aún)* | 3 gotchas — sin webhooks, `ok===true` check, booking.status numérico sin documentar |
| [[revo-solo]] | *(sin proyectos aún)* | 6 gotchas — sin webhooks, `account` header, tax en basis points |
| [[stripe]] | *(sin proyectos aún)* | 5 gotchas — amounts en cents, raw body para firma HMAC, anti-replay 300s |
| [[woocommerce]] | *(sin proyectos aún)* | 5 gotchas — permalinks WordPress prerequisito, timezone por sitio |
| [[shopify]] | *(sin proyectos aún)* | 6 gotchas — version pinning trimestral, webhook secret por endpoint |
| [[zoho-crm]] | *(sin proyectos aún)* | 5 gotchas — notifications expiran 72h, data center `.eu` para España |
| [[business-central]] | *(sin proyectos aún)* | 6 gotchas — ETag/If-Match obligatorio, suscripciones expiran 3 días |

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
| [[holded-auth-change-bearer]] | [[holded]] | API v2: `Authorization: Bearer` rompe proyectos v1 | Migrar header + URL base |

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

## ⚠️ Breaking changes detectados

| Cambio | Plataforma | Detectado | Impacto |
|--------|-----------|-----------|---------|
| [[holded-auth-change-bearer]] | [[holded]] | 2026-05-20 | Alto — proyectos v1 en riesgo de deprecación |

---

## Correcciones críticas documentadas

> ⚠️ **ADR-3 en prestashop-holded-middleware-prod**: La configuración del panel usa `AuthType: NONE` (Lambda URL pública detrás de CloudFront). CLAUDE.md del proyecto documenta `AuthType: AWS_IAM` incorrectamente. CloudFront OAC+SigV4 fue descartado por un bug de AWS con POST/PUT. **El `serverless.yml` es siempre la fuente de verdad**, no CLAUDE.md ni la documentación narrativa.

---

## Conocimiento AWS validado en producción

| Nodo | Descripción | Confianza |
|------|-------------|-----------|
| [[architecture-decision-tree]] | Árbol decisión: webhooks → Lambda URL; polling → Step Functions | High — producción |
| [[lambda-patterns]] | P1-P10: handler structure, singleton, error handling 3 niveles, Pino, retry | High — 4 Lambdas producción |
| [[serverless-framework-v3]] | IaC, patrón 3 tiers, CloudFront condicional, ADR-4/8 | High — producción |
| [[dynamodb-patterns]] | PAY_PER_REQUEST, ConditionalCheck, snake_case ES, antipatrón E5 | High — 5 tablas producción |
| [[step-functions-express]] | Express vs Standard, ADR-2 fetch+process separados, EventBridge cron | High — producción |

**Stack AWS validado:** Serverless Framework v3.38.0 · Node.js 20.x · TypeScript · eu-west-2

---

## Estadísticas de la red

- **Total nodos:** 30
- **Plataformas:** 11
- **Patrones:** 4
- **Errores resueltos:** 6 (+ 1 breaking change)
- **Breaking changes:** 1
- **Históricos de coste:** 1
- **Proyectos:** 1
- **Nodos AWS:** 5
- **Índice:** 1

### Nodos con más enlaces entrantes

| Nodo | Enlaces entrantes | Por qué es central |
|------|------------------|--------------------|
| [[prestashop-holded-middleware-prod]] | 17 | Referenciado por errores, patrones, costes y todos los nodos AWS |
| [[prestashop]] | 7 | Fuente de 4 de los 6 errores resueltos |
| [[holded]] | 5 | Destino de la integración, referenciado en patrones y errores |
| [[dynamodb-patterns]] | 5 | Referenciado por lambda-patterns, architecture-decision-tree, step-functions |

---

*Última actualización: 2026-05-21*
*Próximo proyecto a documentar: añadir entrada en `projects/` y actualizar este índice.*
