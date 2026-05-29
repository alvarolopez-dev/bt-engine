> Autor: Álvaro López
> Proyecto iniciado: mayo 2026

# HANDOFF — bt-engine / Bigtoone Agent Stack
<!-- Actualizado: 2026-05-29. Para recuperar contexto tras clear o pérdida de sesión. -->

## Estado actual — rama main, sin cambios pendientes

```
último commit: 6945848  fix: setup.sh + setup.ps1 — URL repo, Node 20+, plugin Obsidian, MANUAL.md, aws/ folder, warn corregido
tag: v1.3.1
```

---

## BLOQUE 1 — COMPLETADO (2026-05-25/26)

Objetivo: instalar skills reutilizables para el ecosistema bt-engine.

### Skills globales instaladas en `~/.claude/skills/`

| Skill | Origen | Trigger descripción |
|-------|--------|---------------------|
| `tokenwise/ab` | JuliusBrussee/tokenwise | A/B test mismo task en Haiku vs Sonnet vs Opus |
| `tokenwise/install` | JuliusBrussee/tokenwise | Instala routing rules en CLAUDE.md + settings.json |
| `tokenwise/report` | JuliusBrussee/tokenwise | Reporte sesión actual — tokens, $ ahorrado vs baseline Opus |
| `tokenwise/summary` | JuliusBrussee/tokenwise | Tendencias multi-sesión (--week/--month/--all) |
| `tokenwise/undo` | JuliusBrussee/tokenwise | Restaura backups .tokenwise-backup-* |
| `skill-creator` | anthropics/skills | Crear/mejorar/evaluar skills desde cero |
| `security-audit/references/owasp-2025.md` | agamm/claude-code-owasp | Solo references — checklists OWASP Top10/LLM/Agentic |
| `caveman/references/toon-format.md` | Construido ad-hoc | TOON lite con ejemplos bt-engine |
| `typescript-strict` | Construido desde cero | TypeScript strict:true para Lambda nodejs20.x |
| `serverless-deploy` | Construido desde cero | SF v3, nodejs20.x, Lambda Function URL, DynamoDB |

### Ficheros globales modificados

```
~/.claude/CLAUDE.md          — bloque TokenWise añadido (líneas 7-39, markers BEGIN/END)
~/.claude/settings.json      — env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80 añadido
~/.claude/CLAUDE.md.backup   — backup pre-tokenwise
~/.claude/settings.json.backup — backup pre-tokenwise
```

**settings.json NO tiene** `CLAUDE_CODE_DISABLE_1M_CONTEXT` — decisión explícita del usuario (demasiado agresivo globalmente).

---

## BLOQUE 1b — COMPLETADO (2026-05-26/28)

Objetivo: 7 skills propias de Bigtoone en `.claude/skills/` del proyecto.

### Skills de proyecto en `.claude/skills/`

| Skill | Fichero | References | user-invocable | Commit |
|-------|---------|------------|----------------|--------|
| `/caveman` | caveman/SKILL.md | toon-format.md | true | 3ce10a8 |
| `/new-integration` | new-integration/SKILL.md | — | true | 3ce10a8 |
| `/diagnose` | diagnose/SKILL.md | — | true | 3ce10a8 |
| `/research` | research/SKILL.md | — | true | 3ce10a8 |
| `/security-audit` | security-audit/SKILL.md | owasp-2025.md | true | 3ce10a8 |
| `/cost-check` | cost-check/SKILL.md | — | true | 3ce10a8 |
| `constraints` | constraints/SKILL.md | — | false (silenciosa) | 3ce10a8 |

### Otros ficheros del proyecto

```
.agents/skills/bash-defensive-patterns/SKILL.md   — skill project-level
.claude/skills/bash-defensive-patterns             — symlink → .agents/skills/...
.claude/settings.local.json                        — permisos ampliados (WebFetch, git, npm, mcp)
skills-lock.json                                   — hash verificación bash-defensive-patterns
```

---

## SESIÓN 2026-05-28/29 — COMPLETADA

Objetivo: auditoría completa + fixes + Lambda A test + documentación final.

