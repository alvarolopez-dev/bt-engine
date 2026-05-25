---
tags: [devops, checklist, deploy]
created: 2026-05-25
extraído-de: agents/07_agent_devops.md §5
---

# DevOps Checklist — Verificación por componente

#devops #checklist #deploy

[[index]] [[07_agent_devops]]

Comandos de verificación post-deploy por componente.
Extraído de `agents/07_agent_devops.md §5` para reducir peso del agente.

---

## Lambda — cold start sin errores

```bash
# Invocar directamente para forzar cold start y verificar logs
aws lambda invoke \
  --function-name prestashop-holded-middleware-prod-fetchOrdersPrestashop \
  --payload '{}' \
  --region eu-west-2 \
  /tmp/response.json

# Verificar logs del cold start (últimos 5 minutos)
aws logs filter-log-events \
  --log-group-name /aws/lambda/prestashop-holded-middleware-prod-fetchOrdersPrestashop \
  --start-time $(date -d '5 minutes ago' +%s000) \
  --filter-pattern "ERROR" \
  --region eu-west-2
# Resultado esperado: vacío (sin errores en cold start)
```

---

## EventBridge — reglas activas

```bash
aws events list-rules \
  --name-prefix prestashop-holded-middleware-prod \
  --region eu-west-2 \
  --query 'Rules[*].{Name:Name,State:State,Schedule:ScheduleExpression}'
# Resultado esperado:
# - fetchOrders: State=ENABLED, Schedule=cron(0 7 * * ? *)
# - stuckChecker: State=ENABLED, Schedule=cron(30 8 * * ? *)
```

---

## DynamoDB — tablas activas con billing correcto

```bash
for table in orders contacts accounts products categories; do
  aws dynamodb describe-table \
    --table-name prestashop-holded-middleware-prod-${table} \
    --region eu-west-2 \
    --query 'Table.{Status:TableStatus,Billing:BillingModeSummary.BillingMode}'
done
# Resultado esperado por tabla:
# Status: ACTIVE
# Billing: PAY_PER_REQUEST (nunca PROVISIONED)
```

---

## CloudFront — solo si ENABLE_PANEL=true

```bash
# Obtener ID de distribución
DIST_ID=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='prestashop-holded-middleware-prod-panel'].Id" \
  --output text)

# Verificar que propagación completó
aws cloudfront get-distribution \
  --id $DIST_ID \
  --query 'Distribution.{Status:Status,Domain:DomainName}'
# Resultado esperado: Status=Deployed (no InProgress)
# Tiempo: hasta 15 minutos — esperar activamente, no asumir
```

**Verificar acceso a través de CloudFront (no directamente a Lambda URL):**

```bash
curl -s -o /dev/null -w "%{http_code}" \
  https://${CLOUDFRONT_DOMAIN}/health
# Resultado esperado: 200 (o 401 si hay validación de token — no 403, no 502)
```

> ⚠️ Block Public Access activo a nivel de cuenta — Lambda URLs no son accesibles directamente.
> Verificar SIEMPRE a través de CloudFront.

---

## Step Functions — definición activa

```bash
aws stepfunctions list-state-machines \
  --region eu-west-2 \
  --query "stateMachines[?contains(name,'prestashop-holded-middleware-prod')]"
# Resultado esperado: al menos una state machine listada
```

---

## Cuándo hacer rollback

```bash
# Rollback al despliegue anterior (Serverless v3 mantiene historial en S3)
serverless rollback --stage prod --region eu-west-2
```

**Sí hacer rollback:**
- Lambda devuelve error sistemático en cold start
- DynamoDB tabla no creada o con billing incorrecto
- CloudFront en estado de error (no solo lento en propagar)
- EventBridge reglas en estado DISABLED tras el deploy

**NO hacer rollback:**
- CloudFront en "InProgress" — es normal, esperar los 15 minutos
- Lambda warm start más lento de lo esperado — no es un error de deploy
- Advertencia de Serverless sobre v4 disponible — ignorar siempre

---

*Extraído de agents/07_agent_devops.md §5 + §6 — 2026-05-25*
*Ver agente reducido en [[07_agent_devops]] tras refactorización COMMIT 4*
