---
name: security-audit
description: "Ejecuta auditoría de seguridad completa. DISPARAR cuando: usuario pida revisar seguridad, GDPR, OWASP, vulnerabilidades, diga audita esto, revisa seguridad, hay datos sensibles aquí, antes de deploy, voy a desplegar; también activar PROACTIVAMENTE antes de cualquier paso DevOps aunque el usuario no lo pida — si ve deploy_decision aprobada sin security_report, arrancar."
user-invocable: true
---

# Security Audit — Auditoría bt-engine

Cargar `agents/10_agent_security.md`.
Para checklists OWASP detallados → `references/owasp-2025.md`.

## 7 Capas de auditoría

| Capa | Qué verificar |
|------|--------------|
| 1. Webhooks | R-SEC-1 a R-SEC-5: firma, raw body, timingSafeEqual, 401, no log |
| 2. Secrets | R-SEC-7: .env no en repo, SSM en prod, no hardcoded |
| 3. PII/Logs | R-SEC-6: emails, nombres, CIFs, IBANs fuera de CloudWatch |
| 4. Auth Lambda | R-SEC-8: AuthType NONE → handler valida token antes de procesar |
| 5. OWASP Top10 | A01-A10 — ver references/owasp-2025.md |
| 6. LLM Top10 | LLM01-LLM10 — si hay componentes IA en el proyecto |
| 7. Agentic | ASI01-ASI10 — si hay orquestación multi-agente |

## Formato de findings

```
[SEVERIDAD] fichero:línea — descripción breve
```

Ejemplo:
```
[CRÍTICO] src/handlers/webhook.ts:47 — raw body no preservado antes de JSON.parse
[ALTO]    src/utils/auth.ts:23 — === en comparación de tokens, timing attack
[MEDIO]   src/handlers/orders.ts:89 — email del cliente en log de pino
```

| Nivel | Acción |
|-------|--------|
| CRÍTICO | Parar, reportar inmediatamente al usuario |
| ALTO | Completar auditoría, reportar en bloque al final |
| MEDIO/BAJO | Incluir en reporte final |

## Output

Tabla TOON de findings:
```
[N]{severidad,fichero:línea,descripción,fix}:
CRÍTICO,src/handlers/webhook.ts:47,raw body no preservado,preservar Buffer antes de JSON.parse
```

`security_report.json`:
```json
{
  "ready_for_devops": false,
  "findings_count": { "critical": 0, "high": 0, "medium": 0, "low": 0 },
  "findings": [],
  "audited_at": "ISO8601"
}
```

`ready_for_devops: true` solo si cero findings CRÍTICO y cero ALTO.
