---
tags: [security, gdpr, rgpd, compliance, españa]
created: 2026-05-25
source: "10_agent_security.md — obligaciones específicas ecosistema Bigtoone"
---

# GDPR — Obligaciones específicas Bigtoone

#security #gdpr #compliance

Contexto: Bigtoone es grupo tecnológico B2B con sede en Madrid.
Clientes: empresas y autónomos (B2B). Operamos en España → aplica RGPD (EU 2016/679)
y LOPDGDD (Ley Orgánica 3/2018).

Stack técnico donde se aplica: AWS Lambda + DynamoDB + CloudWatch + Secrets Manager.

---

## Roles GDPR en el ecosistema

### Bigtoone como encargado del tratamiento

En la mayoría de integraciones:
- **Responsable del tratamiento:** el cliente (la empresa que encarga la integración)
- **Encargado del tratamiento:** Bigtoone (desarrolla y opera la integración)
- **Sub-encargados:** AWS, Holded, plataforma de ecommerce (PrestaShop, Shopify, etc.)

**Consecuencia:** Bigtoone necesita contrato de encargo de tratamiento (DPA) con cada cliente.
Los clientes necesitan incluir a AWS y Holded en su registro de actividades de tratamiento.

### Cuando Bigtoone es responsable

En productos propios (AvanPyme, Subvfy, etc.):
- Bigtoone es responsable del tratamiento de los datos de sus clientes directos.

---

## Datos personales en el stack

### DynamoDB — campos PII habituales

| Tabla | Campos PII | Base jurídica |
|---|---|---|
| `contacts` | nombre, email, empresa, teléfono | Ejecución de contrato (B2B) |
| `orders` | nombre cliente, dirección envío, email | Ejecución de contrato |
| `accounts` | nombre empresa, CIF | Obligación legal (contabilidad) |
| `products` | ninguno (datos de producto) | — |
| `categories` | ninguno | — |

> **Nota sobre CIF de autónomo:** El CIF de un autónomo es dato personal (identifica a persona física).
> Tratarlo como PII. No loguear. No exponer en APIs innecesariamente.

### CloudWatch — PII prohibida

CloudWatch Logs NO debe contener:
- Emails de clientes finales
- Nombres completos de personas físicas
- Teléfonos, DNIs, CIFs de autónomos, IBANs

**Qué sí puede aparecer en logs:**
- IDs internos (order_id, contact_id, holded_id — no son datos personales en sí)
- Errores técnicos sin datos personales
- Métricas y tiempos de ejecución

---

## Retención de datos

### DynamoDB

| Datos | Retención recomendada | Motivo |
|---|---|---|
| Pedidos | 5 años | Obligación fiscal (Art. 30 CCom) |
| Contactos | Vigencia de la relación + 3 años | RGPD Art. 17 vs obligación legal |
| Logs de sincronización | 1 año | Debugging y trazabilidad |
| Datos de productos | Sin límite (no PII) | — |

**Estado actual (prestashop-holded-middleware-prod):** retención no configurada automáticamente
en DynamoDB. Deuda técnica — documentada, pendiente de implementar TTL por tabla.

### CloudWatch Logs

Retención configurada en `serverless.yml`:

```yaml
resources:
  Resources:
    StepFunctionsLogGroup:
      Type: AWS::Logs::LogGroup
      Properties:
        RetentionInDays: 30    # Suficiente para debugging
```

**30 días es el estándar del ecosistema.** Suficiente para debugging, cumple RGPD
(no retención indefinida), aceptable para SOC2.

Si un cliente requiere retención mayor (auditoría, obligación contractual): documentar
en el proyecto específico y ajustar `RetentionInDays`.

---

## Derecho al olvido (Art. 17 RGPD)

El cliente puede solicitar borrado de sus datos. Procedimiento actual:

### Datos en DynamoDB

```bash
# Borrar contacto por ID
aws dynamodb delete-item \
  --table-name {proyecto}-contacts-prod \
  --key '{"contactId": {"S": "XXXX"}}' \
  --region eu-west-2

# Borrar pedidos asociados — requiere query previa por contactId
aws dynamodb query \
  --table-name {proyecto}-orders-prod \
  --index-name contactId-index \
  --key-condition-expression "contactId = :cid" \
  --expression-attribute-values '{":cid": {"S": "XXXX"}}' \
  --region eu-west-2
# Luego delete-item para cada resultado
```

**Estado actual:** procedimiento manual. Deuda técnica — no hay endpoint de borrado
automatizado. Si el volumen de solicitudes aumenta → implementar como Lambda.

### Datos en CloudWatch

Los logs se borran automáticamente según `RetentionInDays`.
Para borrado anticipado de logs específicos que contengan datos de un cliente:

