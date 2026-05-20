---
tags: [coste, aws, produccion, lambda]
created: 2026-05-20
project: prestashop-holded-middleware-prod
fuente: PROJECT_DNA.md §4, PROJECT_DNA_COMPLEMENT.md CLAUDE.md §Coste
---

# Coste real — prestashop-holded-middleware-prod

#coste #produccion

Referencia histórica de coste real para integraciones PrestaShop → Holded.
Proyecto: [[prestashop-holded-middleware-prod]]
Operativo desde: 2026-05-15

## Arquitectura que produce este coste

| Lambda | Memoria | Timeout | Trigger | Invocaciones/mes |
|--------|---------|---------|---------|-----------------|
| fetchOrdersPrestashop | 1024 MB | 60s | Step Functions (cron diario) | ~30 |
| processOrdersS3 | 1024 MB | 600s | Step Functions | ~30 (si hay pedidos) |
| stuckOrdersChecker | 1024 MB | 60s | EventBridge cron 08:30 UTC | ~30 |
| panelRouter | 1024 MB | 600s | CloudFront → Function URL | variable (uso manual) |

> ⚠️ **Nota para FinOps**: Este proyecto usa **1024 MB** por defecto en todas las Lambdas, no 128 MB. El supuesto de 128 MB en el agente FinOps es correcto como punto de partida conservador, pero debe verificarse con los datos reales de CloudWatch post-despliegue.

## Servicios en uso

- Lambda (4 funciones)
- Step Functions Express (1 máquina de estado, 1 ejecución/día)
- EventBridge (2 reglas cron)
- DynamoDB PAY_PER_REQUEST (5 tablas)
- S3 (1 bucket, objetos con lifecycle 30 días)
- SNS (1 topic de alertas)
- Secrets Manager (1 secreto, si configurado)
- CloudFront (si `ENABLE_PANEL=true`)

## Desglose de costes — volumen ~30 pedidos/día

### Lambda
- Invocaciones totales: ~120/mes (4 Lambdas × ~30)
- GB-segundos: ~120 × 0.8s × 1 GB = ~96 GB-s/mes
- **Free tier: 1M invocaciones + 400.000 GB-s/mes**
- Coste Lambda: **$0.00** (cubierto por free tier con amplio margen)

> Incluso con 1024 MB, el volumen de ~30 pedidos/día deja la Lambda muy dentro del free tier. La memoria no importa al coste a este volumen.

### Step Functions Express
- Ejecuciones: ~30/mes (1/día)
- Transiciones: ~5 por ejecución = ~150 transiciones/mes
- Free tier Express: 1M ejecuciones/mes (no aplica por transiciones)
- Precio: $0.00001/transición → ~$0.0015/mes
- Coste Step Functions: **~$0.00** (negligible)

### DynamoDB
- Volumen: ~30 pedidos/día × operaciones CRUD = ~2.000 operaciones/mes
- Free tier: 25 WCU + 25 RCU permanentes (no solo primeros 12 meses)
- PAY_PER_REQUEST + volumen bajo = dentro de free tier
- Coste DynamoDB: **$0.00**

### S3
- Almacenamiento: < 1 MB/mes (lifecycle 30 días, ~30 ficheros JSON pequeños)
- Requests: ~60/mes (30 PUT + 30 GET)
- Coste S3: **~$0.001/mes** (negligible)

### Secrets Manager
- 1 secreto × $0.40/secreto/mes = $0.40/mes
- Llamadas GetSecretValue: ~120/mes × $0.05/10.000 = $0.0006/mes
- Coste Secrets Manager: **~$0.40/mes** ← **coste dominante**

> ⚠️ **Discrepancia documentada**: CLAUDE.md del proyecto indica "< €0.10/mes, ~€0.04 Secrets Manager". PROJECT_DNA.md indica ~$0.82/mes (2 secretos). La diferencia: (1) CLAUDE.md puede reflejar configuración sin Secrets Manager (usando .env), donde el coste real es ~$0. (2) Si se usa 1 secreto en lugar de 2, el coste es $0.40/mes. Usar datos de CloudWatch post-despliegue para confirmar configuración real del cliente.

### CloudWatch Logs
- ~10-50 MB/mes de logs
- $0.50/GB ingestado → ~$0.005/mes
- Coste CloudWatch: **~$0.005/mes**

### CloudFront (solo si ENABLE_PANEL=true)
- 1 TB/mes gratis → dentro de free tier para uso de panel admin
- Coste CloudFront: **$0.00** (uso típico de panel admin)

## Total estimado por configuración

| Configuración | Coste/mes |
|---------------|-----------|
| Sin Secrets Manager (usando .env) | ~$0.006 |
| Con 1 secreto en Secrets Manager | ~$0.406 |
| Con 2 secretos en Secrets Manager | ~$0.806 |
| Con ENABLE_PANEL=true (+ CloudFront) | +$0.00 |

**Rango real: $0.01 – $0.82/mes** dependiendo de la configuración de secrets.

## Lección para proyectos futuros

> El coste dominante en integraciones Bigtoone de bajo volumen es **Secrets Manager**, no Lambda. Lambda queda en free tier con facilidad incluso con 1024 MB a ~30 invocaciones/día. Calcular siempre el coste de secretos por separado y confirmar cuántos secretos se van a usar.

## Referencia para FinOps

Cuando el agente FinOps reciba una integración PrestaShop → Holded similar, usar este histórico como punto de partida:
- Volumen ~30-50 pedidos/día → coste Lambda: $0 (free tier)
- Coste real dominante: Secrets Manager ($0.40-0.80/mes)
- Total típico: **$0.40-0.82/mes**

Ver también: [[prestashop]], [[holded]]
