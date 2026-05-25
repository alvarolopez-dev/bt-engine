---
tags: [scribe, templates, vault]
created: 2026-05-25
extraído-de: agents/08_agent_scribe.md §3
---

# Scribe Templates — Los 6 Triggers

#scribe #templates #vault

[[index]] [[08_agent_scribe]]

Templates completos para los 6 triggers del agente Scribe.
Extraídos de `agents/08_agent_scribe.md §3` para reducir peso del agente.

---

## TRIGGER 1 — Tras Intake completado

**Cuándo:** el Orquestador recibe `intake_briefing.json` con `ready_for_pipeline: true`.

**Qué escribes:** `dev-log/projects/{nombre-proyecto}/00_intake.md`

**Template:**

```markdown
---
tags: [proyecto, intake, {plataforma_a}, {plataforma_b}]
created: {fecha}
estado: en-progreso
---

# {nombre-proyecto} — Intake

[[{plataforma_a}]] → [[{plataforma_b}]]

## Briefing del usuario

| Campo | Valor |
|-------|-------|
| Dirección | {a_to_b / b_to_a / bidireccional} |
| Trigger | {scheduled / event-based / manual} |
| Datos sincronizados | {lista de entidades} |
| Volumen estimado | {N por día/semana/mes} |
| Criterio de éxito | {texto literal del usuario} |
| Confianza | {high / medium / low} |

## Unknowns identificados para Research

| Unknown | Prioridad |
|---------|-----------|
| {unknown 1} | P1 |
| {unknown 2} | P2 |

## Payloads reales

{true → resumen del shape y campos disponibles}
{false → Research los obtendrá}

## Plataformas en la vault

{Para cada plataforma: ¿está documentada? → link o "nueva — Research en blanco"}

*Fecha intake: {fecha}*
*Próximo hito: Research + FinOps en paralelo*
```

---

## TRIGGER 2 — Tras Research completado

**Cuándo:** el Orquestador recibe el `API_PROFILE` completo de Research.

**Qué haces:**

### 2A — Para cada plataforma YA en la vault:

Abrir `dev-log/knowledge-base/platforms/{plataforma}.md`.
Para cada gotcha del `API_PROFILE`:
- **Gotcha YA documentado** → añadir confirmación:
  ```markdown
  <!-- En el nodo existente del gotcha -->
  ## Historial de confirmaciones

  | Proyecto | Fecha | Síntoma observado |
  |---------|-------|-------------------|
  | [[prestashop-holded-middleware-prod]] | 2026-05-15 | TypeError en pedido 304 |
  | [[nuevo-proyecto]] | {fecha} | {síntoma} |

  **Confirmaciones: 2 — [patrón emergente]**
  ```

- **Gotcha NUEVO no documentado** → crear nodo en `errors/`:
  ```markdown
  ---
  tags: [error, {plataforma}, primera-vez]
  created: {fecha}
  confirmaciones: 1
  proyectos: [{nombre-proyecto}]
  ---

  # {id-error} — {título del gotcha}

  #error #{plataforma}

  Detectado por Research en [[{nombre-proyecto}]].
  **Confirmaciones: 1 — [anécdota — confirmar en próximo proyecto]**

  ## Síntoma

  {descripción del síntoma}

  ## Impacto

  {impacto documentado}

  ## Fuente

  {[oficial|comunidad|confirmado en producción|inferido]}

  ## Proyectos donde ocurrió

  - [[{nombre-proyecto}]] — primera detección

  ## Relaciones

  - [[{plataforma}]] — plataforma origen
  - [[{nodo-relacionado}]] — patrón o error similar
  ```

### 2B — Para plataformas NUEVAS (no en la vault):

Crear `dev-log/knowledge-base/platforms/{plataforma}.md` siguiendo el mismo
formato que `prestashop.md` y `holded.md`.
Cada gotcha documentado por Research → su propio nodo en `errors/`.
Enlazar todos al nodo de la plataforma y al proyecto.

### 2C — Actualizar index.md:

Añadir la nueva plataforma a la tabla de plataformas.
Actualizar estadísticas de nodos.

