---
tags: [error, serverless-framework, nodejs, runtime]
created: 2026-05-28
plataforma: AWS Lambda + Serverless Framework v3
---

# Error: nodejs22.x no soportado por Serverless Framework v3

## Síntoma

Validación local falla al intentar usar `nodejs22.x` como runtime con SF v3.
SF v3 reconoce hasta `nodejs20.x` como runtime válido en su esquema interno.

## Causa raíz

Serverless Framework v3 tiene lista fija de runtimes válidos.
`nodejs22.x` no está en esa lista — requiere SF v4 o AWS CDK para usarlo.

## Runtime correcto con SF v3

```yaml
# serverless.yml
provider:
  runtime: nodejs20.x   # ✅ máximo soportado por SF v3
```

## Si necesitas nodejs22.x

Migrar a Serverless Framework v4 o AWS CDK.
Ver `[[architecture-decision-tree]]` antes de migrar.

## Historial del error en bt-engine

En la sesión de 2026-05-26 se invirtió la fuente de verdad por error:
- `00_CONSTRAINTS.md` se actualizó a nodejs22.x (INCORRECTO)
- El commit `4516869` propagó nodejs22.x como runtime "correcto"
- Corregido el 2026-05-28: todos los ficheros vuelven a nodejs20.x

**Fuente de verdad:** `nodejs20.x` con SF v3. Sin excepción.
