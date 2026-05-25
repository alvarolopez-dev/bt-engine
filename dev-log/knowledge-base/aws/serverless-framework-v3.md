---
tags: [aws, serverless-framework, iac, deployment, v3]
created: 2026-05-20
source: "PROJECT_DNA.md + PROJECT_DNA_COMPLEMENT.md §1-4 + serverless.yml real"
confidence: "high — validado en producción"
---

# Serverless Framework v3 — conocimiento de producción

#aws #serverless-framework #iac #deployment

Conocimiento destilado del proyecto `prestashop-holded-middleware-prod`.
Serverless Framework v3.38.0, congelado. No migrar a v4 sin evaluación.

---

## ADR-4 — Por qué v3 y no v4

```
Decisión:   Serverless Framework v3.38.0 — congelado
Motivo:     v4 tiene incompatibilidades con plugins usados:
            - serverless-offline@13.9.0
            - serverless-plugin-typescript
Evaluado:   Sí — descartado explícitamente
Fecha:      2026-05-19 (prestashop-holded-middleware-prod)
```

**7 vulnerabilidades residuales** en `npm audit`:
- Son de tooling local (aws-sdk v2 interno de serverless, file-type)
- NO llegan al runtime Lambda (no están en el bundle de producción)
- `npm audit fix --force` está **prohibido** — rompe la instalación
- Revisar solo si: cliente exige audit limpio contractualmente, o v4 estabiliza compatibilidad

---

## ⚠️ CONSTRAINT CRÍTICO — Node.js runtime

**Estado a 2026-05-25:**

| Elemento | Estado |
|---|---|
| Runtime actual (`serverless.yml`) | `nodejs20.x` |
| nodejs20.x deprecado por AWS | April 30, 2026 ✓ (ya pasado) |
| Block CREATE nuevas funciones AWS | **June 1, 2026** |
| nodejs22.x en SF v3 enum | **NO** — `ValidationError` en deploy |
| nodejs22.x soportado desde | SF v4.4.12 (comercial) |
| SF v4 | Breaking changes en config + suscripción de pago |

**Validación SF v3 (`lib/plugins/aws/provider.js` — enum hardcoded):**

```javascript
// nodejs22.x NO aparece — deploy con nodejs22.x falla en validación local
// antes de llegar a AWS
awsLambdaRuntime: {
  enum: [
    'nodejs14.x', 'nodejs16.x', 'nodejs18.x', 'nodejs20.x',
    // nodejs22.x — ausente
  ]
}
```

**Impacto por fecha:**

```
April 30, 2026   nodejs20.x officially deprecated por AWS (ya pasado)
June 1, 2026     AWS bloquea CREATE de funciones nuevas con nodejs20.x
                 → Proyectos nuevos no pueden crear Lambdas
                 → Funciones existentes: siguen ejecutando y actualizándose (por ahora)
TBD              AWS bloqueará UPDATES de funciones existentes (fecha no anunciada)
TBD              AWS bloqueará INVOCACIONES (fecha no anunciada)
```

**Opciones de migración (decisión pendiente — ADR-2b):**

| Opción | Esfuerzo | Coste adicional | Resultado |
|---|---|---|---|
| SF v3 → v4 | Alto — breaking changes en config | Suscripción comercial | `nodejs22.x` disponible |
| Ejectar a CDK/SAM | Alto — reescribir IaC completa | $0 | `nodejs22.x` disponible |
| Esperar sin migrar | Cero ahora | $0 | Funciones existentes degradadas progresivamente |

**Pendiente: ADR-2b** — Evaluación formal SF v3 → v4 vs alternativa IaC.

---

## Estructura base de serverless.yml