### Lambda A — revo-holded-test (NUEVO)

Directorio: `/Users/alvarolopez/CEROONE/PROYECTOS/revo-holded-test/`

| Fichero | Contenido |
|---------|-----------|
| `src/handlers/webhook_receiver.ts` | Lambda A — x-www-form-urlencoded, HMAC SHA256, SQS enqueue |
| `src/types/revo_webhook.ts` | Tipos TypeScript: RevoOrderClosedPayload, SqsOrderMessage, HandlerResponse |
| `package.json` | pino, pino-lambda@^4.4.1, qs, @aws-sdk/client-sqs |
| `tsconfig.json` | strict:true, target ES2020 |
| `serverless.yml` | SF v3, nodejs20.x, Function URL, SQS trigger Lambda B |
| `.env.example` | REVO_WEBHOOK_SECRET, SQS_QUEUE_URL |
| `dev-log/knowledge-base/errors/nodejs-runtime-sf-v3.md` | Error node: nodejs20.x vs nodejs22.x |

Patrón clave Lambda A:
- Raw `Buffer` antes de `qs.parse()` — integridad HMAC garantizada
- `crypto.timingSafeEqual` para comparar firmas
- Respuesta 200 < 1s → SQS enqueue async (límite hard Revo: 5s × 5 timeouts = webhook desactivado)

### Auditoría + fixes (commits 62ce6d9 → 6945848)

| Commit | Fix |
|--------|-----|
| `1bfc73d` | obsidian-vault MCP path — ruta absoluta dinámica en setup.sh |
| `62ce6d9` | .gitignore — proteger JSONs runtime + secretos |
| `db85fdc` | vault cleanup — agente duplicado + canvas sin nombre |
| `a6252e0` | eliminar legacy `Agentes Bigtone/` (typo, Obsidian default) |
| `63c5459` | nodejs20.x correcto en todo el ecosistema |
| `dbf47dc` | autoría Álvaro López en 6 ficheros + AUTHORS.md |
| `6945848` | setup.sh + setup.ps1 — 5+4 fixes (URL, Node 20+, MANUAL.md, aws/, Obsidian plugin) |

### Documentación nueva/reescrita

```
agents/MANUAL.md        — guía completa de uso (11 plataformas, 9 agentes, FAQ)
README.md               — 1 página entry point (reescrito desde cero)
AUTHORS.md              — autoría: Álvaro López, stack, período
```

---

## Stack bt-engine — constraints absolutos

| Componente | Valor fijo | Prohibido |
|---|---|---|
| Runtime | `nodejs20.x` | `nodejs22.x` (SF v3 no soporta — requiere SF v4 o CDK) |
| Trigger | Lambda Function URL (`url: true`) | API Gateway |
| IaC | Serverless Framework v3 | CDK, SAM, Terraform |
| Lenguaje | TypeScript `strict: true` | JavaScript puro, `any` sin guard |
| Logs | `pino` + `pino-lambda` | `console.log` directo |
| BD | DynamoDB | RDS, Aurora, Mongo |
| Secrets | Secrets Manager (prod) / `.env` (local) | Hardcoded |

Pipeline: `INTAKE → (RESEARCH ∥ FINOPS) → DEVELOPER → (QA ∥ FINOPS ∥ SECURITY) → ORCHESTRATOR → DEVOPS`

Handler anatomy fija (R-CODE-2): A=cargarSecretos → B=guard defensivo → C=lógica → D=retorno tipado

---

## BLOQUE 2 — COMPLETADO (2026-05-29)

Objetivo: vault aws/ + agent-details/ completa y sin violaciones de constraints.

### Fase A — fixes vault aws/ (commit 231dad0)
- `nodejs22.x` → `nodejs20.x` en `serverless-framework-v3.md` + `architecture-decision-tree.md` (×2)
- `error: any` → `error: unknown` + msg guard en `lambda-patterns.md` (P1, P3, P7) + `dynamodb-patterns.md` (Regla 3)
- `00_TREE.md`: P1-P14 → P1-P18

