---
tags: [aws, arquitectura, decision-tree, lambda, step-functions, webhooks]
created: 2026-05-20
source: "PROJECT_DNA.md + PROJECT_DNA_COMPLEMENT.md — prestashop-holded-middleware-prod"
confidence: "high — validado en producción"
---

# Árbol de decisión de arquitectura — integraciones

#aws #arquitectura #decision-tree

Para cualquier integración nueva de plataforma → Holded (o plataforma → plataforma),
seguir este árbol antes de escribir una línea de código.

---

## Árbol principal

```
¿La plataforma origen tiene webhooks nativos?
│
├── SÍ ──────────────────────────────────────────────────────────┐
│                                                                 │
│   ¿Volumen esperado > 1.000 eventos/hora?                      │
│   │                                                            │
│   ├── NO → Lambda Function URL directa                         │
│   │        Webhook → Lambda → Holded                           │
│   │        (< €0.10/mes para volumen bajo-medio)               │
│   │                                                            │
│   └── SÍ → SQS buffer + Lambda consumer                       │
│            Webhook → SQS → Lambda → Holded                     │
│            (protege contra spikes, reintentos nativos SQS)     │
│                                                                 │
└── NO ───────────────────────────────────────────────────────────┤
                                                                  │
    Step Functions Express + EventBridge cron                    │
    Lambda 1 (fetch) → S3 → Lambda 2 (process) → Holded         │
    (mismo patrón validado en prestashop-holded-middleware-prod)  │
```

---

## Clasificación de plataformas documentadas

### Event-driven viable (webhooks nativos)

| Plataforma | Evento clave | Payload | Signature header | Timeout webhook |
|---|---|---|---|---|
| [[revo-xef]] | `order.closed` | `application/x-www-form-urlencoded` | `X-Revo-Hmac-SHA256` | < 5s o desactiva |
| [[revo-retail]] | `order.closed` | `application/x-www-form-urlencoded` | `X-Revo-Hmac-SHA256` | < 5s o desactiva |
| [[stripe]] | `payment_intent.succeeded` / `invoice.paid` | JSON | `Stripe-Signature` | < 5s |
| [[woocommerce]] | `order.updated` (filtrar por status) | JSON | `X-WC-Webhook-Signature` | < 5s |
| [[shopify]] | `orders/paid` | JSON | `X-Shopify-Hmac-Sha256` | < 5s |
| [[zoho-crm]] | Notifications API (renovar c/48h) | JSON | token en payload | < 10s |
| [[business-central]] | Webhook subscriptions (renovar c/2d) | JSON | validationToken handshake | < 10s |

### Polling obligatorio (sin webhooks)

| Plataforma | Razón | Patrón | Endpoint |
|---|---|---|---|
| [[prestashop]] | Sin webhooks nativos | EventBridge cron → Step Functions | `GET /orders?filter[date_upd]=[desde,hasta]` |
| [[revo-flow]] | Sin webhooks documentados | EventBridge cron → Step Functions | `GET /bookings` |
| [[revo-solo]] | Sin webhooks documentados | EventBridge cron → Step Functions | `GET /sync/orders` |

---

## Rama A — Event-driven (con webhooks)

### Arquitectura estándar

```
Plataforma
  → POST webhook payload
      → Lambda Function URL (AuthType: NONE + CloudFront)
          → Validar firma HMAC
          → Responder 200 INMEDIATAMENTE (< 5s — crítico)
          → Encolar en SQS (o Step Functions async)
              → Lambda procesado
                  → GET detalles completos del evento
                  → POST factura/abono en Holded
                  → DynamoDB ConditionalCheck (idempotencia)
```

### Ejemplo serverless.yml — Lambda Function URL para webhook

```yaml
service: revo-holded-middleware

provider:
  name: aws
  runtime: nodejs20.x
  region: eu-west-2
  memorySize: 1024
  environment:
    DYNAMODB_TABLE_ORDERS: ${self:service}-orders-${sls:stage}
    HOLDED_API_KEY: ''          # Secrets Manager en prod
    REVO_WEBHOOK_SECRET: ''
    SECRETS_MANAGER_SECRET_NAME: ''

functions:
  webhookReceiver:
    handler: src/handlers/webhook_receiver.main
    timeout: 10        # Corto — solo valida + encola
    url: true          # Lambda Function URL pública

  orderProcessor:
    handler: src/handlers/order_processor.main
    timeout: 300       # Procesado real aquí
    # Trigger: SQS o Step Functions

resources:
  Resources:
    OrdersTable:
      Type: AWS::DynamoDB::Table
      Properties:
        BillingMode: PAY_PER_REQUEST
        TableName: ${self:provider.environment.DYNAMODB_TABLE_ORDERS}
        AttributeDefinitions:
          - AttributeName: id_pedido_tienda
            AttributeType: S
        KeySchema:
          - AttributeName: id_pedido_tienda
            KeyType: HASH
```

### Handler webhook — patrón "respuesta rápida + async"

```typescript
// webhook_receiver.ts
export const main = async (event: any): Promise<any> => {
  await cargarSecretos();

  // 1. Validar firma ANTES de procesar
  const signature = event.headers?.['x-revo-hmac-sha256'];
  if (!validarFirmaHMAC(event.body, signature, process.env.REVO_WEBHOOK_SECRET!)) {
    return { statusCode: 401, body: 'Unauthorized' };
  }

  // 2. Parsear payload (Revo: form-data, NO JSON)
  const payload = new URLSearchParams(event.body);
  const orderId = payload.get('data[id]');

  // 3. Encolar para procesado async
  await sqsClient.send(new SendMessageCommand({
    QueueUrl: process.env.SQS_QUEUE_URL!,
    MessageBody: JSON.stringify({ orderId, tenant: payload.get('tenant') }),
    MessageDeduplicationId: orderId!, // FIFO queue — idempotencia a nivel SQS
  }));

  // 4. CRÍTICO: responder 200 antes de 5s
  // Si no → Revo desactiva el webhook tras 5 reintentos fallidos
  return { statusCode: 200, body: 'OK' };
};
```

