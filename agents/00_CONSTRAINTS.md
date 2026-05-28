---
tags: [constraints, stack, pipeline, security, mcp]
created: 2026-05-25
applies-to: todos los agentes del ecosistema
---

# Bigtoone Agent Ecosystem — Constraints
> Diseñado por Álvaro López · 2026

# 00 — CONSTRAINTS UNIVERSALES

> **INSTRUCCIÓN OBLIGATORIA**
> Este fichero se lee ANTES de cualquier tarea.
> Todos los constraints aquí son absolutos.
> No hay excepciones. No hay urgencias que los anulen.

---

## 1. STACK FIJO — NO NEGOCIABLE

### Infraestructura

| Componente | Valor fijo | Prohibido |
|---|---|---|
| Compute | AWS Lambda | EC2, ECS, contenedores |
| Trigger público | Lambda Function URL (`AuthType: NONE`) | API Gateway |
| IaC | Serverless Framework v3 / AWS CDK | SAM, Terraform (salvo ADR explícita) |
| Runtime | `nodejs20.x` | `nodejs22.x` (SF v3 no soporta — requiere SF v4 o CDK) |
| Lenguaje | TypeScript con `strict: true` | JavaScript puro, `any` sin guard |
| Secrets | AWS Secrets Manager (prod) / `.env` (local) | Hardcoded en código o serverless.yml |
| Base de datos | DynamoDB | RDS, Aurora, Mongo (salvo ADR explícita) |
| Logs | `pino` con `pino-lambda` | `console.log` directo |

### SaaS de referencia

```
Google Workspace · Zoho One · Holded · Hubstaff · 3CX · Make
```

Si algo no está en Hubstaff o Zoho, no existe a efectos de tracking.

---

## 2. REGLAS DE CÓDIGO

**R-CODE-1 — Un Lambda, una responsabilidad.**
Si un Lambda hace dos cosas → el Orquestador lo divide. Sin excepción.

**R-CODE-2 — Anatomía de handler — orden fijo:**
```
A. cargarSecretos()     → siempre primero, singleton (no repite en warm)
B. Guard defensivo      → salir rápido si no hay trabajo
C. Lógica principal     → errores por ítem, nunca propagar al batch
D. Retorno tipado       → nunca void implícito
```

**R-CODE-3 — Clientes y singletons fuera del handler.**
Nivel de módulo = se crean una sola vez. Dentro del handler = coste por invocación.

**R-CODE-4 — strict: true es inegociable.**
Si el proyecto tiene `strict: false` → migrar fichero a fichero ANTES de añadir código.
Un fichero por tarea. El Orquestador trackea el progreso.

**R-CODE-5 — Catch siempre tipado.**
```typescript
// ❌ NUNCA
} catch (error: any) { ... }

// ✅ SIEMPRE
} catch (error: unknown) {
  const msg = error instanceof Error ? error.message : String(error);
}
```

**R-CODE-6 — Comentarios obligatorios.**
El qué está en el código. El por qué está en el comentario.
Código sin comentario que explique el porqué → no está terminado.

**R-CODE-7 — Idempotencia obligatoria en todos los handlers.**
Todos los webhooks/eventos pueden llegar duplicados.
ConditionalCheck DynamoDB antes de procesar. Ver `[[idempotencia-dynamodb]]`.

---

## 3. REGLAS DE PIPELINE

### Secuencia de gates — NO alterar orden

```
INTAKE → (RESEARCH ∥ FINOPS) → DEVELOPER → (QA ∥ FINOPS ∥ SECURITY) → ORCHESTRATOR → DEVOPS
```

**R-PIPE-1 — Sin intake_briefing.json = pipeline paralizado.**
Ningún agente técnico actúa antes de que Intake entregue briefing con `confidence_level >= medium`.

**R-PIPE-2 — Sin API_PROFILE = sin código.**
Developer no escribe una línea sin el perfil completo de cada plataforma que va a usar.

**R-PIPE-3 — Sin finops_report.json approved = sin código.**
FinOps bloquea → pipeline para. No se escala al Developer.

**R-PIPE-4 — Sin security_report.json ready_for_devops: true = DevOps no actúa.**
Security es gate paralelo a QA y FinOps. Los tres deben pasar.

**R-PIPE-5 — Sin deploy_decision explícita del Orquestador = DevOps no actúa.**
No se despliega por defecto. El Orquestador toma la decisión conscientemente.

**R-PIPE-6 — blocked_on detiene el agente, no lo salta.**
Cualquier agente que encuentra `blocked_on` reporta al Orquestador y espera.
No improvisa. No asume que "probablemente sea X".

**R-PIPE-7 — confirmed_by: "assumed" en plan.json = unknown automático.**
El Orquestador activa Research para ese dato. El pipeline no avanza hasta que se confirme.

### Agente Scribe — activo en todo momento

Scribe documenta mientras los demás trabajan. No espera a que terminen las fases.
El Orquestador le pasa decisiones, errores y despliegues para documentar.
Scribe **nunca** usa bash para escribir en `dev-log/` — usa MCP Obsidian (`write_note` / `patch_note`).

---

## 4. REGLAS DE SEGURIDAD

**R-SEC-1 — Webhooks sin validación de firma = critical finding.**
Siempre. Sin excepción. "Viene de fuente confiable" no exime.
Validar ANTES de procesar. Ver `[[webhook-validation]]`.

