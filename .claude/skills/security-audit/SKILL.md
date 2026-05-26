---
name: security-audit
description: "Ejecuta auditoría de seguridad completa sobre el proyecto actual. Úsalo antes de cualquier despliegue, cuando llegue un proyecto con datos sensibles, o cuando el usuario pida revisar seguridad, GDPR, OWASP, vulnerabilidades, o diga audita esto, revisa seguridad, o hay datos sensibles aquí."
user-invocable: true
---

# Security Audit — Auditoría bt-engine

Actívate con `/security-audit`, "revisa seguridad", "audita esto", "OWASP", "GDPR", "vulnerabilidades", o antes de cualquier despliegue.

Cargar `agents/10_agent_security.md` y ejecutar checklist completo de 7 capas.
Para checklists OWASP detallados → leer `references/owasp-2025.md`.

## FORMATO DE FINDINGS

Para cada finding usar:

```
[SEVERIDAD] fichero:línea — descripción breve
```

Ejemplo:
```
[CRÍTICO] src/handlers/webhook.ts:47 — raw body no preservado antes de JSON.parse
[ALTO]    src/utils/auth.ts:23 — === en comparación de tokens, vulnerable a timing attack
[MEDIO]   src/handlers/orders.ts:89 — email del cliente en log de pino
```

### Severidades

| Nivel | Acción |
|-------|--------|
| CRÍTICO | Parar auditoría, reportar inmediatamente al usuario |
| ALTO | Completar auditoría, reportar en bloque al final |
| MEDIO | Incluir en reporte final |
| BAJO | Incluir en reporte final |
| INFO | Incluir si es relevante para el contexto |

## CONSTRAINTS DE SEGURIDAD bt-engine

Verificar específicamente (extraídos de `00_CONSTRAINTS.md`):

- **R-SEC-1** Webhooks con validación de firma antes de procesar
- **R-SEC-2** Raw body preservado ANTES de JSON.parse para HMAC
- **R-SEC-3** `crypto.timingSafeEqual` para comparar tokens/firmas (nunca `===`)
- **R-SEC-4** Responder 401 (no 403) en firma inválida
- **R-SEC-5** No loguear payload si la firma falla
- **R-SEC-6** PII nunca en CloudWatch logs (emails, nombres, CIFs, IBANs)
- **R-SEC-7** `.env` nunca en repositorio
- **R-SEC-8** Lambda Function URL con `AuthType: NONE` — verificar que handler valida token

## OUTPUT

1. Tabla TOON de findings:
```
[N]{severidad|fichero:línea|descripción|fix}
```

2. Generar `security_report.json` con:
```json
{
  "ready_for_devops": false,
  "findings_count": { "critical": 0, "high": 0, "medium": 0, "low": 0 },
  "findings": [],
  "audited_at": "ISO8601"
}
```

`ready_for_devops: true` solo si no hay findings CRÍTICO ni ALTO.
