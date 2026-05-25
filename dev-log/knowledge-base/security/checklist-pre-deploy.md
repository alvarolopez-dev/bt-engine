---
tags: [security, checklist, pre-deploy, auditoria]
created: 2026-05-25
source: "10_agent_security.md — stack real Bigtoone"
---

# Checklist pre-deploy — 7 capas de seguridad

#security #checklist #pre-deploy

Referencia operativa para el agente Security (Modo 1).
Ejecutar en orden. No saltar capas.
Cada check: ✅ pass / ❌ critical / ⚠️ warning.

---

## CAPA 1 — Secrets y credenciales

Objetivo: ningún secret real accesible fuera de Secrets Manager.

```
[ ] .gitignore cubre: .env, .env.*, *.pem, *.key, credentials.json, secrets.json
[ ] git log --all --full-history -- '*.env' devuelve vacío
[ ] Sin secrets hardcodeados en código, comentarios, ni logs
[ ] .env.example existe con placeholders (YOUR_KEY_HERE), sin valores reales
[ ] Sin credenciales AWS hardcodeadas (patrón AKIA[0-9A-Z]{16})
[ ] Lambda en producción carga secrets desde Secrets Manager — no desde .env
```

**Comandos:**

```bash
# Credenciales AWS hardcodeadas
grep -rE "AKIA[0-9A-Z]{16}" . --include="*.ts" --include="*.js" --include="*.json"

# Secrets con valores reales
grep -rE "(password|secret|api_key|apikey)\s*[=:]\s*['\"][^'\"]{8,}" src/

# Ficheros .env en historial git
git log --all --full-history -- '*.env' -- '.env'

# .gitignore cubre .env
grep "\.env" .gitignore
```

| Resultado | Severidad |
|---|---|
| Secret real en código o git histórico | ❌ Critical |
| `.env.example` inexistente o incompleto | ⚠️ Warning |
| Lambda lee `.env` en producción | ❌ Critical |

---

## CAPA 2 — Validación de webhooks entrantes

Objetivo: ningún payload externo procesado sin firma validada.

```
[ ] Firma validada ANTES de parsear o procesar el payload
[ ] Stripe: body leído como raw Buffer — no JSON parseado (bodyParser desactivado)
[ ] Shopify: mismo patrón raw body
[ ] WooCommerce: raw body para HMAC-SHA256
[ ] Respuesta 401/403 inmediata si firma inválida — sin procesar nada
[ ] Sin flag de bypass ni "modo debug" que salte la validación en producción
[ ] Timeout configurado en Lambda receptora de webhooks
```

Ver [[webhook-validation]] para código exacto por plataforma.

| Resultado | Severidad |
|---|---|
| Webhook procesa payload antes de validar firma | ❌ Critical |
| Validación comentada o con bypass | ❌ Critical |
| No hay webhooks en este proyecto | ⚠️ Warning (documentar "no aplica") |

---

## CAPA 3 — Inputs y datos

Objetivo: ningún dato de cliente en CloudWatch, ningún input sin validar.

```
[ ] Inputs de APIs externas validados con Zod (o equivalente)
[ ] PII no aparece en logs — emails, nombres, teléfonos, DNIs, CIFs, IBANs
[ ] Errores no exponen stack traces al exterior
[ ] Respuestas API devuelven solo los datos necesarios (no over-fetching)
[ ] Sin console.log de datos de clientes en ningún handler
```

**Búsqueda:**

```bash
# PII en logs
grep -rn "log\.\(info\|debug\|warn\|error\).*\(email\|nombre\|phone\|telefono\)" src/
grep -rn "console\.log.*\(email\|customer\|cliente\)" src/

# Inputs sin validación Zod
grep -rn "event\." src/handlers/ | grep -v "z\." | head -20
# Revisar manualmente los resultados
```

| Resultado | Severidad |
|---|---|
| PII en logs de CloudWatch | ❌ Critical |
| Inputs externos sin validación Zod | ❌ Critical |
| Stack trace expuesto en respuesta de error | ⚠️ Warning |

---

## CAPA 4 — IAM y permisos

Objetivo: mínimo privilegio. Sin wildcards no documentados.

```
[ ] IAM role con permisos mínimos — Resource específico por tabla/bucket/secreto
[ ] Sin wildcards en DynamoDB, S3, Secrets Manager, o SNS
[ ] Cada Lambda solo tiene permisos para recursos que usa realmente
[ ] Sin credenciales AWS hardcodeadas (AKIA...)
[ ] Sin AdministratorAccess o PowerUser en rol Lambda
[ ] Wildcard en CloudWatch Logs delivery documentado como excepción conocida
```

**Verificar en serverless.yml:**

```bash
# Wildcards en IAM
grep -n "Resource: '\*'" serverless.yml
grep -n "Action: '\*'" serverless.yml

# Resultado aceptable: solo logs:* con excepción CloudWatch Logs delivery
# Todo lo demás → revisar
```

