---
tags: [aws, step-functions, express, orquestacion, produccion]
created: 2026-05-21
source: "PROJECT_DNA.md + PROJECT_DNA_COMPLEMENT.md ADR-2 — prestashop-holded-middleware-prod"
confidence: "high — validado en producción"
---

# Step Functions Express — cuándo y cómo

#aws #step-functions #express #orquestacion

Configuración y decisiones de Step Functions extraídas de `prestashop-holded-middleware-prod`.
Express Workflows operativos desde 2026-05-15.

---

## Express vs Standard — tabla de decisión

| Criterio | Express | Standard |
|---|---|---|
| Duración máxima | 5 minutos | 1 año |
| Precio | Por invocación + duración | Por transición de estado |
| Ejecuciones concurrentes | Ilimitadas | 1M simultáneas |
| Historial de ejecución | CloudWatch Logs | Console Step Functions |
| Exactly-once | No (at-least-once) | Sí |
| Human approval / wait | No | Sí (`waitForTaskToken`) |
| Coste típico integración B2B | < €0.01/mes | €0.025/1000 transiciones |

**Regla:** Para integraciones plataforma→Holded, **siempre Express**.

```
¿El flujo necesita aprobación humana intermedia (waitForTaskToken)?
  SÍ → Standard
  NO → Express

¿El flujo puede durar más de 5 minutos?
  SÍ → Express con timeout agresivo en Lambdas internas
  NO → Express sin preocupación

¿Necesitas exactly-once garantizado?
  SÍ → Standard (o idempotencia manual en Express)
  NO → Express + ConditionalCheck DynamoDB
```

**En la práctica:** Para el patrón polling (fetch → process), Express + ConditionalCheck DynamoDB
cubre el caso "exactly-once" sin necesitar Standard. Ver [[idempotencia-dynamodb]].

---

## Configuración real — prestashop-holded-middleware-prod

```yaml
# En serverless.yml — plugin requerido
plugins:
  - serverless-step-functions    # npm install --save-dev serverless-step-functions

stepFunctions:
  stateMachines:
    syncStateMachine:
      name: ${self:service}-sync-${sls:stage}
      type: EXPRESS              # ← Crítico: no STANDARD

      # Logging obligatorio en Express — historial no visible en Console SF
      loggingConfig:
        level: ALL               # ERROR | FATAL | ALL
        includeExecutionData: true
        destinations:
          - Fn::GetAtt: [StepFunctionsLogGroup, Arn]

      definition:
        Comment: "Sync pedidos PrestaShop → Holded"
        StartAt: FetchOrders

        States:
          FetchOrders:
            Type: Task
            Resource: !GetAtt FetchOrdersPrestashopLambdaFunction.Arn
            TimeoutSeconds: 60        # Falla rápido si API PrestaShop no responde
            Retry:
              - ErrorEquals: [States.ALL]
                IntervalSeconds: 3
                MaxAttempts: 2
                BackoffRate: 2.0
            Catch:
              - ErrorEquals: [States.ALL]
                Next: FalloProceso
                ResultPath: $.error
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
            Resource: !GetAtt ProcessOrdersHoldedLambdaFunction.Arn
            TimeoutSeconds: 600       # Lambda de procesado — hasta 500 pedidos
            Retry:
              - ErrorEquals: [States.ALL]
                IntervalSeconds: 3
                MaxAttempts: 2
                BackoffRate: 2.0
            Catch:
              - ErrorEquals: [States.ALL]
                Next: FalloProceso
                ResultPath: $.error
            End: true

          SinPedidos:
            Type: Succeed
            Comment: "Nada que procesar hoy"

          FalloProceso:
            Type: Task
            Resource: arn:aws:states:::sns:publish
            Parameters:
              TopicArn: !Ref AlertaTopic
              Subject: "ERROR sync prestashop-holded"
              Message.$: States.Format('Error en sync: {}. Input: {}', $.error.Cause, States.JsonToString($))
            Next: ProcesoFallado

          ProcesoFallado:
            Type: Fail
            Error: "SyncFailed"
            Cause: "Ver SNS para detalles"
```

---

## Log Group para Express

```yaml
# Express no guarda historial en console — CloudWatch es obligatorio
resources:
  Resources:
    StepFunctionsLogGroup:
      Type: AWS::Logs::LogGroup
      Properties:
        LogGroupName: /aws/states/${self:service}-${sls:stage}
        RetentionInDays: 30        # 30 días es suficiente para debugging
```

**IAM para logging:**

```yaml
iam:
  role:
    statements:
      - Effect: Allow
        Action:
          - logs:CreateLogDelivery
          - logs:GetLogDelivery
          - logs:UpdateLogDelivery
          - logs:DeleteLogDelivery
          - logs:ListLogDeliveries
          - logs:PutResourcePolicy
          - logs:DescribeResourcePolicies
          - logs:DescribeLogGroups
        Resource: '*'    # CloudWatch Logs delivery requiere * — excepción documentada
```

---

## EventBridge trigger — cron diario