```yaml
service: {nombre-proyecto}

frameworkVersion: '3'

plugins:
  - serverless-plugin-typescript
  - serverless-offline
  - serverless-step-functions    # Si usa Step Functions

custom:
  enablePanel: ${env:ENABLE_PANEL, 'false'}    # Gate de infraestructura opcional

provider:
  name: aws
  runtime: nodejs20.x
  region: eu-west-2              # Londres — siempre para clientes españoles
  stage: ${opt:stage, 'dev'}
  memorySize: 1024               # MB — default para todas las funciones
  timeout: 30                    # s — default, sobreescribir por función si necesario
  environment:
    NODE_ENV: production
    DYNAMODB_TABLE_ORDERS: ${self:service}-orders-${sls:stage}
    # ... resto de env vars con defaults
  iam:
    role:
      statements:
        # IAM mínimo por servicio (ver sección IAM)

functions:
  # Ver sección Lambdas

stepFunctions:
  # Solo si usa Step Functions — ver step-functions-express.md

resources:
  Conditions:
    # Solo si hay features opcionales
  Resources:
    # DynamoDB, S3, SNS, CloudFront, etc.
  Outputs:
    # URLs que scripts de deploy necesitan leer
```

---

## Patrón de 3 tiers con env vars

### Lógica del patrón

```
Tier Basic  → ENABLE_PANEL=false + ENABLE_PRODUCT_SYNC=false
              Infra: DynamoDB×N + S3 + SNS + Step Functions + EventBridge
              Coste: ~€0.00-0.10/mes

Tier Pro    → ENABLE_PANEL=true + ENABLE_PRODUCT_SYNC=false
              Infra anterior + CloudFront + Lambda Function URL
              Coste: ~€0.50-2.00/mes (CloudFront mínimo)

Tier Pro+   → ENABLE_PANEL=true + ENABLE_PRODUCT_SYNC=true
              Todo anterior + sync catálogo productos
              Coste: similar Pro + llamadas API adicionales
```

### Tres tipos de gate

**1 — Gate de infraestructura** (crea/destruye recursos AWS con `sls deploy`):

```yaml
# En custom:
custom:
  enablePanel: ${env:ENABLE_PANEL, 'false'}

# En resources.Conditions:
resources:
  Conditions:
    PanelEnabled: !Equals
      - ${env:ENABLE_PANEL, 'false'}
      - 'true'

  Resources:
    # Recurso condicional
    PanelRouterFunctionUrl:
      Condition: PanelEnabled          # ← Solo existe si PanelEnabled=true
      Type: AWS::Lambda::Url
      Properties:
        AuthType: NONE
        TargetFunctionArn: !GetAtt PanelRouterLambdaFunction.Arn
        Cors:
          AllowOrigins: ['*']
          AllowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS']
          AllowHeaders: ['*']
```

**2 — Gate de código** (lógica opcional sin recursos AWS nuevos):

```typescript
// Al inicio del módulo — una vez, al cargar la Lambda
const ENABLE_PRODUCT_SYNC = process.env.ENABLE_PRODUCT_SYNC === 'true';
const ENABLE_ACCOUNTING   = process.env.ENABLE_ACCOUNTING   === 'true';

// En el handler:
if (ENABLE_PRODUCT_SYNC) {
  const productIds = await resolverHoldedProductIds(lineas, holdedService);
}
```

**3 — Gate de degradación** (feature opcional que no rompe flujo principal):

```typescript
try {
  await holdedService.crearPago(docId, amount, treasuryId);
} catch (e: any) {
  log.warn({ error: e.message }, 'Pago falló — factura ya creada, continuando');
  // No re-throw — no es un error fatal
}
```

### Invariante del patrón

La feature opcional **nunca bloquea el flujo base**.
Si falla: infra → no se crea. Código → try/catch → log.warn → valor por defecto.

### Variables de feature flag (referencia)

| Variable | Default | Tier | Ámbito |
|---|---|---|---|
| `ENABLE_PANEL` | `false` | Pro | Infraestructura (CloudFront + URL) + código (endpoints panel) |
| `ENABLE_ACCOUNTING` | `false` | Pro | Solo código (cuenta contable por línea) |
| `ENABLE_PRODUCT_SYNC` | `false` | Pro+ | Solo código (sync SKUs → catálogo Holded) |

---

## ADR-8 — panelRouter Lambda siempre desplegada

**Problema:** Serverless v3 no puede condicionar funciones con CloudFormation Conditions.

