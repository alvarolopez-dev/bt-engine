---
name: research
description: "Investiga una plataforma o API nueva y añade su perfil completo a la vault de conocimiento. Úsalo cuando el usuario mencione una plataforma no documentada, pida investigar una API, necesite el perfil de autenticación de un servicio, o diga investiga X, documenta X, o añade X a la vault."
user-invocable: true
args: "$ARGUMENTS = nombre de plataforma"
---

# Research — Investigación de Plataformas

Actívate con `/research [plataforma]`, "investiga X", "documenta X", "añade X a la vault", o cuando el usuario mencione una plataforma no documentada.

## PASO 1 — Verificar vault primero

```
search_notes con nombre de plataforma
```

Si existe y está actualizado:
→ Reportar qué hay y preguntar explícitamente si actualizar.
Si existe pero desactualizado:
→ Identificar qué secciones necesitan actualización.
Si no existe:
→ Continuar con PASO 2.

## PASO 2 — Pedir URL oficial

Pedir al usuario la URL de la API reference oficial.
**No buscar sin URL confirmada.**
El perfil marcado como `[inferido]` sin URL oficial es válido pero se marca explícitamente.

## PASO 3 — Cargar agente Research

Cargar `agents/03_agent_research.md`.
Ejecutar protocolo completo de investigación.

## PASO 4 — Construir API_PROFILE completo

Ver `[[api-profile-template]]` en vault (`dev-log/knowledge-base/agent-details/api-profile-template.md`).

Marcar cada dato con su fuente:
- `[oficial]` — de la documentación oficial
- `[comunidad]` — de foros, GitHub issues, Stack Overflow
- `[inferido]` — deducido del comportamiento

Campos mínimos del perfil:
- Autenticación (tipo, headers, tokens, renovación)
- Rate limits (por endpoint si difieren)
- Webhook signature (si aplica)
- Gotchas conocidos
- Cambios breaking documentados

## PASO 5 — Escribir en vault

```
write_note en dev-log/knowledge-base/platforms/{nombre}.md
```

Frontmatter YAML requerido:
```yaml
---
tags: [platform, {nombre}, api-profile]
created: {fecha}
status: draft|reviewed
---
```

## PASO 6 — Actualizar índice

```
patch_note en dev-log/index.md
```

Añadir entrada en la sección `platforms/`.

## PASO 7 — Commit

```
knowledge: {plataforma} — perfil inicial
```

Si es actualización:
```
knowledge: {plataforma} — actualizar {sección}
```
