# Optimization Report — Ecosistema Bigtoone Agentes IA
## Diagnóstico + Propuesta de refactorización

Generado: 2026-05-25
Ejecutado: 2026-05-25
Rollback tag: `v1.0.0-pre-optimization`
Estado: **✅ EJECUTADO COMPLETAMENTE — 11 commits desplegados**

### Métricas reales de reducción

| Agente | Antes | Después | Reducción |
|--------|-------|---------|-----------|
| Developer (05) | 797 | 333 | -58% |
| Scribe (08) | 649 | 209 | -68% |
| QA (06) | 575 | 285 | -50% |
| Research (03) | 574 | 259 | -55% |
| Orchestrator (01) | 574 | 462 | -19% |
| Intake (02) | 476 | ~480 | +1% (añadido constraints notice) |
| DevOps (07) | 464 | ~470 | +1% (añadido constraints notice) |
| FinOps (04) | 429 | ~433 | +1% (añadido constraints notice) |
| Security (10) | 425 | ~429 | +1% (añadido constraints notice) |
| **TOTAL** | **4.963** | **~3.360** | **-32%** |

Nodos vault creados: 6 (agent-details/) + 2 ficheros de referencia (00_CONSTRAINTS.md, 00_TREE.md)
Líneas movidas a vault desde agentes: ~1.170 líneas de código extraído

---

## SECCIÓN A — Tamaño de agentes

| Agente | Líneas totales | Líneas de rol/reglas | Líneas estáticas extraíbles | Estado |
|--------|---------------|---------------------|--------------------------|--------|
| 05_developer.md | **797** | ~230 | ~567 | ⚠️ MUY PESADO |
| 08_scribe.md | **649** | ~200 | ~449 | ⚠️ PESADO |
| 06_qa.md | **575** | ~160 | ~415 | ⚠️ PESADO |
| 03_research.md | **574** | ~180 | ~394 | ⚠️ PESADO |
| 01_orchestrator.md | **574** | ~300 | ~274 | ⚠️ PESADO |
| 02_intake.md | 476 | ~340 | ~136 | ✅ ACEPTABLE |
| 07_devops.md | 464 | ~280 | ~184 | ✅ ACEPTABLE |
| 04_finops.md | 429 | ~280 | ~149 | ✅ ACEPTABLE |
| 10_security.md | 425 | ~280 | ~145 | ✅ ACEPTABLE |
| **TOTAL** | **4.963** | **~2.250** | **~2.713** | — |

> **Líneas estáticas extraíbles:** código de ejemplo, plantillas, esquemas JSON, perfiles de plataforma.
> Pueden vivir en la vault y ser referenciadas con `[[enlace]]`. No necesitan estar en el agente.

### Detalle por agente — qué ocupa cada línea

#### 05_developer.md (797 líneas) ⚠️

| Sección | Líneas | Contenido | Extráible |
|---------|--------|-----------|-----------|
| §1-2 Contrato + Reglas | ~75 | Reglas de rol | Parcial (constraints universales) |
| §3 Migración strict | ~35 | Protocolo + código | Sí → vault |
| §4 Anatomía handler | ~50 | Código TypeScript | Sí → `[[handler-structure]]` ya existe |
| §5 Secrets | ~40 | Código TypeScript | Sí → `[[lambda-patterns]]` ya existe |
| §6 Logging Pino | ~30 | Código TypeScript | Sí → `[[lambda-patterns]]` ya existe |
| §7 Errores 3 niveles | ~50 | Código TypeScript | Sí → `[[lambda-patterns]]` ya existe |
| §8 Patrones P1-P8 | ~175 | Código TypeScript | Sí → `[[lambda-patterns]]` ya existe |
| §9 Antipatrones E1-E6 | ~115 | Código TypeScript | Sí → `[[errors/*]]` ya existe |
| §10 Estilo de código | ~70 | Naming + comentarios | Sí → nuevo nodo `[[developer-style]]` |
| §11 Gestión unknowns | ~35 | Protocolo decisión | No — lógica de rol |
| §12 Qué no haces | ~10 | Límites de rol | No — esencial |
| §13 developer_report.json | ~50 | Schema JSON | Parcial — formato esencial |
| §14 Autoauditoría | ~10 | Chequeo de rol | No — esencial |

