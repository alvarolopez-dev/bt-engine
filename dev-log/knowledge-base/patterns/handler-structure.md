---
tags: [patron, lambda, typescript, handler, arquitectura]
created: 2026-05-20
project: prestashop-holded-middleware-prod
fuente: PROJECT_DNA.md §3 §6 P1, PROJECT_DNA_COMPLEMENT.md ADR-5 ADR-6
---

# Patrón — Estructura de handler Lambda

#patron #lambda #typescript #handler

Estructura obligatoria para todos los handlers Lambda del ecosistema Bigtoone.
Todos los handlers del proyecto de referencia siguen este orden sin excepción.

## Los 4 pasos en orden fijo

```
1. cargarSecretos()     ← siempre primero, con caché de warm start
2. Guard defensivo      ← early return si no hay trabajo
3. Lógica principal     ← con manejo de errores por ítem
4. Return summary       ← nunca void, siempre objeto con resultado
```

## Implementación validada

```typescript
// ── SINGLETONS A NIVEL DE MÓDULO (warm start) ────────────────────────────────
// Se crean UNA SOLA VEZ cuando Lambda carga el módulo.
// En ejecuciones warm persisten — no se recrean en cada invocación.
const holdedService    = new HoldedService();
const s3Service        = new S3Service();
export const ordersService = new DynamoOrdersService();

// ── HANDLER ──────────────────────────────────────────────────────────────────
export const main = async (event: FetchOrdersEvent, _context: Context): Promise<FetchOrdersResult> => {

  // ── 1. CARGAR SECRETOS ───────────────────────────────────────────────────
  await cargarSecretos(); // con caché — ver patrón de secrets abajo

  // ── 2. GUARD DEFENSIVO ───────────────────────────────────────────────────
  if (!event.s3Key || event.count === 0) {
    logger.info({ event }, 'Sin pedidos que procesar — saliendo');
    return { procesados: 0, errores: [], skipped: 0 };
  }

  // ── 3. LÓGICA PRINCIPAL CON ERRORES POR ÍTEM ────────────────────────────
  const errores: string[] = [];
  let procesados = 0;

  for (const pedido of pedidos) {
    try {
      await procesarPedido(pedido);
      procesados++;
    } catch (error: unknown) {
      const mensaje = error instanceof Error ? error.message : String(error);
      errores.push(`Pedido ${pedido.id}: ${mensaje}`);
      // No propagamos — los demás pedidos del batch siguen procesándose
    }
  }

  // ── 4. RETURN SUMMARY ────────────────────────────────────────────────────
  return { procesados, errores, total: pedidos.length };
};
```

## Patrón de secrets con caché

Crítico para el rendimiento en warm starts (una Lambda puede procesar miles de invocaciones antes de un cold start):

```typescript
const secretsClient = new SecretsManagerClient({ region: process.env.AWS_REGION });
let secretosCargados = false;

export async function cargarSecretos(): Promise<void> {
  if (secretosCargados) return; // no repetir en ejecuciones warm

  if (!process.env.SECRETS_MANAGER_SECRET_NAME) {
    secretosCargados = true;
    return; // local: usa .env directamente
  }

  const response = await secretsClient.send(
    new GetSecretValueCommand({ SecretId: process.env.SECRETS_MANAGER_SECRET_NAME })
  );
  const secrets = JSON.parse(response.SecretString!) as Record<string, string>;
  for (const [k, v] of Object.entries(secrets)) process.env[k] = v;
  secretosCargados = true;
}
```

## Regla de singletons (P1 del DNA)

Los clientes y servicios se instancian **fuera del handler**, al nivel del módulo.
Dentro del handler: solo uso, nunca `new`.

```typescript
// ✅ CORRECTO — se crea una vez por cold start
const holdedService = new HoldedService(); // fuera del handler

// ❌ INCORRECTO — se crea en cada invocación (incluso warm)
export const main = async () => {
  const holdedService = new HoldedService(); // coste innecesario
};
```

## Validación con Zod (ADR-5)

Validar en la frontera — donde llegan datos externos. A partir de ahí, el tipo está garantizado:

```typescript
const validacion = StandardOrderSchema.safeParse(pedidoExterno);
if (!validacion.success) {
  const erroresZod = validacion.error.issues.map(i => i.message).join(', ');
  throw new Error(`Validación fallida: ${erroresZod}`);
}
const pedido = validacion.data; // StandardOrder tipado garantizado
```

## Los 3 niveles de manejo de errores

| Nivel | Cuándo | Comportamiento |
|-------|--------|---------------|
| Fatal | Configuración esencial falta | `throw new Error('CONFIG_ERROR: ...')` — interrumpe todo |
| Por ítem | Fallo de un elemento del batch | `try/catch` → push a errores → continúa con el siguiente |
| Degradación | Feature opcional falla | `try/catch` → `log.warn` → continúa sin la feature |

Ver [[degradacion-silenciosa]] para el nivel 3 en detalle.

## Proyectos donde se validó

- [[prestashop-holded-middleware-prod]] — 4 handlers siguiendo este patrón en producción
