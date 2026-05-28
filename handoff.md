> Autor: Álvaro López
> Proyecto iniciado: mayo 2026

# HANDOFF — bt-engine / Bigtoone Agent Stack
<!-- Actualizado: 2026-05-28. Para recuperar contexto tras clear o pérdida de sesión. -->

## Estado actual — rama main, sin cambios pendientes

```
último commit: 3ce10a8  feat(skills): 7 skills Bigtoone construidas — descriptions pushier + constraints nueva
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

### Mejoras clave vs stubs previos

- Todas las descriptions usan patrón DISPARAR — triggers explícitos, proactivos
- `caveman`: niveles lite/full/ultra documentados; sección auto-claridad
- `toon-format.md`: ejemplos intake_briefing + api_profile + finops_report con campos reales del pipeline
- `new-integration`: TOON status por gate; Research ∥ FinOps paralelo explícito
- `diagnose`: cortocircuito E1-E6, límite 3 ficheros, paths vault explícitos
- `security-audit`: 7 capas en tabla; trigger proactivo pre-DevOps sin security_report
- `cost-check`: trigger proactivo si intake sin finops; datos mínimos antes de calcular
- `constraints`: skill silenciosa nueva — stack, R-CODE, R-SEC, pipeline, MCP vault

### Otros ficheros del proyecto

```
.agents/skills/bash-defensive-patterns/SKILL.md   — skill project-level
.claude/skills/bash-defensive-patterns             — symlink → .agents/skills/...
.claude/settings.local.json                        — permisos ampliados (WebFetch, git, npm, mcp)
skills-lock.json                                   — hash verificación bash-defensive-patterns
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

## BLOQUES PENDIENTES

### BLOQUE 2 — AWS documentación oficial
Objetivo: references específicas de AWS para Lambda + DynamoDB + SF v3 en dev-log/knowledge-base/aws/

### BLOQUE 3 — TypeScript avanzado para Lambda
Objetivo: patterns avanzados — zod validation en handlers, middleware pattern, error taxonomy bt-engine

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
2. **nodejs20.x es el runtime correcto con SF v3** — nodejs22.x no está soportado por Serverless Framework v3 en validación local. Si se necesita nodejs22.x, requiere migrar a SF v4 o CDK. La sesión de 2026-05-26 invirtió esto por error.
3. **catch siempre `error: unknown`** — nunca `error: any`. Ver R-CODE-5 en 00_CONSTRAINTS.md.
4. **Singletons a nivel de módulo** — DynamoDB, SecretsManager, pino fuera del handler. Ver R-CODE-3.
5. **Idempotencia obligatoria** — ConditionalCheck DynamoDB antes de procesar cualquier webhook. Ver R-CODE-7.
6. **TOON solo para Claude→Claude** — nunca para payloads a APIs externas (Revo/Holded/Zoho).
7. **`agamm/claude-code-owasp`** — el SKILL.md está en `.claude/skills/owasp-security/SKILL.md`, no en raíz.
8. **settings.json sin `CLAUDE_CODE_DISABLE_1M_CONTEXT`** — decisión deliberada, no un olvido.
9. **constraints/SKILL.md es silenciosa** — `user-invocable: false`, se carga automáticamente, no con `/constraints`.