```yaml
# ── IMPOSIBLE EN SERVERLESS v3 ───────────────────────────────────────────────
functions:
  panelRouter:
    Condition: PanelEnabled  # ← No funciona en Serverless v3
    handler: src/handlers/panel.router

# ── SOLUCIÓN IMPLEMENTADA ────────────────────────────────────────────────────
functions:
  panelRouter:
    handler: src/handlers/panel.router
    timeout: 600
    # Sin 'url' aquí — la Function URL es un recurso separado condicional

resources:
  Conditions:
    PanelEnabled: !Equals
      - ${env:ENABLE_PANEL, 'false'}
      - 'true'

  Resources:
    # La Lambda existe siempre, pero solo tiene URL si ENABLE_PANEL=true
    PanelRouterFunctionUrl:
      Condition: PanelEnabled
      Type: AWS::Lambda::Url
      Properties:
        AuthType: NONE
        TargetFunctionArn: !GetAtt PanelRouterLambdaFunction.Arn
```

**Resultado:** La Lambda existe en todos los deploys pero sin URL/trigger = €0 sin invocaciones.
Alternativa descartada: dos serverless.yml separados (duplicación de config).

---

## CloudFront condicional (ENABLE_PANEL)

### Por qué CloudFront delante del panel

La cuenta AWS tiene "Block Public Access for Lambda Function URLs" activo a nivel de cuenta.
Sin API para desactivarlo → obligatorio usar un intermediario.

**OAC+SigV4 fue descartado** (bug AWS con POST/PUT):
- AWS POST/PUT requests usan `UNSIGNED-PAYLOAD` en el header de autenticación
- Esto rompe la firma SigV4 → error 403 en todas las mutaciones
- **Solución:** `AuthType: NONE` en Function URL + CloudFront delante sin firma

⚠️ **Nota:** CLAUDE.md del proyecto documenta `AuthType: AWS_IAM` — **incorrecto**.
El `serverless.yml` es siempre la fuente de verdad (ver ADR-3).

### CloudFront configuration real

```yaml
resources:
  Resources:
    PanelDistribution:
      Condition: PanelEnabled
      Type: AWS::CloudFront::Distribution
      Properties:
        DistributionConfig:
          Enabled: true
          HttpVersion: http2
          DefaultCacheBehavior:
            TargetOriginId: PanelLambdaOrigin
            ViewerProtocolPolicy: redirect-to-https
            AllowedMethods: [GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE]
            CachedMethods: [GET, HEAD, OPTIONS]
            CachePolicyId: 4135ea2d-6df8-44a3-9df3-4b5a84be39ad     # CachingDisabled
            OriginRequestPolicyId: b689b0a8-53d0-40ab-baf2-68738e2966ac  # AllViewer
          Origins:
            - Id: PanelLambdaOrigin
              DomainName: !Select
                - 2
                - !Split ['/', !GetAtt PanelRouterFunctionUrl.FunctionUrl]
              CustomOriginConfig:
                HTTPSPort: 443
                OriginProtocolPolicy: https-only
                OriginReadTimeout: 60          # s — máximo visible por CloudFront
          CustomErrorResponses:
            - ErrorCode: 500
              DefaultTTL: 0                    # No cachear errores
```

**Puntos críticos:**
- `CachingDisabled` — sin caché (panel es SPA con estado dinámico)
- `AllViewer` OriginRequestPolicy — pasa `x-panel-token` header a Lambda
- `OriginReadTimeout: 60` — máximo que CloudFront espera (Lambda puede tardar más, pero CF corta)
- Primera propagación CloudFront: ~15 min. Cambios posteriores: ~5 min.

---

## Scripts de deploy

```bash
# Deploy completo — infra + código
npm run deploy
# = sls deploy --stage prod

# Solo panel HTML — más rápido, no toca infra AWS
npm run panel:deploy
# Lee PanelCloudFrontUrl del stack CloudFormation automáticamente:
# aws cloudformation describe-stacks \
#   --stack-name {service}-prod \
#   --query "Stacks[0].Outputs[?OutputKey=='PanelCloudFrontUrl'].OutputValue"

# Local
npm run setup:local    # Crea tablas DynamoDB local + bucket MinIO
npm run start:local    # serverless offline → http://localhost:3000
npm run flow:local     # Ejecuta fetch+process manual en local

# Destructivo — no usar sin confirmación explícita
npm run remove         # Elimina TODA la infra AWS del stage
```

### Output CloudFormation para scripts

