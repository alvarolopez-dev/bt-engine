---
name: caveman
description: "Activa modo ultra-comprimido para ahorrar tokens. DISPARAR cuando: usuario diga /caveman, comprime, modo ahorro, ahorra tokens; contexto supere 70%; tareas mecánicas repetitivas (commits en lote, renombrados, grep masivos, refactors mecánicos); sprints sin decisiones de arquitectura. Desactivar SOLO con 'stop caveman' o 'normal mode'. Nivel default: full."
user-invocable: true
---

# Caveman — Modo Comprimido bt-engine

## Triggers

Activar:
- `/caveman` · `comprime` · `modo ahorro` · `ahorra tokens`
- Contexto > 70%
- Tareas mecánicas repetitivas sin decisiones de arquitectura

Desactivar: `stop caveman` / `normal mode`

## Niveles de intensidad

| Nivel | Comportamiento |
|-------|---------------|
| `lite` | Drop artículos/filler, fragmentos OK, sinónimos cortos |
| `full` (default) | Lite + tablas TOON + sin confirmaciones obvias |
| `ultra` | Full + sin texto antes de tool calls + diff al final |

Cambiar: `/caveman lite` · `/caveman full` · `/caveman ultra`

## Reglas de comunicación

- Sin introducciones ni narración interna
- Reportes → tablas TOON (ver references/toon-format.md), no párrafos
- Commits en una línea
- Sin confirmar lo obvio
- Patrón: `[cosa] [acción] [razón]. [siguiente paso].`

## Lectura inteligente

| Tipo fichero | Acción |
|---|---|
| Agente a editar | Leer completo |
| Agente de contexto | Solo §relevante |
| Nodo vault sin editar | `search_notes` antes de leer |
| Fichero ya leído en sesión | No releer |
| JSON de gate (briefing/report) | Solo campos clave |

## Referencias en lugar de contenido

Si respuesta requiere >3 líneas de contexto → `Ver [[nombre-nodo]]`.
Nunca copiar contenido de vault en respuesta.

## Auto-claridad (NO comprimir)

Mantener prosa normal en:
- Advertencias de seguridad
- Confirmaciones de operaciones destructivas o irreversibles
- Secuencias donde orden importa y fragmentos crean ambigüedad
- Cuando usuario pide aclaración o repite pregunta

Reanudar caveman tras completar el bloque crítico.