---

## TRIGGER 3 — Durante Development (tiempo real)

**Cuándo:** cada vez que el Developer reporta un `unknown_encountered`,
un bloqueo, o una `api_profile_contradiction` en su `developer_report.json`.
No esperas al final del desarrollo — documentas en caliente.

**Qué escribes:** `dev-log/projects/{nombre-proyecto}/03_dev_log.md`

**Formato append-only — nunca editar entradas anteriores, solo añadir:**

```markdown
---
tags: [dev-log, {nombre-proyecto}, en-progreso]
created: {fecha-inicio}
---

# {nombre-proyecto} — Dev Log

> Registro en tiempo real. Append-only. No editar entradas anteriores.

---

## {fecha} {hora} — {título descriptivo del evento}

**Contexto:** {qué estaba implementando el Developer}
**Evento:** {unknown encontrado / bloqueo / contradicción con API_PROFILE}
**Causa:** {por qué ocurrió — si se conoce}
**Resolución:** {cómo se resolvió — o "pendiente de Research"}
**Tiempo de impacto:** ~{N}h de desarrollo

**¿Nuevo conocimiento para la vault?**
{sí → [[link-al-nodo-creado]] / no}

---
<!-- La siguiente entrada va aquí — no editar la anterior -->
```

**Regla crítica de este trigger:**
Si el Developer encontró algo que contradice el `API_PROFILE` documentado →
además del dev_log, actualizar el nodo de plataforma en `knowledge-base/platforms/`
con la corrección. Research puede estar desactualizado.
Marcar la discrepancia como `[confirmado en producción]` — pesa más que `[oficial]`.

---

## TRIGGER 4 — Tras cada iteración QA fail

**Cuándo:** QA entrega `status: "failed"` y el Orquestador lo recibe.

### 4A — Documentar el fallo en el proyecto:

Añadir entrada en `dev-log/projects/{nombre-proyecto}/03_dev_log.md`:

```markdown
## {fecha} {hora} — QA fail iteración {N}

**Fichero:** {src/utils/normalizarOrderRows.ts:34}
**Error:** {TypeError: Cannot read properties of undefined (reading 'map')}
**Gotcha relacionado:** [[e3-order-rows-tres-formatos]]
**Iteración:** {N} de {max}
**¿Nuevo error no documentado?** {sí/no}
```

### 4B — Si el mismo error ocurre en 2 proyectos distintos:

Crear o actualizar `dev-log/knowledge-base/patterns/patterns-to-avoid.md`:

```markdown
## {título del patrón a evitar}

**Visto en:** [[proyecto-1]], [[proyecto-2]]
**Síntoma:** {descripción exacta}
**Por qué ocurre:** {causa raíz}
**Cómo evitarlo:** {código correcto o patrón alternativo}
**Test que lo habría detectado:** {descripción del test}

> ⚠️ Con 2 confirmaciones en proyectos distintos, este patrón debe añadirse
> como test obligatorio en el Agente QA. Reportado al Orquestador.
```

Reportar al Orquestador:
```
SCRIBE → ORQUESTADOR: sugerencia de actualización de agente

Agente: 06_agent_qa.md
Sección sugerida: §5 COBERTURA DE GOTCHAS
Razón: error {X} ha ocurrido en 2 proyectos distintos
Evidencia: [[proyecto-1]], [[proyecto-2]]
Acción propuesta: añadir test obligatorio para este patrón

Decisión: tuya. No modifico el agente directamente.
```

---

## TRIGGER 5 — Tras despliegue exitoso

**Cuándo:** DevOps entrega `status: "deployed_operational"`.

### 5A — Cerrar el proyecto:

`dev-log/projects/{nombre-proyecto}/05_lessons_learned.md`:

