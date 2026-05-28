---
name: cost-check
description: "Estimación rápida de coste AWS. DISPARAR cuando: usuario pregunte cuánto cuesta, precio estimado, coste AWS, comparar opciones; también antes de arrancar cualquier proyecto nuevo si el usuario no ha pedido FinOps — si hay intake_briefing.json sin finops_report.json, ofrecer proactivamente. Nunca estimar sin datos de volumen — preguntar primero."
user-invocable: true
args: "$ARGUMENTS = descripción de la arquitectura"
---

# Cost Check — Estimación Rápida AWS

## PASO 1 — Referencia base en vault

```
search_notes("cost_history prestashop holded")
```

Base confirmada en producción: **$0.82/mes para 50 pedidos/día**
Ver `dev-log/knowledge-base/costs/prestashop-holded-prod.md`.

## PASO 2 — Datos mínimos antes de calcular

Si faltan → preguntar antes de estimar. Nunca asumir volumen.

- Eventos/pedidos por día
- Número de integraciones (fuentes × destinos)
- Polling o webhook-driven
- Región de deploy (default: eu-west-2)
- Picos previsibles (campañas, estacionalidad)

## PASO 3 — Cargar FinOps

Cargar `agents/04_agent_finops.md` para análisis completo.

## PASO 4 — Output TOON

```
[N]{servicio,coste_usd,unidad,tier,notas}:
Lambda,0.003,/mes,free-tier,<1M invocations
DynamoDB,0.012,/mes,pay-per-request,~10k writes
SQS,0.001,/mes,free-tier,<1M requests
SecretsManager,0.80,/mes,fixed,2 secretos × $0.40
CloudWatch,0.02,/mes,standard,~50MB logs
```

Luego siempre incluir:
```
Total: $X.XX/mes (~€X.XX)
Free tier: cubre hasta mes N / no cubre porque [razón]
```

Alertas si detecta señal de coste inesperado:
```
⚠️ [descripción: volumen sale de free tier en mes N, pico estacional no contemplado, etc.]
```

## Precios referencia (mayo 2026)

| Servicio | Precio |
|----------|--------|
| Lambda | $0.20/1M req + $0.0000166667/GB-s |
| DynamoDB | $1.25/1M writes · $0.25/1M reads |
| Secrets Manager | $0.40/secreto/mes |
| SQS Standard | $0.40/1M requests |
| CloudWatch Logs | $0.50/GB ingestado |
| Lambda Function URL | Sin coste adicional |

Free tier Lambda (permanente): 1M req/mes + 400K GB-s/mes.