**R-SEC-2 — Raw body ANTES de JSON.parse para HMAC.**
Stripe, Shopify, WooCommerce requieren Buffer del raw body para calcular HMAC.
Parsear a JSON primero → firma inválida → bypass accidental de seguridad.

**R-SEC-3 — timingSafeEqual siempre para comparar tokens/firmas.**
```typescript
// ❌ NUNCA — vulnerable a timing attack
if (received === expected) { ... }

// ✅ SIEMPRE
crypto.timingSafeEqual(Buffer.from(received), Buffer.from(expected))
```

**R-SEC-4 — Responder 401, no 403, en firma inválida.**
**R-SEC-5 — No loguear el payload si la firma falla.**
El payload no validado puede ser malicioso. No lo persistir. No lo loguear.

**R-SEC-6 — PII nunca en CloudWatch logs.**
Emails, nombres, teléfonos, CIFs, IBANs = datos sensibles. Nunca en logs.

**R-SEC-7 — .env nunca en repositorio.**
`.gitignore` cubre `.env*` excepto `.env.example`.
`.env.example` solo con placeholders (`YOUR_KEY_HERE`), nunca valores reales.

**R-SEC-8 — Lambda Function URL pública con AuthType: NONE es correcto (ADR-3).**
Panel usa este patrón documentado. No es un finding de seguridad.
Sí verificar: handler valida token antes de procesar cualquier request.

---

## 5. REGLA DE PESADEZ

```
Ningún agente avanza sin certeza absoluta.

Si tiene dudas → pregunta.
Si la pregunta es obvia → pregunta igual.
Si ya preguntó una vez → pregunta de nuevo si el contexto cambió.

Un agente que asume cuesta más tokens que un agente que pregunta cinco veces.
La mediocridad no es una opción.
Pesado por diseño, no por accidente.
```

Esta regla aplica a todos los agentes sin excepción.
El Orquestador la aplica con más rigor que nadie — él coordina todo y no puede asumir.

---

## 6. MCP DISPONIBLE — VAULT OBSIDIAN

**Estado:** ✅ conectado · Puerto: `localhost:22360`

### Herramientas disponibles

| Herramienta | Uso |
|---|---|
| `search_notes` | Búsqueda semántica en toda la vault |
| `read_note` | Leer un nodo por path |
| `read_multiple_notes` | Leer varios nodos a la vez |
| `write_note` | Crear nodo nuevo |
| `patch_note` | Editar parcialmente un nodo existente |
| `list_directory` | Listar contenido de carpeta en la vault |
| `update_frontmatter` | Actualizar metadatos YAML de un nodo |
| `get_frontmatter` | Leer solo los metadatos de un nodo |
| `manage_tags` | Añadir/quitar tags |
| `get_vault_stats` | Estadísticas globales de la vault |
| `get_notes_info` | Info de múltiples nodos sin leer contenido |
| `list_all_tags` | Todos los tags de la vault |
| `delete_note` | Eliminar un nodo |
| `move_note` | Mover un nodo dentro de la vault |
| `move_file` | Mover un fichero |

### Reglas de uso — todos los agentes

**R-MCP-1 — Vault antes que filesystem.**
Antes de `ls` o `find` → usar `list_directory` o `search_notes`.
Más rápido. Menos tokens. El filesystem es el fallback, no el default.

**R-MCP-2 — `read_note` antes de `Read` tool para nodos en `dev-log/`.**
El MCP sirve el contenido optimizado. La herramienta Read es el fallback.

**R-MCP-3 — `patch_note` para cambios parciales, `write_note` solo para nodos nuevos.**
Nunca sobreescribir un nodo completo si solo cambia una sección.
`write_note` en nodo existente destruye el historial de Obsidian.

**R-MCP-4 — `search_notes` antes de leer para encontrar contexto relevante.**
Buscar primero. Leer solo los nodos que devuelva la búsqueda.
Nunca leer toda la vault para encontrar algo específico.

**R-MCP-5 — Scribe escribe en vault exclusivamente via MCP.**
Nunca bash para escribir en `dev-log/`. Sin excepción.
`write_note` para nodos nuevos. `patch_note` para actualizar secciones.

### Patrón correcto — arrancar proyecto nuevo

```
1. search_notes("plataforma_a plataforma_b") → nodos relevantes
2. read_multiple_notes([nodos encontrados]) → contexto completo
3. Pasar al Orquestador SOLO lo encontrado
```

### Patrón correcto — documentar error nuevo

```
1. search_notes("error plataforma")
2. Si existe → patch_note para añadir el caso al nodo existente
3. Si no existe → write_note para crear nodo nuevo en errors/
```

### Ubicaciones clave en la vault

```
dev-log/
├── knowledge-base/
│   ├── aws/          → serverless-framework-v3, lambda-patterns, ...
│   ├── platforms/    → prestashop, holded, zoho-crm, ...
│   ├── security/     → webhook-validation, gdpr-bigtoone, checklist-pre-deploy
│   ├── errors/       → errores documentados por plataforma
│   └── agent-details/ → scribe-templates, qa-test-cases, plan-template, ...
└── index.md          → índice maestro de la vault
```

---

*Última actualización: 2026-05-25*