```markdown
---
tags: [proyecto, lessons-learned, cerrado, {plataformas}]
created: {fecha-cierre}
estado: cerrado
---

# {nombre-proyecto} — Lessons Learned

[[{plataforma_a}]] → [[{plataforma_b}]]

## Métricas del proyecto

| Métrica | Valor |
|---------|-------|
| Duración total | {N} días |
| Iteraciones QA fail → fix | {N} |
| Errores nuevos documentados | {N} |
| Errores evitados por vault preexistente | {N} |
| Gotchas de Research que ya estaban en vault | {N}/{total} |

## Coste real vs estimado

| Componente | FinOps estimó | Real (30 días) | Varianza |
|------------|---------------|----------------|----------|
| Lambda | {$X} | {$Y} | {Z%} |
| DynamoDB | {$X} | {$Y} | {Z%} |
| CloudFront | {$X} | {$Y} | {Z%} |
| Secrets Manager | {$X} | {$Y} | {Z%} |
| **Total** | **{$X}** | **{$Y}** | **{Z%}** |

**Coste dominante:** {componente} — {razón}
**¿Estimación de FinOps fue precisa?** {sí/no — si no, qué faltó considerar}

## Nuevos nodos añadidos a la vault

{lista de [[links]] a nodos creados en este proyecto}

## Errores evitados por la vault

{lista de errores que el Developer no cometió porque los vio en knowledge-base}
{Si la lista está vacía: "primer proyecto con estas plataformas — los errores
 documentados aquí protegerán al siguiente equipo"}

## Patrones validados en este proyecto

{lista de [[links]] a patrones que se usaron y se confirmaron}

## Sugerencias para agentes (→ Orquestador)

{Si hay algo que debería cambiar en algún agente basado en lo aprendido}
{Si no hay nada: "ninguna — el ecosistema respondió como se esperaba"}

*Proyecto cerrado: {fecha}*
*Documentado por: Scribe*
```

### 5B — Actualizar historial de costes:

`dev-log/knowledge-base/costs/{nombre-proyecto}-prod.md`:

```markdown
---
tags: [costes, produccion, {plataformas}]
created: {fecha}
---

# Coste real — {nombre-proyecto}

## Parámetros

| Parámetro | Valor |
|-----------|-------|
| Integración | {plataforma_a} → {plataforma_b} |
| Volumen | ~{N} registros/día |
| Región AWS | {eu-west-2} |
| Tiers activos | {Basic / Pro / Pro+} |

## Coste mensual real

{tabla completa por componente}

**Total:** {$X/mes}

## Comparación FinOps

{FinOps estimó $X. Real fue $Y. Varianza de Z%.}
{Razón de la varianza si la hay.}

## Referencia para proyectos similares

{Qué usar como baseline si hay una integración similar en el futuro}

## Relaciones

- [[{nombre-proyecto}]] — proyecto origen
- [[{plataforma_a}]] — plataforma origen
- [[{plataforma_b}]] — plataforma destino
```

### 5C — Actualizar index.md:

- Cambiar estado del proyecto a `Cerrado`
- Actualizar estadísticas de nodos
- Añadir entrada al historial de costes reales
- Actualizar "nodos con más enlaces entrantes" si ha cambiado

---

## TRIGGER 6 — Al arrancar proyecto nuevo

**Cuándo:** ANTES de que el Orquestador active el Intake para un proyecto nuevo.
Este trigger es el más valioso: genera contexto gratuito que ahorra tokens en todo el pipeline.

**Cómo funciona:**
El Orquestador pasa los nombres de plataformas detectados (si los conoce del contexto inicial).
El Scribe consulta la vault y devuelve el informe al Orquestador.

**Output — informe al Orquestador:**

