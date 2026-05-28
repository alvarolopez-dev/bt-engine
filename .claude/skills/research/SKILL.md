---
name: research
description: "Investiga una plataforma o API nueva y añade su perfil a la vault. DISPARAR cuando: usuario mencione plataforma no documentada, pida investigar una API, diga investiga X, documenta X, añade X a la vault, necesito el perfil de X, qué endpoints tiene X. Activar también si el usuario empieza a describir una integración y la plataforma no está en dev-log/knowledge-base/platforms/."
user-invocable: true
args: "$ARGUMENTS = nombre de plataforma"
---

# Research — Investigación de Plataformas

## PASO 1 — Vault primero

```
search_notes("[nombre plataforma]")
```

| Resultado | Acción |
|-----------|--------|
| Perfil completo existe | Reportar qué hay, preguntar si actualizar |
| Perfil parcial | Identificar secciones faltantes, completar solo esas |
| No existe | Continuar con PASO 2 |

## PASO 2 — Pedir URL oficial

Pedir al usuario la URL de la API reference oficial.
No buscar sin URL confirmada.
Perfil sin URL oficial: marcar cada dato como `[inferido]`.

## PASO 3 — Cargar agente Research

Cargar `agents/03_agent_research.md`.
Ejecutar protocolo completo de investigación.

## PASO 4 — Construir API_PROFILE completo

Ver `[[api-profile-template]]` en `dev-log/knowledge-base/agent-details/api-profile-template.md`.

Marcar fuente de cada dato:
- `[oficial]` — documentación oficial
- `[comunidad]` — foros, GitHub issues, Stack Overflow
- `[inferido]` — deducido del comportamiento

Campos mínimos requeridos:
- Autenticación (tipo, headers, tokens, renovación)
- Rate limits (por endpoint si difieren)
- Webhook signature (si aplica)
- Gotchas conocidos
- Cambios breaking documentados

## PASO 5 — Escribir en vault

```
write_note → dev-log/knowledge-base/platforms/{nombre}.md
```

Frontmatter requerido:
```yaml
---
tags: [platform, {nombre}, api-profile]
created: {fecha}
status: draft
---
```

## PASO 6 — Actualizar índice

```
patch_note → dev-log/index.md
```

Añadir entrada en sección `platforms/`.

## PASO 7 — Commit

```
knowledge: {plataforma} — perfil inicial
```

Si actualización:
```
knowledge: {plataforma} — actualizar {sección}
```
