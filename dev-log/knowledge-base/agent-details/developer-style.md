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