**Conclusión:** 05_developer puede ir de 797 a ~260 líneas.
Todo el código de §4-§9 ya existe en la vault (`lambda-patterns.md` tiene P1-P14, `errors/` tiene E1-E6).
El agente solo necesita decir: "Ver [[lambda-patterns]] para patrones. Ver [[errors/*]] para antipatrones."

#### 08_scribe.md (649 líneas) ⚠️

| Sección | Líneas | Extráible |
|---------|--------|-----------|
| §1 Por qué Scribe es diferente | ~15 | No — rol |
| §2 Vault existente | ~30 | No — contexto necesario |
| §3 Triggers 1-6 con templates | ~420 | Sí → `[[scribe-templates]]` nuevo |
| §4 Sistema de confianza | ~20 | No — regla de negocio |
| §5 Sintaxis Obsidian | ~40 | Sí → `[[scribe-templates]]` |
| §6 Regla de oro | ~10 | No — esencial |
| §7-9 Límites + estructura | ~25 | No — esencial |

**Conclusión:** 08_scribe puede ir de 649 a ~160 líneas.
Los templates de los 6 triggers (el cuerpo grande) van a vault: `[[scribe-templates]]`.

#### 06_qa.md (575 líneas) ⚠️

| Sección | Líneas | Extráible |
|---------|--------|-----------|
| §1-2 Contrato + Reglas | ~55 | Parcial (R3 strict → constraints) |
| §3 Protocolo de mocks | ~50 | Sí → `[[qa-test-cases]]` nuevo |
| §4 Suite obligatoria 4.1-4.4 | ~120 | Sí → `[[qa-test-cases]]` nuevo |
| §5 Cobertura de gotchas E1-E6 | ~90 | Sí → `[[qa-test-cases]]` nuevo |
| §6 Casos de caos | ~60 | Sí → `[[qa-test-cases]]` nuevo |
| §7-8 Criterios aprobación/bloqueo | ~30 | No — reglas de rol |
| §9 Qué QA no hace | ~10 | No — esencial |
| §10 qa_report.json | ~85 | Sí → parcial (schemas extensos) |

**Conclusión:** 06_qa puede ir de 575 a ~180 líneas.
Todo el código de tests va a vault: `[[qa-test-cases]]`. El agente referencia con "Ver [[qa-test-cases]] para código de cada gotcha."

#### 03_research.md (574 líneas) ⚠️

| Sección | Líneas | Extráible |
|---------|--------|-----------|
| §1-2 Rol + Reglas | ~90 | Parcial |
| §3 Proceso investigación | ~45 | No — protocolo esencial |
| §4 PrestaShop profile (JSON completo) | ~130 | Sí → `[[prestashop]]` YA EXISTE en vault |
| §4 Holded profile (JSON completo) | ~125 | Sí → `[[holded]]` YA EXISTE en vault |
| §5 API_PROFILE schema | ~60 | Sí → nuevo nodo `[[api-profile-template]]` |
| §6 Priorización unknowns | ~25 | No — protocolo esencial |
| §7-8 Output + Autoauditoría | ~30 | No — esencial |

**Conclusión:** 03_research puede ir de 574 a ~220 líneas.
Los perfiles de PrestaShop y Holded ya están en la vault. El agente los duplica innecesariamente.
El agente debería decir: "Ver [[prestashop]] y [[holded]] para perfiles precargados."

#### 01_orchestrator.md (574 líneas) ⚠️

