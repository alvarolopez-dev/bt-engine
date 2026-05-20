---
tags: [proyecto, produccion, prestashop, holded, aws-lambda]
created: 2026-05-20
estado: operativo
region: eu-west-2
desplegado: 2026-05-15
fuente: PROJECT_DNA.md, PROJECT_DNA_COMPLEMENT.md
---

# prestashop-holded-middleware-prod

#proyecto #produccion #prestashop #holded

Middleware serverless que sincroniza pedidos de [[prestashop]] con el ERP [[holded]].
Operativo en `eu-west-2` (Londres) desde 2026-05-15.

## Qué hace

- Descarga pedidos **pagados** de PrestaShop → crea **facturas** en Holded
- Descarga pedidos **reembolsados** de PrestaShop → crea **abonos** en Holded
- Frecuencia: cron 07:00 UTC diario vía EventBridge + Step Functions Express
- Tiers: Basic / Pro (+ panel) / Pro+ (+ sync catálogo)

## Arquitectura

```
EventBridge cron(0 7 * * ? *)
  → Step Functions Express
    → Lambda fetchOrdersPrestashop (60s, 1024MB) → S3
    → [count > 0?]
      → Lambda processOrdersS3 (600s, 1024MB) → DynamoDB + Holded API
      → [error] → SNS email

EventBridge cron(30 8 * * ? *)
  → Lambda stuckOrdersChecker (60s, 1024MB) → SNS si pending > 24h

CloudFront (HTTPS público)
  → Lambda panelRouter (600s, 1024MB) — solo si ENABLE_PANEL=true
```

## Decisiones de arquitectura (ADRs)

| ADR | Decisión | Alternativa descartada |
|-----|----------|----------------------|
| ADR-1 | Step Functions **EXPRESS**, no STANDARD | STANDARD cobra por transición + historial innecesario |
| ADR-2 | **5 tablas** DynamoDB independientes, no single-table | GSIs sin beneficio real (todo acceso por PK) |
| ADR-3 | CloudFront → Lambda URL `AuthType: NONE` | API Gateway (~$3.50/M requests); OAC+SigV4 (bug AWS POST/PUT) |
| ADR-4 | Serverless Framework **v3** congelado | v4 incompatible con plugins usados |
| ADR-5 | **Zod** en boundary de datos externos | Validación manual; confiar en API externa |
| ADR-6 | **axios-retry** ×3 con backoff exponencial | Sin retry; un spike de latencia tira el sync del día |
| ADR-7 | Polling por **`date_upd`**, no `date_add` | `date_add` perdería pedidos creados semanas antes de pagarse |
| ADR-8 | Lambda panelRouter **siempre desplegada**, sin URL si tier Basic | Dos serverless.yml separados (duplicación) |

> ⚠️ **Corrección ADR-3**: CLAUDE.md del proyecto documenta `AuthType: AWS_IAM`. Incorrecto. El `serverless.yml` usa `AuthType: NONE`. CloudFront OAC+SigV4 fue descartado por bug de AWS donde POST/PUT usan `UNSIGNED-PAYLOAD` en el header de auth, rompiendo la firma.

## Errores resueltos en este proyecto

| Error | Síntoma | Patrón aplicado |
|-------|---------|----------------|
| [[e1-object-object-nombres]] | `[object Object]` en ProductsTable | `extraerNombre()` para 3 formatos |
| [[e2-race-condition-facturas-duplicadas]] | Facturas duplicadas en Holded | [[idempotencia-dynamodb]] |
| [[e3-order-rows-tres-formatos]] | TypeError en pedidos de una línea | `normalizarOrderRows()` |
| [[e4-caracteres-invisibles]] | Contactos no encontrados por nombre | `cleanStr()` con U+200E |
| [[e5-campo-estado-renombrado]] | Pedidos re-procesados tras renombrar campo | Migración + compatibilidad transitoria |
| [[e6-panel-router-sin-url]] | Limitación Serverless v3 con Conditions | Lambda siempre desplegada, URL condicional |

## Patrones validados en este proyecto

- [[degradacion-silenciosa]] — accounting, cobros, product_sync
- [[idempotencia-dynamodb]] — evita facturas duplicadas con Step Functions
- [[patron-3-tiers]] — Basic / Pro / Pro+ por env vars
- [[handler-structure]] — 4 handlers siguiendo el patrón cargarSecretos → guard → loop → return

## Stack técnico

```
Runtime:        Node.js 20.x / TypeScript (strict: false — deuda técnica)
Framework:      Serverless Framework v3.38.0
AWS:            Lambda + Step Functions EXPRESS + EventBridge + DynamoDB + S3 + SNS + CloudFront
HTTP:           axios + axios-retry (×3, backoff exponencial)
Validación:     Zod (en boundary StandardOrderSchema)
Logger:         Pino (JSON estructurado)
AWS SDK:        @aws-sdk/* v3 modular
Tests:          Jest + ts-jest
```

## Variables de entorno críticas

| Variable | Default | Requerida en prod |
|----------|---------|------------------|
| `HOLDED_API_KEY` | — | ✅ |
| `HOLDED_SERIE_ID` | — | ✅ |
| `PRESTASHOP_URL` | — | ✅ |
| `PRESTASHOP_API_KEY` | — | ✅ |
| `ALERT_EMAIL` | — | ✅ |
| `ORDER_PAID_STATE_ID` | `'2'` | (verificar con cliente) |
| `ENABLE_PANEL` | `false` | Solo tier Pro/Pro+ |
| `ENABLE_ACCOUNTING` | `false` | Solo tier Pro |
| `ENABLE_PRODUCT_SYNC` | `false` | Solo tier Pro+ |
| `SECRETS_MANAGER_SECRET_NAME` | `''` | Recomendado en prod |

## Coste real en producción

Ver [[prestashop-holded-prod]] para desglose completo.
Resumen: **$0.00-$0.82/mes** según configuración de Secrets Manager.
Coste dominante: Secrets Manager ($0.40/secreto/mes), no Lambda.

## DynamoDB — 5 tablas

| Tabla | PK | Propósito |
|-------|----|-----------|
| orders | `id_pedido_tienda` | Idempotencia + historial |
| contacts | `id_tienda` | Caché contactos Holded |
| accounts | `num` | Caché plan de cuentas |
| products | `product_reference` (SKU) | Mapeo SKU → cuenta contable |
| categories | `category_id` | Mapeo categoría → cuenta |

## Deuda técnica identificada

- `strict: false` en tsconfig — migración incremental fichero a fichero
- Sin PITR en DynamoDB — riesgo de pérdida total si se borra tabla
- Sin tests de integración real — todos son unitarios con mocks
- `holded.service.ts` sin suite de tests propia
- Sin webhooks de PrestaShop — sync en diferido (cron 09:00), no tiempo real
