---
tags: [patron, arquitectura, tiers, serverless, feature-flags]
created: 2026-05-20
project: prestashop-holded-middleware-prod
fuente: PROJECT_DNA_COMPLEMENT.md §4, PROJECT_DNA.md §6 P4
---

# Patrón — 3 tiers comerciales con variables de entorno

#patron #arquitectura #tiers #feature-flags

Implementa features opcionales como tiers comerciales controlados **exclusivamente por variables de entorno**.
No requiere código diferente por tier. Un solo `serverless.yml`.

Ver error relacionado: [[e6-panel-router-sin-url]]

## Los 3 tiers del proyecto de referencia

| Tier | Variables | Features |
|------|-----------|---------|
| **Basic** | `ENABLE_PANEL=false`, `ENABLE_PRODUCT_SYNC=false` | Sync automático + alertas |
| **Pro** | `ENABLE_PANEL=true`, `ENABLE_PRODUCT_SYNC=false` | + Panel de mapeo contable |
| **Pro+** | `ENABLE_PANEL=true`, `ENABLE_PRODUCT_SYNC=true` | + Sync catálogo productos Holded |

## Los 3 tipos de gate — cuál usar en cada caso

### Tipo 1 — Gate de infraestructura (CloudFormation Condition)

Usar cuando la feature **crea recursos AWS** (Lambda URL, CloudFront, SQS, etc.)

```yaml
# serverless.yml
custom:
  enablePanel: ${env:ENABLE_PANEL, 'false'}

resources:
  Conditions:
    PanelEnabled: !Equals
      - ${env:ENABLE_PANEL, 'false'}
      - 'true'

  Resources:
    PanelRouterFunctionUrl:
      Condition: PanelEnabled
      Type: AWS::Lambda::Url
      Properties:
        AuthType: NONE
        TargetFunctionArn: !GetAtt PanelRouterLambdaFunction.Arn

    PanelDistribution:
      Condition: PanelEnabled
      Type: AWS::CloudFront::Distribution
      ...
```

> ⚠️ **Limitación Serverless v3**: las funciones Lambda NO pueden condicionarse directamente. Solo los recursos en `resources:` aceptan `Condition`. Solución: siempre desplegar la Lambda, condicionar solo su trigger/URL. Ver [[e6-panel-router-sin-url]].

### Tipo 2 — Gate de código (lectura de env var a nivel de módulo)

Usar cuando la feature **no crea recursos AWS** — es solo lógica en código.

```typescript
// Al inicio del módulo — fuera del handler, se lee UNA SOLA VEZ al arrancar Lambda
const ENABLE_PRODUCT_SYNC = process.env.ENABLE_PRODUCT_SYNC === 'true';
const ENABLE_ACCOUNTING   = process.env.ENABLE_ACCOUNTING   === 'true';

// Dentro del handler:
if (ENABLE_PRODUCT_SYNC) {
  const holdedProductIds = await resolverHoldedProductIds(lineas, holdedService);
  // aplicar productIds a líneas de factura
}
```

### Tipo 3 — Gate de degradación (try/catch con log.warn)

Usar cuando la feature **es opcional y no debe romper el flujo principal**.

Ver [[degradacion-silenciosa]] para implementación completa.

## Invariante del patrón

La feature opcional **nunca rompe el flujo base**:
- Si la infra no se despliega: el stack base funciona igual
- Si el código falla: `try/catch` → `log.warn` → el pedido se procesa igualmente
- Si el tier no está habilitado: la Lambda existe pero no es alcanzable → coste €0

## Checklist para añadir una nueva feature opcional

```
[ ] 1. Definir la env var: ENABLE_NUEVA_FEATURE=false (default siempre false)
[ ] 2. Añadir a .env.example con documentación y tier correspondiente
[ ] 3. Si crea recursos AWS: añadir Condition en serverless.yml + aplicarla a cada recurso
[ ] 4. Si es solo código: leer env var al nivel de módulo (fuera del handler)
[ ] 5. Envolver la lógica opcional en try/catch con degradación explícita
[ ] 6. Documentar en README (tabla de tiers + sección de variables)
[ ] 7. Documentar en CLAUDE.md sección Variables de entorno
```

## Variables de feature-flag del proyecto de referencia

| Variable | Default | Tipo de gate | Tier |
|----------|---------|-------------|------|
| `ENABLE_PANEL` | `false` | Infraestructura + código | Pro |
| `ENABLE_ACCOUNTING` | `false` | Solo código | Pro (implícito) |
| `ENABLE_PRODUCT_SYNC` | `false` | Solo código | Pro+ |

## Proyectos donde se validó

- [[prestashop-holded-middleware-prod]] — 3 tiers en producción desde 2026-05-15