| Sección | Líneas | Extráible |
|---------|--------|-----------|
| §1-2 Rol + patrón Bigtoone | ~40 | No — esencial |
| §3 Flujo de activación | ~50 | No — esencial |
| §4 Condiciones activación | ~60 | No — esencial |
| §5 project_state.json | ~45 | Sí → `[[plan-template]]` nuevo |
| §6 Deuda TypeScript | ~25 | Parcial → constraints |
| §7 Análisis inicial | ~25 | No — protocolo |
| §8 Protocolo arranque | ~25 | No — protocolo |
| §9 plan.json (estructura completa) | ~80 | Sí → `[[plan-template]]` nuevo |
| §10 Decisión despliegue | ~25 | No — esencial |
| §11-12 Fallos + escalado | ~35 | No — esencial |
| §13 Estructura directorio | ~30 | Sí → `[[00_TREE.md]]` |
| §14-15 Output + delegación | ~35 | No — esencial |

**Conclusión:** 01_orchestrator puede ir de 574 a ~370 líneas.
Ganancia moderada — el orquestador tiene más contenido de rol que de código estático.

---

## SECCIÓN B — Información duplicada entre agentes

| Información | Dónde aparece | Tipo duplicación |
|-------------|---------------|-----------------|
| **TypeScript strict: true** | Developer §3, §10; QA R3; Orchestrator §6 | 4 agentes, mismo constraint |
| **Handler structure** (cargarSecretos→guard→loop) | Developer §4 + QA §4.1 | Código completo duplicado |
| **E1-E6 errores** | Developer §9 (código) + QA §5 (tests) + Research §4 (gotchas) | 3 versiones del mismo error |
| **Holded API auth** | Research §4 + DevOps §3 ADR | 2 agentes, contexto diferente |
| **PrestaShop/Holded JSON profiles** | Research §4 completo + vault knowledge-base/ | ¡YA ESTÁN EN LA VAULT! |
| **Lambda patterns P1-P8** | Developer §8 completo + vault lambda-patterns.md | ¡YA ESTÁN EN LA VAULT! |
| **Degradación silenciosa** | Developer §7 + QA §4.4 + vault patterns/ | 3 lugares |
| **ConditionalCheck idempotencia** | Developer §6 P6 + QA §4.3 + vault | 3 lugares |
| **Coste historial $0.82/mes** | FinOps §7 + Scribe §6 + vault costs/ | 3 lugares, ya en vault |
| **Security gate pre-deploy** | Security §1 (define gate) + DevOps (no actualizado aún) | Gate sin implementar en DevOps |
| **Footer pattern** | Todos los agentes: "Agente XX · v2.0" | 10 ficheros, línea redundante |
| **"no API calls en tests"** | QA R1 + potencialmente en 00_CONSTRAINTS.md | Constraint universal |

**Hallazgo crítico:** Los perfiles de PrestaShop y Holded en Research §4 son una duplicación completa de lo que ya existe en `dev-log/knowledge-base/platforms/`. Research embebe el JSON completo (~255 líneas) innecesariamente.

---

## SECCIÓN C — Contenido que debería vivir en la vault

### Ya existe en vault pero está duplicado en agentes

| Contenido | Agente que lo duplica | Nodo vault existente |
|-----------|----------------------|---------------------|
| PrestaShop API profile | Research §4 (~130 líneas) | `[[prestashop]]` |
| Holded API profile | Research §4 (~125 líneas) | `[[holded]]` |
| Lambda patterns P1-P14 | Developer §8 (~175 líneas) | `[[lambda-patterns]]` |
| Handler structure | Developer §4 (~50 líneas) | `[[handler-structure]]` |
| Secrets Manager pattern | Developer §5 (~40 líneas) | `[[lambda-patterns]]` |
| Errors E1-E6 descriptions | Developer §9 + QA §5 (~200 líneas total) | `[[errors/*]]` |
| Coste historial real | FinOps §7 (~40 líneas) | `[[prestashop-holded-prod]]` |

**Total duplicado en agentes que ya está en vault: ~760 líneas.**

### Nuevo contenido que debería ir a la vault