### Fase B — agent-details/ (ya existían, fixes + markers)
- 6 ficheros en `dev-log/knowledge-base/agent-details/` — contenido real, no stubs
- `developer-style.md` + `plan-template.md`: `nodejs22.x` → `nodejs20.x`
- `00_TREE.md`: markers "(pendiente)" → descripciones reales

---

## BLOQUE 3 — COMPLETADO (2026-05-29)

Objetivo: patterns avanzados TypeScript para Lambda — 3 ficheros nuevos en `dev-log/knowledge-base/patterns/`.

| Fichero | Contenido |
|---------|-----------|
| `zod-validation.md` | Schema definition, `z.infer<>`, safeParse vs parse, passthrough, coerción form-data, error format pino, anti-patrones |
| `middleware-lambda.md` | Compose pattern sin deps, withSecrets/withRawBody/withHmacRevo/withFormBody, orden fijo de middlewares, tests por separado |
| `error-taxonomy.md` | `BtEngineError` base + 5 subclases (Config/Validation/ExternalApi/Duplicate/WebhookAuth), instanceof guards, pino serializer |

`00_TREE.md` actualizado con los 3 nuevos nodos.

---

## BLOQUES PENDIENTES

Todos los bloques planificados completados. Vault de conocimiento completa.
Próximas sesiones: implementación de proyectos usando el ecosistema (BLOQUE 4 libre).

---

## Cómo retomar

```bash
cd "/Users/alvarolopez/CEROONE/PROYECTOS/AGENTE BIGTOONE"
git log --oneline -3     # verificar estado
cat agents/00_CONSTRAINTS.md   # constraints universales
cat agents/00_TREE.md          # árbol del ecosistema
```

Luego decir: `"Listo para BLOQUE 2 — AWS docs"` o `"Listo para BLOQUE 3 — TypeScript avanzado"`

---

## Gotchas documentados

1. **client_token Revo obligatorio en Intake** — campo requerido, no opcional. Ver commit `fa300f6`.
2. **nodejs20.x es el runtime correcto con SF v3** — nodejs22.x no está soportado por Serverless Framework v3 en validación local. Si se necesita nodejs22.x, requiere migrar a SF v4 o CDK. La sesión de 2026-05-26 invirtió esto por error. Ver vault: `dev-log/knowledge-base/errors/nodejs-runtime-sf-v3.md`.
3. **catch siempre `error: unknown`** — nunca `error: any`. Ver R-CODE-5 en 00_CONSTRAINTS.md.
4. **Singletons a nivel de módulo** — DynamoDB, SecretsManager, pino fuera del handler. Ver R-CODE-3.
5. **Idempotencia obligatoria** — ConditionalCheck DynamoDB antes de procesar cualquier webhook. Ver R-CODE-7.
6. **TOON solo para Claude→Claude** — nunca para payloads a APIs externas (Revo/Holded/Zoho).
7. **`agamm/claude-code-owasp`** — el SKILL.md está en `.claude/skills/owasp-security/SKILL.md`, no en raíz.
8. **settings.json sin `CLAUDE_CODE_DISABLE_1M_CONTEXT`** — decisión deliberada, no un olvido.
9. **constraints/SKILL.md es silenciosa** — `user-invocable: false`, se carga automáticamente, no con `/constraints`.
10. **obsidian-vault MCP config en `~/.claude.json`** — almacenado por proyecto, NO en el repo. Requiere reinicio de sesión de Claude Code tras cambiar el path. setup.sh calcula ruta absoluta en runtime con `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dev-log` para evitar placeholder roto.
11. **pino-lambda@^5.0.0 no existe** — versión 5.x no publicada en npm. Usar siempre `^4.4.1`.
12. **Lambda A Revo: responder < 1s** — Revo desactiva el webhook tras 5 timeouts de 5s. Patrón correcto: 200 inmediato + SQS enqueue; Lambda B procesa async.
13. **optimization-report.md en dev-log/ raíz** — fichero intencional (no figura en 00_TREE.md — es meta-doc del ecosistema, no knowledge-base).
