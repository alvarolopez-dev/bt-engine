---
tags: [orchestrator, plan, template]
created: 2026-05-25
extraído-de: agents/01_agent_orchestrator.md §5 + §9
---

# Plan Template — project_state.json + plan.json

#orchestrator #plan #template

[[index]] [[01_agent_orchestrator]]

Schemas completos para el Orquestador.
Extraído de `agents/01_agent_orchestrator.md §5 + §9` para reducir peso del agente.

---

## project_state.json — LA MEMORIA DEL PIPELINE

Mantener este fichero actualizado tras cada agente.
Es el estado compartido entre sesiones. Añadir a `.gitignore`.

```json
{
  "project_name": "",
  "platform_a": {
    "name": "",
    "version": "",
    "api_profile_ready": false
  },
  "platform_b": {
    "name": "",
    "version": "",
    "api_profile_ready": false
  },
  "integration_direction": "a_to_b | b_to_a | bidirectional",
  "data_being_synced": [],
  "lambdas": [
    {
      "name": "",
      "trigger": "",
      "purpose": ""
    }
  ],
  "typescript_strict_status": {
    "project_has_strict": true,
    "files_migrated": [],
    "files_pending_migration": []
  },
  "pipeline_status": {
    "intake":          "pending | done",
    "research":        "pending | done",
    "finops":          "pending | approved | blocked",
    "development":     "pending | in_progress | done",
    "qa":              "pending | pass | fail",
    "deploy_decision": "pending | approved | deferred",
    "deployment":      "pending | done | failed"
  },
  "deploy_criteria_met": false,
  "current_blocker": null,
  "last_agent": null,
  "iteration_count": 0,
  "total_estimated_cost_eur": 0,
  "scribe_log_path": "dev-log/"
}
```

---

## plan.json — EL CONTRATO DE TRABAJO DEL DEVELOPER

Generado por el Orquestador cuando Intake entrega `intake_briefing.json`
con `ready_for_pipeline: true`.

El plan es tan preciso que un Developer que nunca ha visto el proyecto
sabe exactamente qué construir sin hacer una sola pregunta.

### Estructura obligatoria

```json
{
  "project_name": "",
  "plan_version": "1.0",
  "plan_date": "",
  "confidence": "high | medium | low",

  "architecture": {
    "pattern": "event-driven | polling | hybrid",
    "reason": "por qué — referencia al API_PROFILE de la plataforma",
    "lambdas": [
      {
        "name": "",
        "trigger": "",
        "trigger_reason": "",
        "purpose": "",
        "estimated_duration_ms": 0,
        "memory_mb": 128,
        "runtime": "nodejs22.x",
        "runtime_note": ""
      }
    ],
    "database": "DynamoDB PAY_PER_REQUEST | ninguna",
    "database_reason": ""
  },

  "integrations": {
    "platform_a": {
      "name": "",
      "api_version": "",
      "auth_method": "",
      "webhook_or_polling": "",
      "api_profile_status": "vault | research_needed"
    },
    "platform_b": {
      "name": "",
      "api_version": "",
      "auth_method": "",
      "api_profile_status": "vault | research_needed"
    }
  },

  "data_mapping": [
    {
      "from_field": "",
      "to_field": "",
      "transform": "ninguna | descripción exacta",
      "confirmed_by": "intake | assumed"
    }
  ],

  "unknowns": [
    {
      "field": "",
      "impact": "bloqueante | no bloqueante",
      "assigned_to": "research | client | devops",
      "resolves_before": "development | deployment"
    }
  ],

  "security": {
    "webhook_validation_required": true,
    "pii_fields": [],
    "gdpr_applies": true,
    "region": "eu-west-1"
  },

  "estimated_cost": {
    "status": "pending_finops",
    "historical_reference": "$0.82/mes — 50tx/día"
  },

  "ready_to_proceed": true,
  "blocking_unknowns": []
}
```

### Reglas absolutas del plan

**R1 — `confirmed_by: "assumed"` en data_mapping → unknown automático.**
Si cualquier campo de mapeo no fue confirmado explícitamente por el cliente
en el Intake → marcarlo como `confirmed_by: "assumed"` → generar unknown automático
asignado a Research. El Developer no implementa mapeos asumidos.

**R2 — `blocking_unknowns` con items → `ready_to_proceed: false`.**
Si el plan tiene unknowns bloqueantes sin resolver:
- `ready_to_proceed: false`
- Orquestador vuelve al Intake o escala al cliente
- Research y FinOps no se activan hasta que se resuelvan
- Sin excepción: un plan con blocking unknowns no genera código

**R3 — `api_profile_status: "vault"` → Research no se activa para esa plataforma.**
Si el API_PROFILE ya existe en la vault, Research usa el existente.
Solo se activa Research para plataformas con `api_profile_status: "research_needed"`.

**R4 — El plan va al Developer como input principal.**
El Developer recibe: `plan.json` + `API_PROFILE` de cada plataforma.
El Developer no necesita más contexto. El plan debe bastar.

---

## Estructura de directorio esperada por proyecto

Todo proyecto nuevo sigue esta estructura.

```
proyecto-integracion/
├── project_state.json               ← gitignored
├── intake_briefing.json             ← gitignored
├── dev-log/
│   ├── projects/{nombre}/
│   └── knowledge_base/
├── .env.example
├── .gitignore
├── package.json
├── tsconfig.json
├── src/
│   ├── handlers/
│   ├── services/
│   ├── schemas/
│   ├── utils/
│   └── types/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── infrastructure/
└── scripts/
```

---

*Extraído de agents/01_agent_orchestrator.md §5 + §9 + §13 — 2026-05-25*
*Ver agente reducido en [[01_agent_orchestrator]] tras refactorización COMMIT 4*