---

## Rama B — Polling (sin webhooks)

### Arquitectura estándar

```
EventBridge cron (diario o cada N horas)
  → StartExecution → Step Functions Express
      → Lambda 1: GET /orders?date_from=X&date_to=Y
          → Filtra solo pedidos no procesados
          → Escribe JSON en S3
          → Return { count, s3Key }
      → Choice: count > 0?
          SÍ → Lambda 2: Read S3 → For each order:
                  → ConditionalCheck DynamoDB (skip si ya existe)
                  → POST factura en Holded
                  → Update DynamoDB estado
          NO → Succeed (sin work)
      → Error: → SNS email alerta
```

### Ejemplo serverless.yml — Polling con Step Functions

```yaml
# Basado en prestashop-holded-middleware-prod — probado en producción
service: revo-solo-holded-middleware

provider:
  name: aws
  runtime: nodejs20.x
  region: eu-west-2
  memorySize: 1024
  iam:
    role:
      statements:
        - Effect: Allow
          Action: [dynamodb:PutItem, dynamodb:GetItem, dynamodb:UpdateItem]
          Resource: !GetAtt OrdersTable.Arn
        - Effect: Allow
          Action: [s3:PutObject, s3:GetObject]
          Resource: !Sub '${RawBucket.Arn}/*'
        - Effect: Allow
          Action: states:StartExecution
          Resource: !Ref SyncStateMachine

functions:
  fetchOrders:
    handler: src/handlers/fetch_orders.main
    timeout: 60

  processOrders:
    handler: src/handlers/process_orders.main
    timeout: 600

stepFunctions:
  stateMachines:
    syncStateMachine:
      name: ${self:service}-sync-${sls:stage}
      type: EXPRESS           # No STANDARD — ver step-functions-express.md
      definition:
        StartAt: FetchOrders
        States:
          FetchOrders:
            Type: Task
            Resource: !GetAtt FetchOrdersLambdaFunction.Arn
            Retry:
              - ErrorEquals: [States.ALL]
                IntervalSeconds: 3
                MaxAttempts: 2
                BackoffRate: 2.0
            Catch:
              - ErrorEquals: [States.ALL]
                Next: FalloProceso
            Next: HayPedidos
          HayPedidos:
            Type: Choice
            Choices:
              - Variable: $.count
                NumericGreaterThan: 0
                Next: ProcessOrders
            Default: SinPedidos
          ProcessOrders:
            Type: Task
            Resource: !GetAtt ProcessOrdersLambdaFunction.Arn
            Retry:
              - ErrorEquals: [States.ALL]
                IntervalSeconds: 3
                MaxAttempts: 2
                BackoffRate: 2.0
            Catch:
              - ErrorEquals: [States.ALL]
                Next: FalloProceso
            End: true
          SinPedidos:
            Type: Succeed
          FalloProceso:
            Type: Task
            Resource: arn:aws:states:::sns:publish
            Parameters:
              TopicArn: !Ref AlertaTopic
              Message.$: States.Format('Error en sync: {}', $.Cause)
            Next: ProcesoFallado
          ProcesoFallado:
            Type: Fail

resources:
  Resources:
    CronSync:
      Type: AWS::Events::Rule
      Properties:
        ScheduleExpression: 'cron(0 7 ? * * *)'  # 07:00 UTC = 09:00 España invierno
        State: ENABLED
        Targets:
          - Id: SyncStateMachine
            Arn: !Ref SyncStateMachine
            RoleArn: !GetAtt EventBridgeRole.Arn
```

---

## Decisiones específicas documentadas

### ¿date_upd o date_add para polling?

**Siempre `date_upd`** — ver ADR-7 en [[serverless-framework-v3]].

Un pedido creado hace 30 días puede pagarse hoy. `date_add` lo perdería. `date_upd` lo captura.

### ¿Lambda única o fetch + process separados?

**Separar siempre** — ver ADR-2 en [[step-functions-express]].

- Fetch: 60s timeout, falla rápido si API no responde
- Process: 600s timeout, puede procesar 500+ pedidos
- Si se juntan: un timeout en fetch deja pedidos en S3 sin procesar

### ¿Guardar en S3 entre lambdas?

**SÍ cuando hay más de ~10 pedidos**. Lambda response payload máx 6MB. S3 es ilimitado.
Coste: negligible (S3 lifecycle 30 días).

### ¿Cuándo añadir SQS?

Solo si:
- Volumen > 1.000 eventos/hora
- Necesitas retry independiente por mensaje (vs retry de todo el batch)
- Múltiples consumidores del mismo evento

Para volumen bajo-medio (< 100 pedidos/día): Step Functions es suficiente.

---

## Relaciones

- [[lambda-patterns]] — patrones TypeScript para handlers de ambas ramas
- [[step-functions-express]] — cuándo Express vs Standard, configuración real
- [[dynamodb-patterns]] — idempotencia ConditionalCheck para ambas arquitecturas
- [[serverless-framework-v3]] — IaC, patrón de 3 tiers, scripts de deploy
- [[prestashop-holded-middleware-prod]] — referencia de implementación polling validada en producción

## Proyectos donde aparece

- [[prestashop-holded-middleware-prod]] — rama polling implementada y operativa
