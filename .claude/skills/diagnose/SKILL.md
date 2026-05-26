---
name: diagnose
description: "Diagnostica bugs y problemas en proyectos existentes sin escribir código. Úsalo cuando el usuario reporte un error, bug, fallo en producción, o comportamiento inesperado. Actívalo también cuando el usuario diga algo no funciona, tengo un fallo, está roto, o describa un comportamiento anómalo en un Lambda, webhook, o integración."
user-invocable: true
args: "$ARGUMENTS = descripción del problema"
---

# Diagnose — Diagnóstico sin Código

Actívate con `/diagnose [descripción]`, "algo no funciona", "tengo un bug", "está fallando", o cuando el usuario describa comportamiento inesperado en producción.

**Regla principal: no modificar código durante el diagnóstico. Solo analizar y reportar.**

## PASO 1 — Buscar en vault primero

```
search_notes con términos del problema
```

Buscar específicamente:
- Errores E1-E6 documentados en `dev-log/knowledge-base/errors/`
- Gotchas de las plataformas involucradas (`dev-log/knowledge-base/platforms/`)
- Patrones que pueden fallar (`dev-log/knowledge-base/patterns/`)

## PASO 2 — Leer solo ficheros relevantes

No escanear todo el proyecto.
Solo lo que el problema sugiere directamente.
Priorizar ficheros nombrados en la descripción o en los errores del vault.

## PASO 3 — Construir hipótesis

Ordenar por probabilidad basándose en:
1. Errores documentados E1-E6 (mayor peso — ya ocurrieron)
2. Gotchas de plataformas involucradas
3. Violaciones de constraints conocidos (R-CODE-1 a R-CODE-7)
4. Patrones estructurales (singleton fuera del handler, raw body, etc.)

## PASO 4 — Reportar en formato TOON

```
[N]{hipótesis|probabilidad|fichero:línea|fix}:
[hipótesis 1],[alta|media|baja],[ruta:línea],[descripción del fix]
```

Ejemplo:
```
[2]{hipótesis|probabilidad|ubicación|fix}:
raw body parseado antes de HMAC,alta,src/handlers/webhook.ts:23,preservar Buffer antes de JSON.parse
timingSafeEqual no usado,media,src/utils/auth.ts:45,reemplazar === por crypto.timingSafeEqual
```

## Si la causa raíz no es determinable

Listar explícitamente qué información adicional se necesita:
- Logs de CloudWatch del periodo del fallo
- Payload exacto del webhook
- Estado de DynamoDB en el momento del error
- Variables de entorno activas

No inventar hipótesis sin base. No modificar nada hasta que el usuario confirme la causa.
