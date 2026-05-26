# TOON — Token-Oriented Object Notation

Formato comprimido para arrays de objetos uniformes.
Sin binario externo — solo convención de escritura.

## Comparativa

JSON estándar (120 tokens):
```json
[{"id":1,"name":"Alice","role":"admin"},
 {"id":2,"name":"Bob","role":"user"}]
```

TOON (70 tokens — 42% ahorro):
```
[2]{id,name,role}:
1,Alice,admin
2,Bob,user
```

Sintaxis: `[N]{campo1,campo2,...}:` seguido de una fila CSV por objeto.

## Usar TOON en reportes de

- Estados de pipeline → `agente|estado|líneas`
- API_PROFILEs resumidos → `plataforma|auth|rate_limit|webhook`
- Resultados de QA → `test|resultado|fichero`
- Estimaciones FinOps → `servicio|coste|unidad`
- Skills disponibles → `skill|líneas|references|test_ok`

## Ejemplos bt-engine

Pipeline status:
```
[5]{agente|estado|gate}:
Intake,done,GATE-0
Research,done,GATE-1
FinOps,approved,GATE-2
Security,pending,GATE-3
QA,pending,GATE-4
```

FinOps report:
```
[4]{servicio|coste_usd|unidad|notas}:
Lambda,0.003,/mes,cubierto free tier
SQS,0.001,/mes,<1M requests
Secrets,0.80,/mes,2 secretos
CloudWatch,0.02,/mes,~50MB logs
```

## Regla importante

TOON solo para comunicación Claude→Claude o reportes internos.
**Nunca** para payloads a APIs externas (Revo, Holded, Zoho, Stripe, etc.).
