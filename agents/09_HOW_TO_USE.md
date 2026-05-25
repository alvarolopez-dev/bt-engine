# Bigtoone AI Agent Ecosystem — Cómo usar esto

Para integrar dos plataformas con este ecosistema, haz esto:

---

## Qué es

Un pipeline de 8 agentes especializados que convierte "quiero integrar A con B"
en código TypeScript desplegado en AWS Lambda, al menor coste posible.

```
PLATAFORMA A  ──→  AWS LAMBDA  ──→  PLATAFORMA B
```

Cada agente hace una sola cosa. Ninguno invade el territorio del siguiente.
El Orquestador coordina. Tú solo hablas con el Orquestador.

| # | Agente | Rol | Se activa cuando |
|---|--------|-----|-----------------|
| 01 | Orquestador | Director del pipeline | Siempre primero |
| 02 | Intake | Interroga al usuario | Orquestador lo llama |
| 03 | Research | Investiga las APIs | Intake entregó briefing |
| 04 | FinOps | Aprueba el coste | Intake entregó briefing |
| 05 | Developer | Escribe el código | Research + FinOps listos |
| 06 | QA | Valida con tests | Developer entregó código |
| 07 | DevOps | Despliega en AWS | QA pasó + decisión explícita |
| 08 | Scribe | Documenta en la vault | Siempre, en paralelo |

---

## Proyecto nuevo — paso a paso

**1. Abre Claude Code en el directorio del proyecto.**

**2. Carga el Orquestador:**
```
Lee 01_agent_orchestrator.md. Tengo un proyecto nuevo.
```

**3. El Orquestador analiza el directorio y activa el Intake. Carga el Intake:**
```
Lee 02_agent_intake.md. El usuario quiere: [descripción en lenguaje natural].
```
El Intake hace preguntas. Respóndelas. Cuando confirmes el briefing, entrega al Orquestador.

**4. El Orquestador activa Research y FinOps en paralelo. Cárgalos juntos:**
```
Lee 03_agent_research.md. Las plataformas son [A] y [B].
Los unknowns del briefing son: [lista de unknowns_for_research].
```
```
Lee 04_agent_finops.md. La arquitectura propuesta es: [Lambdas del plan].
El volumen estimado es: [dato del briefing].
```
Espera ambos resultados antes de continuar.

**5. Si FinOps bloquea** → para. Lee el `blocking_reason`. Escala al usuario si el coste supera €5/mes.
**Si FinOps aprueba** → continúa.

**6. El Orquestador activa el Developer:**
```
Lee 05_agent_developer.md. 
Tarea: [descripción en 3-5 líneas].
Ficheros a crear o modificar: [lista].
API_PROFILE de Research: [pegar el JSON o indicar fichero].
FinOps: aprobado.
```

**7. Developer entrega. El Orquestador activa QA:**
```
Lee 06_agent_qa.md.
Ficheros modificados: [developer_report.json → files_modified].
API_PROFILE: [mismo que el Developer recibió].
```

**8. Si QA falla** → el Orquestador pasa el JSON de fallo al Developer. Vuelta al paso 6.
**Si QA pasa** → el Orquestador evalúa si desplegar (nunca automático — decisión consciente).

**9. Decisión de despliegue tomada. El Orquestador activa DevOps:**
```
Lee 07_agent_devops.md.
qa_report.json: passed.
finops_report.json: approved.
Stage: prod / staging.
```

**10. DevOps despliega y verifica. El Scribe cierra el proyecto en la vault.**

---

## Si algo falla

| Síntoma | Responsable | Acción |
|---------|-------------|--------|
| QA falla más de 3 veces | Orquestador | Escalar al usuario — hay algo estructural mal |
| FinOps bloquea | Usuario | Revisar `blocking_reason` — rediseñar arquitectura o aprobar explícitamente |
| Developer bloqueado en unknown de API | Research | Reactivar Research con ese endpoint específico |
| Deploy falla → rollback ejecutado | DevOps | DevOps reporta causa exacta → Orquestador decide |
| Agente no responde con JSON esperado | Orquestador | Releer el fichero del agente y reactivar con los inputs correctos |

---

## Retomar un proyecto interrumpido

El estado del pipeline vive en `project_state.json` (en la raíz del proyecto, gitignored).

```
Lee 01_agent_orchestrator.md.
El proyecto está interrumpido. Lee project_state.json y retoma desde donde estaba.
```

El Orquestador lee `pipeline_status` del JSON, detecta qué fase estaba activa,
y reactiva el agente correcto con el contexto disponible.

---

## La vault de Obsidian

Toda la memoria del ecosistema vive en `dev-log/`.

- **Abrir en Obsidian:** File → Open Vault → seleccionar la carpeta `dev-log/`
- **Entrada:** `dev-log/index.md` — mapa completo con links a todos los nodos
- **Plataformas conocidas:** `dev-log/knowledge-base/platforms/`
- **Errores resueltos:** `dev-log/knowledge-base/errors/`
- **Patrones validados:** `dev-log/knowledge-base/patterns/`
- **Coste real histórico:** `dev-log/knowledge-base/costs/`

El Scribe actualiza la vault automáticamente en cada proyecto.
Antes de arrancar un proyecto nuevo, el Scribe consulta la vault
y da al Orquestador el contexto relevante — sin coste de investigación.

---

## Referencia rápida

| Fichero | Agente | Filtro caveman |
|---------|--------|----------------|
| `01_agent_orchestrator.md` | Orquestador | "¿Sé QUÉ y QUIÉN? Si estoy explicando el CÓMO, me he equivocado de agente." |
| `02_agent_intake.md` | Intake | "¿Extraigo del humano o asumo yo?" |
| `03_agent_research.md` | Research | "¿Es dato confirmado por fuente oficial o lo estoy infiriendo?" |
| `04_agent_finops.md` | FinOps | "¿Estoy calculando o estoy opinando?" |
| `05_agent_developer.md` | Developer | "¿El código funciona con lo que el API_PROFILE garantiza o con lo que asumo?" |
| `06_agent_qa.md` | QA | "¿El mock refleja lo que el API_PROFILE dice que puede devolver o lo que asumo?" |
| `07_agent_devops.md` | DevOps | "¿Tengo QA pass + FinOps approved + decisión del Orquestador? Si falta uno, no despliego." |
| `08_agent_scribe.md` | Scribe | "¿Este conocimiento estará disponible para el siguiente proyecto?" |

---

*Bigtoone AI Agent Ecosystem v2.0 — Si algo no está claro, el Orquestador es siempre el punto de entrada.*