| Resultado | Severidad |
|---|---|
| Wildcard en DynamoDB / S3 / Secrets Manager / SNS | ❌ Critical |
| Wildcard en CloudWatch Logs delivery | ⚠️ Warning (excepción documentada) |
| Lambda con permisos no usados | ⚠️ Warning |

---

## CAPA 5 — GDPR

Objetivo: datos personales protegidos, retención definida, datos en UE.

```
[ ] Datos personales identificados: qué tablas, qué campos exactos
[ ] Retención en DynamoDB documentada (ej: pedidos 5 años por obligación fiscal)
[ ] Retención de logs CloudWatch configurada (30 días — aceptable para debugging)
[ ] Derecho al olvido: existe procedimiento para borrar datos de un cliente
[ ] Región AWS: eu-west-1 (Irlanda), eu-west-2 (Londres*), o eu-west-3 (París)
[ ] Procesadores de datos identificados en documentación del proyecto
```

> **eu-west-2 (Londres):** UK fuera de UE. Cubierto por decisión de adecuación
> de la Comisión Europea (en vigor a 2026-05-25, revisable).
> Aceptable actualmente. Menos robusto que eu-west-1/eu-west-3.
> Documentar como warning en proyectos que usen esta región.

**Campos personales frecuentes en el stack:**

| Tabla DynamoDB | Campos PII |
|---|---|
| contacts | nombre, email, empresa, teléfono |
| orders | nombre cliente, dirección envío |
| accounts | nombre empresa, CIF (PII de autónomo) |

| Resultado | Severidad |
|---|---|
| Datos de clientes en región fuera de UE/adecuación | ❌ Critical |
| Sin retención configurada en CloudWatch (logs infinitos) | ❌ Critical |
| Sin retención documentada en DynamoDB | ⚠️ Warning |
| Derecho al olvido sin procedimiento | ⚠️ Warning |
| Proyecto en eu-west-2 | ⚠️ Warning (registrar dependencia de adecuación UK) |

Ver [[gdpr-bigtoone]] para obligaciones específicas.

---

## CAPA 6 — SOC2 awareness

Objetivo: trazabilidad y control de acceso a producción.

```
[ ] CloudWatch logs activos en todas las Lambdas — no desactivados
[ ] SNS alerta configurada para errores críticos (FalloProceso en Step Functions)
[ ] Cambios en producción trackeados con git tags de deploy
[ ] Acceso a producción controlado por credenciales AWS — no compartidas
[ ] Sin acceso manual ad-hoc a DynamoDB en producción sin justificación documentada
```

| Resultado | Severidad |
|---|---|
| CloudWatch logs desactivados en alguna Lambda | ❌ Critical |
| Sin SNS alerta para errores críticos | ⚠️ Warning |
| Deploys sin git tag | ⚠️ Warning |

---

## CAPA 7 — Superficie de ataque Lambda URLs

Objetivo: entrada pública controlada, sin información expuesta al exterior.

```
[ ] Timeout configurado en cada Lambda con entrada pública
[ ] Reserved concurrency configurada o kill switch documentado (P13 lambda-patterns)
[ ] Payload máximo conocido: 6MB sync, 1MB async — inputs grandes van a S3
[ ] Headers de respuesta no exponen X-Powered-By, Server, versiones
[ ] Errores internos devuelven mensaje genérico — sin stack trace al exterior
[ ] CORS restrictivo si Lambda URL accesible desde browser
[ ] Token de autenticación del panel validado antes de procesar (ADR-3)
```

| Resultado | Severidad |
|---|---|
| Timeout no configurado en Lambda con entrada pública | ❌ Critical |
| Stack trace expuesto en respuesta de error | ❌ Critical |
| Sin reserved concurrency (kill switch no disponible) | ⚠️ Warning |
| CORS con AllowOrigins: * en Lambda con datos sensibles | ⚠️ Warning |

---

## Agregación de resultados

```
Cualquier ❌ Critical  →  status: "fail"  →  ready_for_devops: false
Solo ⚠️ Warning        →  status: "warn"  →  ready_for_devops: true (con condiciones)
Todo ✅ pass            →  status: "pass"  →  ready_for_devops: true
```

Generar `security_report.json` con resultado. Ver agente Security §6 para formato completo.

---

## Relaciones

- [[10_agent_security]] — agente que ejecuta este checklist
- [[webhook-validation]] — código de validación por plataforma
- [[gdpr-bigtoone]] — obligaciones GDPR específicas del ecosistema
- [[lambda-patterns]] — P8 (IAM mínimo), P13 (kill switch concurrency)
- [[serverless-framework-v3]] — serverless.yml donde verificar IAM

*Última actualización: 2026-05-25*