| Contenido | Agente origen | Nodo vault propuesto |
|-----------|--------------|---------------------|
| Scribe templates (6 triggers completos) | Scribe §3 (~420 líneas) | `agent-details/scribe-templates.md` |
| QA test code (gotchas + caos) | QA §3-6 (~320 líneas) | `agent-details/qa-test-cases.md` |
| API_PROFILE schema | Research §5 (~60 líneas) | `agent-details/api-profile-template.md` |
| plan.json + project_state.json schemas | Orchestrator §5+§9 (~125 líneas) | `agent-details/plan-template.md` |
| Developer naming/style guide | Developer §10 (~70 líneas) | `agent-details/developer-style.md` |
| DevOps verification commands | DevOps §5 (~100 líneas) | `agent-details/devops-checklist.md` |
| Security checklist (ya creado) | Security §5 (~200 líneas) | `security/checklist-pre-deploy.md` ✅ ya existe |

---

## SECCIÓN D — Análisis de carga

### MCP filesystem — ¿siempre necesario?

| Agente | Necesita filesystem? | Cuándo | Carga innecesaria? |
|--------|---------------------|--------|-------------------|
| Scribe | ✅ Sí, siempre | Lee y escribe vault constantemente | No |
| Research | ✅ Sí, al inicio | Lee perfiles existentes de la vault | Solo si vault ya tiene el perfil |
| Orchestrator | ⚠️ Ocasional | Lee project_state.json | Solo en sesiones con proyecto activo |
| Developer | ⚠️ Ocasional | Lee project_state.json, escribe developer_report | Solo al inicio/cierre |
| DevOps | ⚠️ Ocasional | Lee env vars, escribe devops_report | Solo al inicio/cierre |
| QA | ❌ Raramente | Lee ficheros de código del Developer | Podría operar sin él |
| FinOps | ❌ Casi nunca | Solo para leer finops_report histórico | Alta carga innecesaria |
| Intake | ❌ No | No lee ni escribe vault directamente | Carga innecesaria |
| Security | ⚠️ Ocasional | Lee código para auditar | Solo en modo auditoría activa |

**Hallazgo:** MCP filesystem se carga en todas las sesiones aunque solo Scribe y Research lo usan constantemente. Agents como Intake y FinOps nunca lo necesitan en su activación típica.

### Agentes que cargan información que no usan en cada activación

- **Research:** carga perfiles de PrestaShop + Holded completos (~255 líneas) aunque sean para una plataforma diferente. Si el proyecto es Shopify → esas líneas son carga muerta.
- **QA:** carga toda la suite de tests E1-E6 aunque el proyecto no use PrestaShop.
- **Developer:** carga todos los patrones P1-P8 y E1-E6 aunque el proyecto solo use 2 de ellos.

**Conclusión:** el contenido estático en los agentes no es selectivo — se carga todo aunque solo aplique una parte. En la vault, el agente puede leer solo el nodo que necesita.

---

## SECCIÓN E — Mapa del proyecto

**¿Existe tree.md?** No existe ningún fichero de mapa visual en la raíz.

```bash
ls *.md
# 01_agent_orchestrator.md  05_agent_developer.md  09_HOW_TO_USE.md
# 02_agent_intake.md        06_agent_qa.md          README.md
# 03_agent_research.md      07_agent_devops.md
# 04_agent_finops.md        08_agent_scribe.md      10_agent_security.md
```

README.md existe (104 líneas) pero no incluye un mapa visual completo del pipeline, los agentes, y la vault.

**Mejora obvia:** crear `00_TREE.md` como punto de entrada visual que cualquier agente puede leer en 30 líneas para orientarse.

---

---

## FASE 2 — PROPUESTA DE REFACTORIZACIÓN

### Objetivo cuantificado

| Métrica | Actual | Objetivo | Reducción |
|---------|--------|----------|-----------|
| Total líneas en agentes | 4.963 | ~2.200 | -56% |
| Agentes sobre 500 líneas | 5 | 0 | -100% |
| Agentes sobre 300 líneas | 8 | 5 | -37% |
| Información duplicada | ~760 líneas | 0 | -100% |
| Información ya en vault | Ya existe | Referenciada | — |

---

### PRINCIPIOS RECTORES

```
1. Ningún agente supera 500 líneas
2. Información estática vive en la vault
3. Agentes referencian vault: "Ver [[nodo]]" en lugar de embed
4. Constraints universales en 00_CONSTRAINTS.md (todos los agentes lo leen)
5. Cada agente carga SOLO lo que necesita en su activación
6. Contenido específico de plataforma NUNCA en el agente — siempre en vault
```

