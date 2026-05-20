---
tags: [error-resuelto, serverless, cloudformation, lambda, panel]
created: 2026-05-20
project: prestashop-holded-middleware-prod
fuente: PROJECT_DNA.md §9 E6, PROJECT_DNA_COMPLEMENT.md ADR-8
---

# E6 — panelRouter Lambda sin Function URL en tier Basic

#error-resuelto #serverless #cloudformation #lambda

## Síntoma

Al intentar condicionar el despliegue de la Lambda `panelRouter` con `ENABLE_PANEL=false`, Serverless Framework v3 fallaba o la Lambda se desplegaba igualmente sin su Function URL.

## Causa raíz

**Limitación de Serverless Framework v3**: las funciones Lambda no pueden condicionarse con CloudFormation Conditions. Solo los recursos custom (definidos en `resources:`) aceptan `Condition`.

Intento fallido:
```yaml
# ❌ NO funciona en Serverless v3
functions:
  panelRouter:
    condition: PanelEnabled  # Serverless ignora esto
    handler: ...
```

## Solución aplicada (ADR-8)

Desplegar la Lambda `panelRouter` **siempre**, pero condicionar solo su Function URL y los recursos de CloudFront:

```yaml
# ✅ La Lambda siempre existe
functions:
  panelRouter:
    handler: src/core/handlers/mapping_panel_handler.router
    timeout: 600

# ✅ Los recursos de acceso son condicionales
resources:
  Conditions:
    PanelEnabled: !Equals
      - ${env:ENABLE_PANEL, 'false'}
      - 'true'

  Resources:
    PanelRouterFunctionUrl:
      Condition: PanelEnabled
      Type: AWS::Lambda::Url
      ...
    PanelDistribution:
      Condition: PanelEnabled
      Type: AWS::CloudFront::Distribution
      ...
```

**Resultado**: La Lambda existe en todos los tiers pero es inalcanzable sin su URL/trigger. Coste: €0 sin invocaciones.

## Corrección crítica sobre ADR-3

La configuración final del panel usa `AuthType: NONE` en la Function URL (URL pública).
CloudFront OAC+SigV4 fue descartado por un bug de AWS: las peticiones POST/PUT envían `UNSIGNED-PAYLOAD` en el header de autenticación, rompiendo la firma SigV4.

**CLAUDE.md del proyecto documenta `AuthType: AWS_IAM` incorrectamente. El `serverless.yml` es la fuente de verdad.**

Ver también: [[holded]] sección Panel de administración

## Patrón reutilizable

→ Ver [[patron-3-tiers]] para el patrón completo de features opcionales con CloudFormation Conditions.

## Proyecto donde ocurrió

[[prestashop-holded-middleware-prod]]
