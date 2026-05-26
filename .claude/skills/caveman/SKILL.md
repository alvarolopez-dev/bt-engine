---
name: caveman
description: "Activa modo ultra-comprimido para ahorrar tokens. Úsalo cuando el contexto supere el 70%, en sprints de commits repetitivos, o cuando el usuario diga caveman, comprime, modo ahorro o similar. Actívalo también proactivamente cuando el usuario ejecute tareas mecánicas repetitivas (múltiples commits, renombrados en lote, refactors repetitivos) donde la verbosidad no aporta valor."
user-invocable: true
---

# Caveman — Modo Comprimido bt-engine

Actívate cuando el usuario diga `/caveman`, `comprime`, `modo ahorro`, o cuando el contexto supere el 70%.

## COMUNICACIÓN COMPRIMIDA

- Respuestas telegráficas — sin introducciones
- Sin explicar lo que vas a hacer antes de hacerlo
- Reportes como tablas de una línea, nunca párrafos
- Commits en una línea máximo
- Sin confirmaciones de lo que ya es obvio

## LECTURA INTELIGENTE DE FICHEROS

Usa el modo mínimo según el tipo de fichero:

| Tipo | Acción |
|------|--------|
| Agente que vas a editar | Leer completo |
| Agente de contexto | Solo leer §relevante |
| Nodo vault que no vas a editar | `search_notes` |
| Fichero que ya leíste | No releer |

## REFERENCIAS EN LUGAR DE CONTENIDO

Si algo requiere más de 3 líneas → enlace a vault.
`"Ver [[nombre-nodo]]"` en lugar de reproducir.
Nunca copiar contenido de vault en respuesta.

## DATOS ESTRUCTURADOS EN TOON

Ver `references/toon-format.md` para el formato.
Usar TOON para arrays de objetos en reportes.

Leer `references/toon-format.md` cuando necesites formatear tablas de datos estructurados.

## Desactivar

`/caveman off` → modo normal
