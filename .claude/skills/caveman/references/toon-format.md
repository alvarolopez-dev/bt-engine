# TOON — Token-Oriented Object Notation

Formato comprimido para arrays de objetos uniformes.
Sin binario externo — solo convención de escritura.

## Sintaxis

`[N]{campo1,campo2,...}:` + una fila CSV por objeto.

Comparativa:
- JSON estándar: 120 tokens
- TOON: 70 tokens — 42% ahorro

## Regla crítica

TOON solo Claude→Claude o reportes internos.
**Nunca** para payloads a APIs externas (Revo, Holded, Zoho, Stripe).

---

## intake_briefing.json (resumen)

```
[1]{plataformas,objetivo,webhook_trigger,destino_action,client_token,confidence}:
PrestaShop+Holded,sync-pedidos,order.status_update,holded.createSalesOrder,revo_abc123,high
```

Campos bloqueantes (blocked_on siempre incluir):
```
[1]{campo,valor}:
confidence_level,high
client_token,revo_abc123
blocked_on,null
```

## api_profile.json (Research output)

```
[2]{plataforma,auth,base_url,rate_limit,webhook_support,gotchas_clave}:
PrestaShop,X-API-KEY header,/api/,N/A,order_add+order_update,"[E3] rows 3 formatos"
Holded,Bearer token,api.holded.com/api/bling/,100req/min,no-outbound,"[E1] object-names"
```

## finops_report.json (FinOps output)

```
[5]{servicio,coste_usd,unidad,tier,notas}:
Lambda,0.003,/mes,free-tier,<1M invocations
DynamoDB,0.012,/mes,pay-per-request,~10k writes
SQS,0.001,/mes,free-tier,<1M requests
SecretsManager,0.80,/mes,fixed,2 secretos × $0.40
CloudWatch,0.02,/mes,standard,~50MB logs
```

Decisión final:
```
[1]{status,total_usd_mes,umbral_usd,decision}:
approved,0.836,5.00,bajo umbral — proceder a Developer
```

---

## Pipeline status

```
[5]{agente,estado,gate}:
Intake,done,GATE-0
Research,done,GATE-1
FinOps,approved,GATE-2
Security,pending,GATE-3
QA,pending,GATE-4
```

## QA results

```
[4]{test,resultado,fichero,ms}:
handler-loads-secrets,pass,intake.test.ts,12
guard-returns-400-no-token,pass,intake.test.ts,8
idempotency-duplicate-event,pass,intake.test.ts,15
holded-createSalesOrder-mock,pass,developer.test.ts,23
```

## Skills disponibles

```
[7]{skill,lines,references,trigger}:
caveman,70,toon-format.md,/caveman o contexto>70%
new-integration,80,—,nuevo proyecto entre plataformas
diagnose,60,—,bug o error inesperado
research,70,—,plataforma no documentada
security-audit,90,owasp-2025.md,antes de deploy
cost-check,55,—,estimación coste AWS
typescript-strict,75,—,código TypeScript Lambda
```