---

### ESTRUCTURA PROPUESTA

```
agents/                               ← todos los .md de agentes (directorio nuevo)
├── 00_CONSTRAINTS.md                 ← NUEVO — constraints universales
├── 00_TREE.md                        ← NUEVO — mapa visual del proyecto
├── 01_agent_orchestrator.md          ← refactorizado: 574 → ~370 líneas
├── 02_agent_intake.md                ← sin cambios: 476 líneas (✅ en rango)
├── 03_agent_research.md              ← refactorizado: 574 → ~220 líneas
├── 04_agent_finops.md                ← sin cambios: 429 líneas (✅ en rango)
├── 05_agent_developer.md             ← refactorizado: 797 → ~260 líneas
├── 06_agent_qa.md                    ← refactorizado: 575 → ~180 líneas
├── 07_agent_devops.md                ← actualización gate Security: ~480 líneas
├── 08_agent_scribe.md                ← refactorizado: 649 → ~160 líneas
├── 09_HOW_TO_USE.md                  ← sin cambios
└── 10_agent_security.md              ← sin cambios: 425 líneas (✅ en rango)

dev-log/knowledge-base/
├── platforms/                        ← ya existe
├── aws/                              ← ya existe
├── patterns/                         ← ya existe
├── errors/                           ← ya existe
├── security/                         ← ya existe
├── costs/                            ← ya existe
└── agent-details/                    ← NUEVO directorio
    ├── scribe-templates.md           ← extraído de Scribe §3
    ├── qa-test-cases.md              ← extraído de QA §3-6
    ├── api-profile-template.md       ← extraído de Research §5
    ├── plan-template.md              ← extraído de Orchestrator §5+§9
    ├── developer-style.md            ← extraído de Developer §10
    └── devops-checklist.md           ← extraído de DevOps §5
```

---

### 00_CONSTRAINTS.md — Reglas universales

Contenido propuesto (este fichero lo lee cada agente al inicio):

```markdown
# CONSTRAINTS UNIVERSALES — Ecosistema Bigtoone

Aplican a todos los agentes sin excepción.

## Stack fijo
- Runtime: nodejs20.x (SF v3 max — ver ADR-2b)
- Framework: Serverless Framework v3.38.0 (congelado)
- Región AWS: eu-west-1, eu-west-2, o eu-west-3 (GDPR)
- DB: DynamoDB PAY_PER_REQUEST (nunca PROVISIONED)
- IaC: serverless.yml es siempre la fuente de verdad

## Código (Developer + QA)
- TypeScript strict: true — sin excepciones
- Nunca console.log → siempre Pino
- Zod en todo input externo (boundary del sistema)
- Patrón handler: cargarSecretos → guard → loop → return
- Secrets: Secrets Manager en prod, .env solo en local
- PII nunca en logs de CloudWatch

## Pipeline (todos los agentes)
- Sin API_PROFILE → Developer no escribe código
- Sin QA pass + FinOps approved + Security pass → DevOps no despliega
- Sin confirmación humana → Orchestrador no avanza
- Sin intake_briefing.json → ningún agente técnico activa
- Nunca API Gateway (usar Lambda URLs)

## Seguridad (Developer + Security)
- Validar firma de webhook ANTES de procesar payload
- Secrets solo de Secrets Manager en producción
- IAM mínimo — sin wildcards en DynamoDB/S3/SNS/Secrets Manager
- GDPR: datos de clientes nunca fuera de UE/adecuación

## REGLA DE PESADEZ
"Ningún agente avanza sin certeza absoluta.
Si tiene dudas → pregunta.
Si la pregunta parece obvia → pregunta igual.
Un agente que asume cuesta más tokens que uno que pregunta cinco veces.
La mediocridad no es una opción. Pesado por diseño, no por accidente."
```

---

### Cambios por agente

#### 05_developer.md: 797 → ~260 líneas

