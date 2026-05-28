---
name: constraints
description: "Contexto silencioso con reglas universales bt-engine. Cargar automáticamente al inicio de cualquier tarea técnica — código, deploy, testing, diseño de arquitectura. No requiere invocación explícita del usuario."
user-invocable: false
---

# Constraints — Reglas Universales bt-engine

Fuente autoritativa: `agents/00_CONSTRAINTS.md`
Leer completo antes de cualquier tarea técnica.

## Stack fijo (no negociable)

| Componente | Valor | Prohibido |
|---|---|---|
| Runtime | `nodejs22.x` | `nodejs20.x` (deprecado AWS) |
| Trigger | Lambda Function URL (`AuthType: NONE`) | API Gateway |
| IaC | Serverless Framework v3 | CDK, SAM, Terraform |
| Lenguaje | TypeScript `strict: true` | JS puro, `any` sin guard |
| BD | DynamoDB | RDS, Aurora, Mongo |
| Logs | `pino` + `pino-lambda` | `console.log` directo |
| Secrets | Secrets Manager (prod) / `.env` (local) | Hardcoded |

## Reglas de código críticas

- **R-CODE-2** Handler: A=cargarSecretos → B=guard → C=lógica → D=retorno tipado
- **R-CODE-3** Singletons (DynamoDB, SecretsManager, pino) a nivel módulo, nunca dentro del handler
- **R-CODE-5** `catch (error: unknown)` siempre — nunca `catch (error: any)`
- **R-CODE-7** Idempotencia obligatoria — ConditionalCheck DynamoDB antes de procesar

## Reglas de seguridad críticas

- **R-SEC-1** Validar firma webhook ANTES de procesar — sin excepción
- **R-SEC-2** Raw body como Buffer ANTES de JSON.parse para HMAC
- **R-SEC-3** `crypto.timingSafeEqual` para comparar tokens — nunca `===`
- **R-SEC-6** PII nunca en CloudWatch (emails, CIFs, IBANs, teléfonos)

## Pipeline (orden estricto)

```
INTAKE → (RESEARCH ∥ FINOPS) → DEVELOPER → (QA ∥ SECURITY) → ORCHESTRATOR → DEVOPS
```

Gates bloqueantes — no saltar: GATE-0 a GATE-5.
Ver `agents/00_CONSTRAINTS.md §3` para reglas completas.

## MCP Obsidian vault

Disponible en `localhost:22360`.
Vault antes que filesystem: `search_notes` antes de `ls`/`find`.
`patch_note` para cambios parciales — nunca `write_note` en nodo existente.

## Regla de pesadez

Si hay dudas → preguntar. Si la pregunta es obvia → preguntar igual.
Un agente que asume cuesta más tokens que uno que pregunta cinco veces.
