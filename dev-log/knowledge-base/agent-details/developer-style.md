---
tags: [developer, style, typescript]
created: 2026-05-25
extraído-de: agents/05_agent_developer.md §10
---

# Developer Style Guide — Naming, comentarios y estilo

#developer #style #typescript

[[index]] [[05_agent_developer]]

Guía de estilo del proyecto. Naming, idioma, comentarios, validación.
Extraído de `agents/05_agent_developer.md §10` para reducir peso del agente.

---

## Naming

```
Ficheros:              snake_case.ts               fetch_orders_prestashop.ts
Clases y tipos:        PascalCase                   HoldedService, StandardOrder
Variables y funciones: camelCase                    idPedidoTienda, obtenerCuentasPorSku
Constantes de módulo:  UPPER_SNAKE_CASE             ENABLE_ACCOUNTING, ORDER_PAID_STATE_ID
Campos DynamoDB/JSON:  snake_case                   id_pedido_tienda, holded_account_id
```

---

## Idioma

```
Dominio de negocio:    español    pedido, factura, cuenta, procesarPedido()
Logs y mensajes:       español    "Factura creada", "Error procesando pedido"
Recursos AWS y config: inglés     OrdersTable, ENABLE_ACCOUNTING, fetchOrdersPrestashop
```

---

## Comentarios — el estándar del proyecto

```typescript
// ── SEPARADORES VISUALES para secciones de lógica ────────────────────────
// ── A. CARGAR SECRETOS ────────────────────────────────────────────────────
// ── B. OBTENER PEDIDOS DE S3 ──────────────────────────────────────────────

// JSDoc en servicios compartidos — no en handlers
/**
 * Busca un contacto por su código de PrestaShop usando paginación.
 * Solo descarga páginas hasta encontrar el contacto o agotar el límite.
 * @param code - El ID del cliente en PrestaShop (campo 'code' en Holded)
 */

// Comentarios pedagógicos en lógica no obvia
// IMPORTANTE: La API de Holded necesita el ID INTERNO (cadena de 24 chars),
// no el número de cuenta que ves en pantalla (ej: NO usar "700").
// Si envías un número normal, Holded lo ignora silenciosamente.

// No puedes comprar medio pantalón
.int("La cantidad debe ser entera")

// Si es gratis (0€), no hay factura de venta
.positive("El total pagado debe ser positivo")
```

---

## TypeScript utility types — APIs externas y DynamoDB

Patrones de composición de tipos para modelos de integraciones. No usar `any`; componer desde el tipo base.

```typescript
// Tipo base de plataforma externa
type HoldedContacto = {
  id: string;
  nombre: string;
  email: string;
  nif: string;
  createdAt: string;
};

// PATCH payload — campos editables sin id ni timestamps
type PatchContactoPayload = Omit<Partial<HoldedContacto>, 'id' | 'createdAt'>;
// → { nombre?: string; email?: string; nif?: string }

// Respuesta API con solo campos necesarios (evita traer datos sensibles)
type ContactoResumen = Pick<HoldedContacto, 'id' | 'nombre'>;

// Webhook con claves dinámicas (batch status, por ejemplo)
type BatchStatusWebhook = Record<string, 'pending' | 'processed' | 'failed'>;

// Campo nullable de API externa → forzar a no-null antes de usar
function procesarEmail(email: NonNullable<HoldedContacto['email']>) { ... }

// DynamoDB item debe tener todos los campos presentes (al escribir)
type DynamoOrderItem = Required<StandardOrder>;

// Forzar retorno completo del handler (sin campos opcionales olvidados)
type HandlerResponse = Required<Pick<SyncResult, 'procesados' | 'errores' | 'saltados'>>;
```

**Combinación más usada en integraciones:**
```typescript
// Modelo de actualización parcial de API externa
type UpdatePayload<T, Immutable extends keyof T = 'id' | 'createdAt'> =
  Omit<Partial<T>, Immutable>;
```

---

## tsconfig.json — configuración oficial para Lambda nodejs20.x

```json
{
  "compilerOptions": {
    "target": "es2022",
    "strict": true,
    "preserveConstEnums": true,
    "noEmit": true,
    "sourceMap": false,
    "module": "commonjs",
    "moduleResolution": "node",
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "isolatedModules": true
  },
  "exclude": ["node_modules", "**/*.test.ts"]
}
```

**Campos clave:**
- `"noEmit": true` — si usas esbuild para compilar, tsc solo chequea tipos (no emite JS)
- `"isolatedModules": true` — requerido por esbuild; cada fichero transpilable sin contexto global
- `"target": "es2022"` — nodejs20.x soporta ES2022
- `"strict": true` — obligatorio en bt-engine (R-CODE-4)

**Flujo con esbuild (futuro):**
```bash
tsc --noEmit     # type check sin compilar
esbuild src/handlers/fetch_orders.ts --bundle --platform=node --target=node20 --outdir=dist
```

**Flujo actual (serverless-plugin-typescript):**
```bash
sls deploy  # serverless-plugin-typescript llama a tsc internamente — esbuild no usado
```

---

## Validación con Zod — solo en la frontera

```typescript
// Zod valida en el punto de entrada al sistema — donde llegan datos externos.
// A partir de ahí, el tipo está garantizado y no se vuelve a validar.

const validacion = StandardOrderSchema.safeParse(pedidoExterno);
if (!validacion.success) {
  const erroresZod = validacion.error.issues.map(i => i.message).join(', ');
  throw new Error(`Validación fallida: ${erroresZod}`);
}
const pedido = validacion.data; // A partir de aquí: StandardOrder tipado garantizado
```

---

*Extraído de agents/05_agent_developer.md §10 — 2026-05-25*
*Ver agente reducido en [[05_agent_developer]] tras refactorización COMMIT 4*
