---
name: cost-check
description: "Estimación rápida de coste AWS sin pipeline completo. Úsalo cuando el usuario pregunte cuánto costaría una arquitectura, quiera comparar opciones de coste, pida una estimación antes de empezar desarrollo, o diga cuánto cuesta, precio estimado, coste AWS, o similar."
user-invocable: true
args: "$ARGUMENTS = descripción de la arquitectura"
---

# Cost Check — Estimación Rápida AWS

Actívate con `/cost-check [arquitectura]`, "cuánto cuesta", "precio estimado", "coste AWS", "comparar opciones", o cuando el usuario pregunte por costes antes de empezar.

## PASO 1 — Referencia base en vault

```
search_notes "cost_history"
```

Referencia base confirmada en producción:
**$0.82/mes para 50 pedidos/día** (prestashop-holded middleware)
Ver `dev-log/knowledge-base/costs/prestashop-holded-prod.md` para desglose completo.

## PASO 2 — Cargar FinOps

Cargar `agents/04_agent_finops.md`.

Si faltan datos para calcular → preguntar antes de estimar. Los datos mínimos requeridos:
- Volumen de eventos/pedidos por día
- Número de integraciones (fuentes × destinos)
- Frecuencia de polling si aplica
- Región de deploy

**Nunca asumir volumen. Siempre preguntar.**

## PASO 3 — Output en formato TOON

```
[N]{servicio|coste_usd|unidad|notas}:
Lambda,0.003,/mes,cubierto free tier hasta 1M req
SQS,0.001,/mes,<1M requests/mes
Secrets,0.80,/mes,2 secretos × $0.40
CloudWatch,0.02,/mes,~50MB logs
```

Luego:
```
Total estimado: $X.XX/mes (~€X.XX al cambio actual)
Free tier cubre: sí hasta mes N / no (explicar por qué)
```

Si hay señales de alerta (coste inesperadamente alto, volumen que sale del free tier, picos no contemplados):
```
⚠️ Alertas:
- [descripción de la señal]
```

## Precios de referencia (mayo 2026)

| Servicio | Precio |
|----------|--------|
| Lambda | $0.20 / 1M requests + $0.0000166667 / GB-segundo |
| DynamoDB PAY_PER_REQUEST | $1.25 / 1M writes, $0.25 / 1M reads |
| Secrets Manager | $0.40 / secreto / mes |
| SQS Standard | $0.40 / 1M requests |
| CloudWatch Logs | $0.50 / GB ingestado |
| Lambda Function URL | Sin coste adicional (solo Lambda) |

Free tier Lambda: 1M requests/mes + 400K GB-segundos/mes (permanente).