**Qué sale:**
- §4 Anatomía handler (50 líneas) → `"Ver [[handler-structure]] para código completo"`
- §5-7 Secrets + Logging + Errores (~120 líneas) → `"Ver [[lambda-patterns]] §P1-P14"`
- §8 Patrones P1-P8 (~175 líneas) → `"Ver [[lambda-patterns]] para todos los patrones"`
- §9 Antipatrones E1-E6 (~115 líneas) → `"Ver [[errors/*]] para código de cada error"`
- §10 Estilo (~70 líneas) → `"Ver [[developer-style]] para naming y comentarios"`

**Qué queda:**
- Contrato de entrada (inputs requeridos)
- Reglas absolutas R1-R6 (lógica de decisión, no código)
- §11 Gestión de unknowns del API_PROFILE
- §12 Qué no haces
- §13 developer_report.json (schema mínimo, no ejemplos extensos)

**Formato de referencia en el agente:**
```markdown
## 4. PATRONES OBLIGATORIOS

Todo código del proyecto sigue los patrones validados en producción.
No reinventar. No simplificar. Aplicar directamente.

- **Handler structure:** `[[handler-structure]]` — orden obligatorio: cargarSecretos → guard → loop → return
- **Secrets:** `[[lambda-patterns]]` §P4 — singleton + flag de caché
- **Logging:** `[[lambda-patterns]]` §P3 — Pino, niveles, correlationId
- **Errores 3 niveles:** `[[lambda-patterns]]` §P8 — fatal / por ítem / degradación
- **Idempotencia:** `[[idempotencia-dynamodb]]` — ConditionalExpression
- **Patrones completos P1-P14:** `[[lambda-patterns]]`

## 5. ANTIPATRONES CONOCIDOS

Antes de escribir código, revisar si hay un error documentado que lo cubra:
- `[[e1-object-object-nombres]]` — nombres multi-idioma PrestaShop
- `[[e2-race-condition-facturas-duplicadas]]` — ConditionalCheck
- `[[e3-order-rows-tres-formatos]]` — normalización order_rows
- `[[e4-caracteres-invisibles]]` — U+200E en strings
- `[[e5-campo-estado-renombrado]]` — migración de campos DynamoDB
- `[[e6-panel-router-sin-url]]` — Lambda sin URL en tier Basic
```

---

#### 03_research.md: 574 → ~220 líneas

**Qué sale:**
- §4 PrestaShop JSON completo (~130 líneas) → `"Ver [[prestashop]] en vault"`
- §4 Holded JSON completo (~125 líneas) → `"Ver [[holded]] en vault"`
- §5 API_PROFILE schema (~60 líneas) → `"Ver [[api-profile-template]] en vault"`

**Qué queda:**
- §1-2 Rol + Reglas (lógica de cuándo confiar en qué fuente)
- §3 Proceso de investigación (protocolo — no código)
- §4 reducido a: tabla de plataformas en vault + instrucción de cómo usarlas
- §6 Priorización de unknowns
- §7-8 Output + autoauditoría

**Formato de referencia:**
```markdown
## 4. PLATAFORMAS PRECARGADAS EN LA VAULT

Antes de investigar una plataforma, verificar si tiene perfil en la vault:

| Plataforma | Nodo vault | Confianza | Última validación |
|---|---|---|---|
| PrestaShop 1.7.x | `[[prestashop]]` | high — producción | 2026-05-15 |
| Holded v1/v2 | `[[holded]]` | high — producción | 2026-05-20 |
| ... | ... | ... | ... |

**Plataforma en vault:** cargar el perfil como base. Verificar solo si la versión del cliente difiere.
**Plataforma nueva:** investigar desde cero. Ver [[api-profile-template]] para el esquema de salida.
```

---

#### 06_qa.md: 575 → ~180 líneas

**Qué sale:**
- §3 Protocolo de mocks con código completo (~50 líneas) → `[[qa-test-cases]]`
- §4 Suite de pruebas 4.1-4.4 con código (~120 líneas) → `[[qa-test-cases]]`
- §5 Cobertura gotchas E1-E6 con código (~90 líneas) → `[[qa-test-cases]]`
- §6 Casos de caos con código (~60 líneas) → `[[qa-test-cases]]`