```yaml
resources:
  Resources:
    # Rol para que EventBridge invoque Step Functions
    EventBridgeRole:
      Type: AWS::IAM::Role
      Properties:
        AssumeRolePolicyDocument:
          Version: '2012-10-17'
          Statement:
            - Effect: Allow
              Principal:
                Service: scheduler.amazonaws.com   # EventBridge Scheduler
              Action: sts:AssumeRole
        Policies:
          - PolicyName: InvokeStepFunctions
            PolicyDocument:
              Version: '2012-10-17'
              Statement:
                - Effect: Allow
                  Action: states:StartExecution
                  Resource: !Ref SyncStateMachineExpress   # Ref al Step Functions

    # Cron — 09:00 España (07:00 UTC invierno)
    CronSync:
      Type: AWS::Events::Rule
      Properties:
        Name: ${self:service}-daily-sync-${sls:stage}
        Description: "Sync diario PrestaShop → Holded"
        ScheduleExpression: 'cron(0 7 ? * * *)'    # ADR-7: date_upd no date_add
        State: ENABLED
        Targets:
          - Id: SyncStateMachine
            Arn: !Ref SyncStateMachineExpress
            RoleArn: !GetAtt EventBridgeRole.Arn
            Input: '{}'            # Express ignora input de EventBridge por defecto
```

---

## ADR-2 — Por qué fetch y process en Lambdas separadas

```
Decisión: Dos Lambdas (FetchOrders + ProcessOrders) en lugar de una Lambda monolítica.

Motivo 1 — Timeouts independientes:
  - Fetch: 60s (falla rápido si API externa no responde)
  - Process: 600s (puede procesar 500+ pedidos sin timeout)
  - Con Lambda única: timeout de process = timeout de fetch. 60s = procesar solo 5 pedidos.

Motivo 2 — S3 como bus:
  - FetchOrders escribe JSON en S3, devuelve { count, s3Key }
  - ProcessOrders lee de S3
  - Lambda response payload máximo: 6MB (suficiente para ~500 pedidos)
  - Si el catálogo crece: S3 escala sin cambiar arquitectura

Motivo 3 — Retry granular:
  - Si ProcessOrders falla en el pedido 50 de 100: Step Functions reintenta ProcessOrders
  - La Lambda relee S3 y continúa (idempotencia via ConditionalCheck)
  - Lambda monolítica: reintento refetcha de API y reprocesa todo

Alternativa descartada: Lambda única con timeout 600s
  - Problema: si la API externa tarda 30s, el resto del timeout se pierde
  - Problema: fetch y process entrelazados = no se puede reintertar solo process
```

---

## Paso de datos entre estados

```typescript
// FetchOrders devuelve — Step Functions pasa esto como input a ProcessOrders
interface FetchOrdersOutput {
  count: number;      // Pedidos encontrados (HayPedidos Choice lo lee)
  s3Key: string;      // Clave S3 con JSON completo
  desde: string;      // ISO8601 — para logging
  hasta: string;      // ISO8601
}

// ProcessOrders recibe ese mismo objeto como `event`
export const main = async (event: FetchOrdersOutput): Promise<ProcessResult> => {
  await cargarSecretos();

  // Guard — Step Functions Choice ya filtra count=0, pero defensivo
  if (!event.s3Key || event.count === 0) {
    return { procesados: 0, errores: [], saltados: 0 };
  }

  // Lee de S3 — no del event (que tendría limite 6MB si fuera inline)
  const pedidos = await s3Service.leerPedidos(event.s3Key);
  // ...
};
```

---

## Costes reales — Express vs Standard

```
Volumen referencia: ~30 pedidos/día, 1 ejecución diaria

Express:
  - Invocaciones: 1/día × 30 días = 30 invocaciones
  - Duración: ~30s × 30 = 900s
  - Coste Express: $0.000025/invocación + $0.0001/GB-segundo
  - Total/mes: < $0.001

Standard:
  - Transiciones: ~5 estados × 30 días = 150 transiciones
  - Precio: $0.025/1000 transiciones
  - Total/mes: < $0.005

Diferencia: negligible. Razón real para Express: ilimitado concurrente + logging más simple.
```

---

## Errores comunes

| Error | Causa | Fix |
|---|---|---|
| `States.Runtime` en FetchOrders | Lambda timeout < tiempo API externa | Subir `TimeoutSeconds` en la Step Function state (no en Lambda) |
| Express historial vacío en Console | Express no guarda en UI — solo CloudWatch | Revisar `/aws/states/{service}-{stage}` en CloudWatch Logs |
| `InvalidArn` en SNS publish | ARN construido mal en `FalloProceso` | `!Ref AlertaTopic` no `!GetAtt AlertaTopic.Arn` para SNS |
| Step Functions no arranca | IAM de EventBridge falta `states:StartExecution` | Añadir Action al EventBridgeRole |

---

## Relaciones

- [[architecture-decision-tree]] — cuándo usar Step Functions vs Lambda directa
- [[lambda-patterns]] — estructura de los handlers FetchOrders y ProcessOrders
- [[dynamodb-patterns]] — idempotencia ConditionalCheck en ProcessOrders
- [[serverless-framework-v3]] — IaC completa con Step Functions integrado
- [[prestashop-holded-middleware-prod]] — implementación de referencia operativa

## Proyectos donde aparece

- [[prestashop-holded-middleware-prod]] — Express Workflows operativos desde 2026-05-15