```
SCRIBE — AUDITORÍA PRE-PROYECTO
────────────────────────────────────────────────────────────────

Plataformas detectadas: {PrestaShop} + {Holded}

PLATAFORMAS EN LA VAULT
→ [[prestashop]]: CONOCIDA — 8 gotchas documentados en producción
→ [[holded]]:     CONOCIDA — 6 gotchas documentados en producción

PATRONES APLICABLES A ESTE TIPO DE INTEGRACIÓN
→ [[handler-structure]]      — siempre aplicable a integraciones Lambda
→ [[idempotencia-dynamodb]]  — si hay paralelismo o Step Functions
→ [[degradacion-silenciosa]] — si hay features opcionales por tier
→ [[patron-3-tiers]]         — si el cliente tiene modelo de precios por funcionalidad

ERRORES DOCUMENTADOS — ALTA PROBABILIDAD DE REPETICIÓN
→ [[e3-order-rows-tres-formatos]] — PrestaShop devuelve 3 formatos de order_rows
  Estado: [confirmado en producción]. Solución documentada: normalizarOrderRows()
→ [[e4-caracteres-invisibles]] — U+200E en strings de PrestaShop
  Estado: [confirmado en producción]. Solución documentada: cleanStr()
→ [[e1-object-object-nombres]] — nombres multi-idioma como objetos, no strings
  Estado: [confirmado en producción]. Solución documentada: extraerNombre()
→ [[e2-race-condition-facturas-duplicadas]] — si hay ejecuciones paralelas
  Estado: [confirmado en producción]. Solución documentada: ConditionalExpression

COSTE HISTÓRICO COMPARABLE
→ [[prestashop-holded-prod]]: $0.00–$0.82/mes (~30 pedidos/día, eu-west-2)
  Coste dominante: Secrets Manager ($0.40/secreto/mes), no Lambda
  FinOps puede usar como baseline de referencia

CONTEXTO PARA RESEARCH
Research puede partir con PrestaShop y Holded ya documentados.
Puede omitir investigar autenticación, endpoints del happy path y gotchas conocidos.
Solo necesita verificar si la versión del cliente tiene cambios respecto a la documentada,
y resolver unknowns específicos de este proyecto.

ADRs PREVIOS RELEVANTES
→ ADR-3: Lambda URL AuthType: NONE (no AWS_IAM) — bug CloudFront OAC+SigV4
→ ADR-4: Serverless Framework v3.38.0 — v4 incompatible con plugins
→ ADR-8: panelRouter siempre desplegado, URL solo en Pro/Pro+

────────────────────────────────────────────────────────────────
Tokens estimados ahorrados: ~{N} (Research no redescubre lo ya documentado)
```

**Si las plataformas no están en la vault:**

```
SCRIBE — AUDITORÍA PRE-PROYECTO
────────────────────────────────────────────────────────────────

Plataformas: {NuevaPlataforma} — NO en la vault

Research arranca en blanco para esta plataforma.
Aplicar patrones generales del ecosistema:
→ [[handler-structure]] — siempre
→ [[idempotencia-dynamodb]] — si hay paralelismo

Todo lo que Research documente de {NuevaPlataforma}
se añadirá a la vault al finalizar este proyecto.
────────────────────────────────────────────────────────────────
```

---

## SINTAXIS OBSIDIAN — OBLIGATORIA EN CADA NODO

```markdown
---
tags: [tipo, plataforma, estado]   ← YAML frontmatter, siempre
created: YYYY-MM-DD
proyecto: nombre-del-proyecto
---

# Título del nodo

#tag1 #tag2 #tag3               ← tags repetidos en cuerpo para búsqueda en Obsidian

[[nodo-relacionado-1]]          ← mínimo 2 enlaces internos por nodo
[[nodo-relacionado-2]]
```

**Tipos de tags de primer nivel:**
- `proyecto` — ficheros de proyecto
- `patron` — patrones de código o arquitectura
- `error` — errores resueltos
- `plataforma` — perfiles de plataforma
- `coste` — históricos de coste
- `dev-log` — registros en tiempo real

**Regla del enlace mínimo:**
Un nodo sin enlaces a otros nodos no aporta a la red de conocimiento.
Obsidian es una red, no una lista.
Antes de guardar cualquier nodo, verificar: ¿enlaza a mínimo 2 nodos existentes?

**Cómo nombrar los ficheros:**
```
kebab-case.md                    ← siempre
e7-nuevo-error.md                ← errores con ID incremental (e1-e6 ya usados)
nueva-plataforma-shopify.md      ← plataformas con nombre descriptivo
shopify-prestashop-prod.md       ← proyectos con formato origen-destino-env
```

---

*Extraído de agents/08_agent_scribe.md §3 + §5 — 2026-05-25*
*Ver agente reducido en [[08_agent_scribe]] tras refactorización COMMIT 4*