**Qué queda:**
- §1-2 Contrato + Reglas (lógica, no código)
- §7-8 Criterios de aprobación/bloqueo (lógica)
- §9 Qué QA no hace
- §10 qa_report.json (schema)
- Referencias: "Para código de cada gotcha → `[[qa-test-cases]]`"

**Formato de referencia:**
```markdown
## 3. SUITE OBLIGATORIA — VER VAULT

Todo el código de tests está documentado en `[[qa-test-cases]]`.
Estructura:
- §1 Anatomía del handler (guard, loop, return)
- §2 Secrets con caché (warm start)
- §3 Idempotencia (ConditionalCheckFailedException)
- §4 Degradación silenciosa (ENABLE_* vars)
- §5 Gotchas E1-E6 con código completo
- §6 Chaos cases PrestaShop + Holded

Regla: para cada gotcha en el API_PROFILE → test obligatorio.
Ver `[[qa-test-cases]]` §5-6 para código de referencia.
```

---

#### 08_scribe.md: 649 → ~160 líneas

**Qué sale:**
- §3 Templates de 6 triggers (~420 líneas) → `[[scribe-templates]]`
- §5 Sintaxis Obsidian (~40 líneas) → `[[scribe-templates]]`

**Qué queda:**
- §1 Por qué el Scribe es diferente
- §2 Vault existente (contextual, no extenso)
- §3 reducido a: tabla de 6 triggers + "Ver [[scribe-templates]] para cada template"
- §4 Sistema de confianza acumulada
- §6 Regla de oro
- §7-9 Límites + estructura + autoauditoría

---

#### 07_devops.md — Actualización pendiente (security gate)

**Problema detectado:** el gate de DevOps en §1 requiere QA + FinOps + Orquestador.
El agente Security (creado en commit 2920896) define que su `security_report.json`
con `ready_for_devops: true` es gate obligatorio antes de DevOps.
**DevOps aún no lo incorpora.** Es un gap de consistencia.

**Cambio propuesto:**
```json
// GATE 1: qa_report.json — sin cambios
// GATE 2: finops_report.json — sin cambios
// GATE 3 (NUEVO): security_report.json
//   ✅ status: "pass" o "warn"
//   ✅ ready_for_devops: true
// GATE 4: Orquestador — decisión explícita (antes era GATE 3)
```

---

### 00_TREE.md — Mapa visual propuesto

```markdown
# Ecosistema Bigtoone — Mapa de agentes y vault

## Pipeline

USUARIO
  ↓
02 INTAKE → intake_briefing.json
  ↓
01 ORQUESTADOR — genera plan.json
  ↓                    ↓                   ↓
03 RESEARCH    04 FINOPS         10 SECURITY
API_PROFILE    finops_report     security_report
  ↓                    ↓                   ↓
  └────────────────────┴───────────────────┘
                       ↓
               05 DEVELOPER → developer_report.json
                       ↓
               06 QA → qa_report.json
                       ↓
               01 ORQUESTADOR — decisión deploy
                       ↓
               07 DEVOPS → devops_report.json
                       ↓
               08 SCRIBE (siempre activo) → dev-log/

## Vault

dev-log/knowledge-base/
  platforms/     → prestashop, holded, revo-*, stripe, shopify...
  aws/           → lambda-patterns, dynamodb-patterns, serverless-framework-v3...
  patterns/      → handler-structure, idempotencia-dynamodb, degradacion-silenciosa...
  errors/        → e1..e6, holded-auth-change-bearer...
  security/      → checklist-pre-deploy, gdpr-bigtoone, webhook-validation...
  costs/         → prestashop-holded-prod...
  agent-details/ → scribe-templates, qa-test-cases, api-profile-template... (propuesto)
```

---

## PREGUNTAS PARA VALIDACIÓN HUMANA

Antes de ejecutar la refactorización, necesito confirmación en 6 puntos:

### P1 — Estructura de directorios

