---
name: new-integration
description: "Arranca el pipeline completo de Bigtoone para una integración nueva desde cero. Úsalo cuando el usuario describa una nueva integración entre plataformas, diga nuevo proyecto, nueva integración, conectar X con Y, o similar. Actívalo también cuando el usuario mencione webhooks entre dos SaaS, sincronización de datos entre sistemas, o automatización entre plataformas."
user-invocable: true
---

# New Integration — Pipeline Completo bt-engine

Actívate con `/new-integration`, "nueva integración", "conectar X con Y", "nuevo proyecto", o cuando el usuario describa un flujo de datos entre dos plataformas.

El Scribe (`agents/08_agent_scribe.md`) está activo en **todos** los pasos — documenta en paralelo, no espera al final.

## PASO 1 — Consultar vault primero

Antes de cualquier otra cosa:

```
search_notes con nombres de plataformas mencionadas
```

Reportar:
- Qué conocimiento existe ya en vault
- `api_profile_status: vault` si plataforma ya documentada
- `api_profile_status: research_needed` si no existe

## PASO 2 — Activar Intake

Cargar `agents/02_agent_intake.md`.
Aplicar protocolo completo de briefing.
**No avanzar sin `intake_briefing.json` completo y confirmado por el usuario.**
Requerimiento mínimo: `confidence_level >= medium`.

## PASO 3 — Research (solo si research_needed)

Cargar `agents/03_agent_research.md`.
Si vault tiene el perfil completo → saltar este paso.
Si perfil parcial → completar solo los datos faltantes.

## PASO 4 — FinOps en paralelo con Research

Cargar `agents/04_agent_finops.md`.
Ejecutar simultáneamente con Research cuando sea posible.
**Gate bloqueante: esperar `status: approved`.**

## PASO 5 — Developer

Solo activar con los tres presentes:
- Research completo (o vault confirmado)
- FinOps `status: approved`
- `intake_briefing.json` `confidence_level >= medium`

Cargar `agents/05_agent_developer.md`.

## PASO 6 — QA

Cargar `agents/06_agent_qa.md`.
Bucle hasta `qa_report status: pass`.
**Máximo 3 iteraciones → escalar al usuario si no pasa.**

## PASO 7 — Security

Cargar `agents/10_agent_security.md`.
Gate paralelo a QA.
**Sin security pass → no hay deploy. Sin excepciones.**

## PASO 8 — Decisión de despliegue

Presentar al usuario estos criterios antes de avanzar:

- ¿Tests cubren happy path + gotchas críticos de las plataformas?
- ¿FinOps aprobado con margen conocido?
- ¿Caso de uso completo end-to-end validado?

**Esperar confirmación explícita — nunca asumir deploy autorizado.**

## PASO 9 — DevOps

Solo con decisión aprobada explícitamente por el usuario.
Cargar `agents/07_agent_devops.md`.

## Gates bloqueantes (no saltar)

```
GATE 0: intake_briefing.json (confidence >= medium)
GATE 1: api_profile.json completo
GATE 2: finops_report.json (status: approved)
GATE 3: security_report.json (ready_for_devops: true)
GATE 4: qa_report.json (status: pass)
GATE 5: deploy_decision explícita del usuario
```

Si cualquier gate falla → reportar al usuario y esperar. No improvisar.