```bash
# Buscar log streams del cliente
aws logs describe-log-streams \
  --log-group-name /aws/lambda/{función} \
  --region eu-west-2

# Borrar log stream específico (borra todos los logs del stream)
aws logs delete-log-stream \
  --log-group-name /aws/lambda/{función} \
  --log-stream-name "2026/05/25/[$LATEST]XXXX" \
  --region eu-west-2
```

### Datos en plataformas externas (Holded, PrestaShop)

El borrado en DynamoDB no borra datos en Holded ni en PrestaShop.
Responsabilidad del cliente como responsable del tratamiento gestionar el borrado
en cada plataforma según sus propias APIs.

---

## Transferencias internacionales

### Regiones AWS y su status GDPR

| Región | Ubicación | Status GDPR |
|---|---|---|
| eu-west-1 | Irlanda | ✅ UE — sin restricciones |
| eu-west-3 | París | ✅ UE — sin restricciones |
| eu-west-2 | Londres | ⚠️ UK fuera de UE — cubierto por decisión de adecuación (revisable) |
| eu-central-1 | Frankfurt | ✅ UE — sin restricciones |
| us-east-1 | Virginia | ❌ No aceptable sin cláusulas contractuales tipo |
| ap-* | Asia-Pacífico | ❌ No aceptable sin cláusulas contractuales tipo |

**Stack actual:** eu-west-2. Aceptable actualmente por decisión de adecuación UK
(COM(2021) 4250). Seguimiento requerido — la decisión puede revocarse.

**Recomendación:** nuevos proyectos → eu-west-1 (Irlanda) o eu-west-3 (París).

### Sub-encargados con acceso a datos

| Sub-encargado | Tipo de acceso | DPA disponible |
|---|---|---|
| AWS | Infraestructura (Lambda, DynamoDB, CloudWatch) | Sí — AWS Data Processing Addendum |
| Holded | Destino de datos (facturas, contactos) | Verificar con Holded |
| PrestaShop | Fuente de datos (pedidos, clientes) | Verificar con cliente |

---

## Registro de actividades de tratamiento (Art. 30 RGPD)

Bigtoone debe mantener registro de actividades como encargado.
Para cada integración documentar:

```
- Nombre y datos de contacto del responsable (cliente)
- Categorías de tratamiento: sincronización de pedidos, facturación
- Categorías de datos: datos identificativos, datos económicos
- Categorías de interesados: clientes finales del responsable
- Destinatarios: Holded (facturación)
- Transferencias internacionales: no (si todo en UE/adecuación)
- Plazo de supresión: según política de retención del cliente
- Medidas de seguridad: cifrado en tránsito (TLS), cifrado en reposo (DynamoDB default)
```

---

## Medidas técnicas de seguridad

### Cifrado en tránsito

- Lambda → DynamoDB: TLS (AWS SDK lo gestiona automáticamente)
- Lambda → Secrets Manager: TLS
- Lambda → APIs externas: HTTPS obligatorio (rechazar HTTP)
- CloudFront → Lambda URL: HTTPS

### Cifrado en reposo

- DynamoDB: cifrado AES-256 activado por defecto en todas las tablas
- S3 (datos temporales): SSE-S3 activado por defecto
- Secrets Manager: cifrado con KMS

### Control de acceso

- Secrets Manager: acceso solo a Lambdas con IAM policy específica
- DynamoDB: IAM policy por tabla, no wildcard
- CloudWatch: acceso solo a rol de ejecución Lambda

---

## Incidents y notificaciones

**Plazo de notificación (Art. 33 RGPD):** 72 horas desde detección al responsable.
**Umbral:** brecha que suponga riesgo para derechos de personas físicas.

**Si se detecta un incident:**
1. Documentar en `incidents/` con fecha y descripción
2. Evaluar si hay datos personales afectados
3. Si hay PII comprometida → notificar al cliente (responsable) en < 72h
4. El cliente notifica a la AEPD si procede

Ver `incidents/` — carpeta de registro de incidentes.

---

## Deudas técnicas GDPR conocidas

| Deuda | Impacto | Prioridad |
|---|---|---|
| TTL por tabla DynamoDB no configurado | Retención no automática — borrado manual | Media |
| Endpoint de borrado automatizado (derecho al olvido) | Procedimiento manual actual | Media |
| DPA firmado con cada cliente | Riesgo contractual | Alta |
| Registro actividades de tratamiento formal | Obligatorio Art. 30 | Alta |

---

## Relaciones

- [[checklist-pre-deploy]] — Capa 5 GDPR del checklist
- [[webhook-validation]] — validación de firma (protege integridad de datos)
- [[lambda-patterns]] — P3 (logging estructurado sin PII), P8 (IAM mínimo)
- [[dynamodb-patterns]] — tablas con PII documentadas

*Última actualización: 2026-05-25*
