---
tags: [mapa, pipeline, estructura, agentes]
created: 2026-05-25
applies-to: todos los agentes del ecosistema
---

# 00 — MAPA DEL ECOSISTEMA BIGTOONE

> Leer este fichero para orientarse en el proyecto.
> Siempre leer `[[00_CONSTRAINTS]]` antes de cualquier tarea.

---

## Pipeline de activación

```
USUARIO
  ↓
02 INTAKE → intake_briefing.json  (confidence_level >= medium requerido)
  ↓
01 ORQUESTADOR — genera plan.json
  ↓                    ↓                    ↓
03 RESEARCH    04 FINOPS          10 SECURITY
API_PROFILE    finops_report      security_report
  ↓                    ↓                    ↓
  └────────────────────┴────────────────────┘
                       ↓  (los 3 gates deben pasar)
               05 DEVELOPER → developer_report.json
                       ↓
               06 QA → qa_report.json
                       ↓
               01 ORQUESTADOR — decisión deploy explícita
                       ↓
               07 DEVOPS → devops_report.json

08 SCRIBE — activo en paralelo durante todo el pipeline → dev-log/
```

### Gates bloqueantes (orden estricto)

| Gate | Fichero | Agente responsable |
|------|---------|-------------------|
| GATE 0 | `intake_briefing.json` (confidence >= medium) | Intake |
| GATE 1 | `api_profile.json` completo | Research |
| GATE 2 | `finops_report.json` (status: approved) | FinOps |
| GATE 3 | `security_report.json` (ready_for_devops: true) | Security |
| GATE 4 | `qa_report.json` (status: pass) | QA |
| GATE 5 | `deploy_decision` explícita | Orquestador |

---

## Agentes — ubicación y responsabilidad

| Fichero | Agente | Líneas | Rol |
|---------|--------|--------|-----|
| `agents/00_CONSTRAINTS.md` | — | ref | Constraints universales (leer siempre primero) |
| `agents/00_TREE.md` | — | ref | Este fichero — mapa del ecosistema |
| `agents/01_agent_orchestrator.md` | Orquestador | ~574 | Coordinación + decisión deploy |
| `agents/02_agent_intake.md` | Intake | ~476 | Briefing inicial + validación petición |
| `agents/03_agent_research.md` | Research | ~574 | API_PROFILE + investigación plataformas |
| `agents/04_agent_finops.md` | FinOps | ~429 | Análisis de costes AWS |
| `agents/05_agent_developer.md` | Developer | ~797 | Implementación TypeScript |
| `agents/06_agent_qa.md` | QA | ~575 | Tests + validación calidad |
| `agents/07_agent_devops.md` | DevOps | ~464 | Deploy Serverless Framework |
| `agents/08_agent_scribe.md` | Scribe | ~649 | Documentación → vault |
| `agents/09_HOW_TO_USE.md` | — | ref | Guía de uso del ecosistema |
| `agents/10_agent_security.md` | Security | ~425 | Auditoría de seguridad |

---

## Vault — estructura de conocimiento

```
dev-log/
├── index.md                    ← índice maestro (30 nodos documentados)
├── knowledge-base/
│   ├── aws/
│   │   ├── lambda-patterns.md         (P1-P14 validados en producción)
│   │   ├── dynamodb-patterns.md
│   │   ├── serverless-framework-v3.md
│   │   ├── step-functions-express.md
│   │   └── architecture-decision-tree.md
│   ├── platforms/
│   │   ├── prestashop.md              (8 gotchas confirmados)
│   │   ├── holded.md                  (6 gotchas + breaking change v2)
│   │   ├── revo-xef.md
│   │   ├── revo-retail.md
│   │   ├── revo-flow.md
│   │   ├── revo-solo.md
│   │   ├── stripe.md
│   │   ├── woocommerce.md
│   │   ├── shopify.md
│   │   ├── zoho-crm.md
│   │   └── business-central.md
│   ├── patterns/
│   │   ├── handler-structure.md
│   │   ├── idempotencia-dynamodb.md
│   │   ├── degradacion-silenciosa.md
│   │   └── patron-3-tiers.md
│   ├── errors/
│   │   ├── e1-object-object-nombres.md
│   │   ├── e2-race-condition-facturas-duplicadas.md
│   │   ├── e3-order-rows-tres-formatos.md
│   │   ├── e4-caracteres-invisibles.md
│   │   ├── e5-campo-estado-renombrado.md
│   │   ├── e6-panel-router-sin-url.md
│   │   └── holded-auth-change-bearer.md
│   ├── security/
│   │   ├── checklist-pre-deploy.md
│   │   ├── webhook-validation.md
│   │   └── gdpr-bigtoone.md
│   ├── costs/
│   │   └── prestashop-holded-prod.md
│   └── agent-details/              ← propuesto en optimization-report
│       ├── scribe-templates.md     (extraer de Scribe §3 — pendiente)
│       ├── qa-test-cases.md        (extraer de QA §3-6 — pendiente)
│       ├── api-profile-template.md (extraer de Research §5 — pendiente)
│       ├── plan-template.md        (extraer de Orchestrator §5+§9 — pendiente)
│       ├── developer-style.md      (extraer de Developer §10 — pendiente)
│       └── devops-checklist.md     (extraer de DevOps §5 — pendiente)
└── projects/
    └── prestashop-holded-middleware-prod.md
```

---

## Stack fijo (resumen rápido)

```
Compute:    AWS Lambda (nodejs20.x)
IaC:        Serverless Framework v3.38.0
DB:         DynamoDB PAY_PER_REQUEST
Región:     eu-west-2 (producción actual)
Lenguaje:   TypeScript strict: true
Secrets:    AWS Secrets Manager (prod) / .env (local)
Logs:       pino + pino-lambda
Trigger:    Lambda Function URL (AuthType: NONE — ADR-3)
```

> Ver `[[00_CONSTRAINTS]]` para reglas completas, constraints críticos y reglas de pipeline.

---

*Última actualización: 2026-05-25*
