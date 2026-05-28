---
name: new-integration
description: "Arranca el pipeline completo de Bigtoone para una integración nueva. DISPARAR cuando: usuario diga nuevo proyecto, nueva integración, conectar X con Y, sincronizar X con Y, webhook entre plataformas, automatizar flujo entre sistemas; si menciona dos SaaS + verbo de acción (sync, conectar, enviar, recibir, migrar). No esperar que el usuario pida el pipeline explícitamente — si describe integración, arrancar."
user-invocable: true
---

# New Integration — Pipeline Completo bt-engine

Scribe (`agents/08_agent_scribe.md`) activo en **todos** los pasos. Documenta en paralelo.

## Status TOON (reportar en cada gate)

```
[6]{gate,agente,fichero,estado}:
GATE-0,Intake,intake_briefing.json,pending
GATE-1,Research,api_profile.json,pending
GATE-2,FinOps,finops_report.json,pending
GATE-3,Security,security_report.json,pending
GATE-4,QA,qa_report.json,pending
GATE-5,Orchestrator,deploy_decision,pending
```

## PASO 1 — Vault primero

```
search_notes("[plataforma_a] [plataforma_b]")
```

Reportar:
- `api_profile_status: vault` → perfil completo existe
- `api_profile_status: partial` → existe pero incompleto
- `api_profile_status: research_needed` → no existe

## PASO 2 — Intake

Cargar `agents/02_agent_intake.md`.
Gate bloqueante: `intake_briefing.json` con `confidence_level >= medium`.
No avanzar hasta briefing confirmado por usuario.

## PASO 3 — Research ∥ FinOps (paralelo cuando sea posible)

**Research** (solo si `research_needed` o `partial`):
Cargar `agents/03_agent_research.md`.
Si vault tiene perfil completo → saltar.

**FinOps** (siempre, en paralelo con Research):
Cargar `agents/04_agent_finops.md`.
Gate bloqueante: `finops_report.json` con `status: approved`.

## PASO 4 — Developer

Activar solo con los tres confirmados:
- `api_profile.json` completo (vault o Research)
- `finops_report.json` status: approved
- `intake_briefing.json` confidence_level >= medium

Cargar `agents/05_agent_developer.md`.

## PASO 5 — QA

Cargar `agents/06_agent_qa.md`.
Bucle hasta `qa_report.json` status: pass.
Máximo 3 iteraciones → escalar al usuario si no pasa.

## PASO 6 — Security (paralelo a QA)

Cargar `agents/10_agent_security.md` o invocar `/security-audit`.
Gate bloqueante: `security_report.json` con `ready_for_devops: true`.

## PASO 7 — Decisión deploy

Presentar criterios al usuario:
- Tests cubren happy path + gotchas críticos de plataformas
- FinOps aprobado con margen conocido
- Caso de uso end-to-end validado

**Esperar confirmación explícita. Nunca asumir deploy autorizado.**

## PASO 8 — DevOps

Solo con decisión aprobada explícitamente.
Cargar `agents/07_agent_devops.md`.

## Gates (no saltar)

| Gate | Fichero | Bloqueante si |
|------|---------|---------------|
| GATE-0 | intake_briefing.json | confidence < medium |
| GATE-1 | api_profile.json | incompleto |
| GATE-2 | finops_report.json | status != approved |
| GATE-3 | security_report.json | ready_for_devops != true |
| GATE-4 | qa_report.json | status != pass |
| GATE-5 | deploy_decision | no explícita del usuario |

Gate fallido → reportar y esperar. No improvisar. No asumir.
