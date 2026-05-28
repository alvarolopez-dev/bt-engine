---
name: diagnose
description: "Diagnostica bugs y problemas sin escribir código. DISPARAR cuando: usuario reporte error, bug, fallo en producción, comportamiento inesperado; diga algo no funciona, tengo un fallo, está roto, está fallando, no llega el webhook, Lambda no responde, DynamoDB devuelve X en lugar de Y. Activar también si el usuario menciona CloudWatch con errores o describe síntomas sin causa conocida."
user-invocable: true
args: "$ARGUMENTS = descripción del problema"
---

# Diagnose — Diagnóstico sin Código

**Regla absoluta: no modificar código durante diagnóstico. Solo analizar y reportar.**

## PASO 1 — Vault primero

```
search_notes("[términos del problema] [plataforma]")
```

Buscar en:
- `dev-log/knowledge-base/errors/` — E1-E6 documentados
- `dev-log/knowledge-base/platforms/[plataforma]` — gotchas
- `dev-log/knowledge-base/patterns/` — patrones estructurales

Si error coincide con E1-E6 → reportar inmediatamente sin leer código.

## PASO 2 — Leer solo ficheros relevantes

No escanear todo el proyecto.
Solo ficheros nombrados en la descripción o señalados por vault.
Máximo 3 ficheros sin confirmación adicional del usuario.

## PASO 3 — Hipótesis ordenadas por probabilidad

Prioridad:
1. Errores E1-E6 documentados (mayor peso — ya ocurrieron en producción)
2. Gotchas de plataformas involucradas
3. Violaciones de constraints (R-CODE-1 a R-SEC-8)
4. Patrones estructurales (singleton fuera del handler, raw body, timing attack, etc.)

## PASO 4 — Reporte TOON

```
[N]{hipótesis,probabilidad,ubicación,fix}:
raw body parseado antes de HMAC,alta,src/handlers/webhook.ts:23,preservar Buffer antes de JSON.parse
timingSafeEqual no usado,media,src/utils/auth.ts:45,reemplazar === por crypto.timingSafeEqual
```

## Si causa raíz no determinable

Listar explícitamente qué se necesita:
- Logs CloudWatch del periodo del fallo
- Payload exacto del webhook
- Estado DynamoDB en momento del error
- Variables de entorno activas

No inventar hipótesis sin base. No modificar nada hasta que usuario confirme causa.