**Pregunta:** ¿Los agentes se mueven a `agents/` como subdirectorio, o permanecen en la raíz?

- **Opción A:** Mantener en raíz (sin cambio de ruta, más simple)
- **Opción B:** Mover a `agents/` (más ordenado, separación clara raíz vs vault)

Mi recomendación: **Opción A** — menos commits de reorganización, misma eficiencia.

---

### P2 — Qué queda en el agente vs qué va a la vault

**Developer §8 Patrones P1-P8:** ¿el agente mantiene una versión corta (solo nombres + qué hace cada uno) o solo el enlace?

- **Opción A:** Solo enlace: "Ver [[lambda-patterns]] para todos los patrones" (mínimo tokens)
- **Opción B:** Tabla resumen en el agente + enlace al código completo en vault (mejor UX)

**QA tests de gotchas:** ¿van TODOS a vault o solo los específicos de plataforma (E1-E6), manteniendo los genéricos (guard, loop, return)?

- **Opción A:** Todo a vault, agente solo referencia
- **Opción B:** Tests genéricos (handler structure, secrets) permanecen en agente; tests de plataforma (E1-E6, PrestaShop, Holded) van a vault

---

### P3 — 00_CONSTRAINTS.md

¿El `00_CONSTRAINTS.md` lo leen los agentes automáticamente (instrucción en cada agente de leerlo al inicio), o es solo documentación de referencia?

- **Opción A:** Instrucción en cada agente: "Al inicio, leer [[00_CONSTRAINTS.md]]"
- **Opción B:** Se copia el constraint relevante en cada agente (duplicación controlada)
- **Opción C:** Es referencia — los constraints se incorporan de forma resumida en cada agente

Mi recomendación: **Opción A** — reduce duplicación al máximo.

---

### P4 — Research §4 (perfiles de plataforma en el agente)

Los perfiles de PrestaShop y Holded están completos en el agente (~255 líneas) Y en la vault.

¿El agente mantiene alguna versión inline o solo referencia la vault?

- **Opción A:** Solo referencia: "Ver [[prestashop]] en vault"
- **Opción B:** Mantiene solo los gotchas más críticos (5 líneas cada uno), vault tiene el detalle

Mi recomendación: **Opción A** — los perfiles ya están en la vault con más detalle.

---

### P5 — Scribe templates

Los 6 triggers del Scribe son operativos (los usa activamente en cada proyecto).
¿Van a vault como referencia, o se mantienen inline porque el Scribe los necesita constantemente?

- **Opción A:** A vault — Scribe lee [[scribe-templates]] cuando necesita un template
- **Opción B:** Mantener inline (el Scribe los usa en cada proyecto, tenerlos cerca tiene sentido)
- **Opción C:** Solo los 6 headers de trigger en el agente + "Ver [[scribe-templates]] §TriggerN para template completo"

Mi recomendación: **Opción C** — equilibrio entre disponibilidad y peso.

---

### P6 — Security gate en DevOps

El agente DevOps no incluye `security_report.json` como gate. ¿Lo actualizo en este mismo proceso de refactorización, o es un cambio separado?

- **Opción A:** Incluirlo en la refactorización (ya que tocamos el agente)
- **Opción B:** Commit separado antes de la refactorización (más limpio)

Mi recomendación: **Opción B** — cambio pequeño, commit separado, no mezclar con refactorización masiva.

---

## Impacto esperado post-refactorización

| Métrica | Actual | Post-refactor |
|---------|--------|--------------|
| Líneas totales agentes | 4.963 | ~2.200 (-56%) |
| Tokens por activación típica | ~4.000-6.000 | ~1.800-2.800 |
| Agentes sobre 500 líneas | 5 | 0 |
| Duplicación de código | ~760 líneas | 0 |
| Vault nodos nuevos necesarios | — | 5-6 |
| Commits necesarios para ejecutar | — | 10-13 (uno por agente) |

---

*Diagnóstico generado: 2026-05-25*
*Tag de rollback: `v1.0.0-pre-optimization`*
*Esperando validación humana en P1-P6 antes de ejecutar cualquier cambio.*