```yaml
Outputs:
  PanelCloudFrontUrl:
    Condition: PanelEnabled
    Description: URL pública del panel via CloudFront
    Value: !Sub 'https://${PanelDistribution.DomainName}'
    Export:
      Name: ${self:service}-${sls:stage}-panel-url
```

---

## Variables de entorno — obligatorias vs opcionales

### Requeridas en producción (sin default — deploy falla si no están)

```yaml
HOLDED_API_KEY: ''         # API key Holded — Secrets Manager en prod
HOLDED_SERIE_ID: ''        # ID serie facturas en Holded
PRESTASHOP_URL: ''         # URL tienda PrestaShop
PRESTASHOP_API_KEY: ''     # ws_key PrestaShop
```

### Opcionales con default seguro

```yaml
ORDER_PAID_STATE_ID: '2'       # ID estado "Pago aceptado" en PrestaShop (varía por tienda)
DAYS_TO_FETCH: '1'             # Días hacia atrás que descarga Lambda 1
ENABLE_ACCOUNTING: 'false'     # Resolución cuenta contable por SKU/categoría
HOLDED_TREASURY_ID: ''         # Vacío = no registra cobro en Holded
SECRETS_MANAGER_SECRET_NAME: '' # Vacío = usa .env directo (solo local)
```

### Solo en .env local (NO definir en producción)

```
DYNAMODB_ENDPOINT=http://localhost:8000
S3_ENDPOINT=http://localhost:9000
IS_LOCAL=local
ENABLE_PANEL=true       # Solo en .env — no en serverless.yml environment
ENABLE_PRODUCT_SYNC=true
```

---

## IAM mínimo — referencia

```yaml
iam:
  role:
    statements:
      # DynamoDB — tabla por tabla, no wildcard
      - Effect: Allow
        Action: [dynamodb:Query, dynamodb:Scan, dynamodb:GetItem,
                 dynamodb:PutItem, dynamodb:UpdateItem, dynamodb:DeleteItem,
                 dynamodb:BatchGetItem, dynamodb:BatchWriteItem]
        Resource: !GetAtt OrdersTable.Arn

      # S3 — bucket específico, no wildcard
      - Effect: Allow
        Action: [s3:PutObject, s3:GetObject, s3:ListBucket]
        Resource:
          - !GetAtt RawBucket.Arn
          - !Sub '${RawBucket.Arn}/*'

      # Secrets Manager — solo el secreto del proyecto
      - Effect: Allow
        Action: [secretsmanager:GetSecretValue]
        Resource: !Sub 'arn:aws:secretsmanager:${self:provider.region}:*:secret:${self:service}-${sls:stage}-secrets-*'

      # SNS — solo el topic de alertas del proyecto
      - Effect: Allow
        Action: [sns:Publish]
        Resource: !Ref AlertaTopic
```

---

## Anti-patrones documentados

| Anti-patrón | Problema | Solución |
|---|---|---|
| `npm audit fix --force` | Rompe instalación, vulns son tooling no runtime | Aceptar las 7 vulns conscientemente |
| Condicionar funciones con CF Conditions | No funciona en Serverless v3 | Lambda siempre + URL condicional (ADR-8) |
| `AuthType: AWS_IAM` + OAC | Bug AWS con POST/PUT UNSIGNED-PAYLOAD | `AuthType: NONE` + CloudFront sin OAC |
| Wildcard en IAM (`Resource: '*'`) | Principio de mínimo privilegio | Resource específico por tabla/bucket/secreto |
| `DYNAMODB_ENDPOINT` en producción | Lambda en AWS no puede conectar a localhost | Variable SOLO en .env local |

---

## Relaciones

- [[architecture-decision-tree]] — cuándo usar esta arquitectura vs event-driven
- [[lambda-patterns]] — patrones TypeScript para las Lambdas desplegadas aquí
- [[step-functions-express]] — detalle de la Step Function que orquesta
- [[dynamodb-patterns]] — tablas DynamoDB creadas en los Resources
- [[prestashop-holded-middleware-prod]] — proyecto de referencia

## Proyectos donde aparece

- [[prestashop-holded-middleware-prod]] — Serverless v3.38.0, operativo desde 2026-05-15
