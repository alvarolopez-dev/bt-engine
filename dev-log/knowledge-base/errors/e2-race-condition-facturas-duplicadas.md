---
tags: [error-resuelto, dynamodb, lambda, idempotencia, race-condition]
created: 2026-05-20
project: prestashop-holded-middleware-prod
fuente: PROJECT_DNA.md §9 E2, §6 P6
---

# E2 — Race condition: facturas duplicadas en Holded

#error-resuelto #dynamodb #idempotencia #race-condition

## Síntoma

Dos facturas idénticas creadas en [[holded]] para el mismo pedido.
El pedido aparecía dos veces en Holded con el mismo número de pedido de [[prestashop]].

## Causa raíz

El patrón **check-then-insert** tiene race condition cuando dos invocaciones de Lambda corren en paralelo:

```
Lambda A: lee DynamoDB → pedido 404 no existe → decide crear
Lambda B: lee DynamoDB → pedido 404 no existe → decide crear
Lambda A: llama a Holded → crea factura F-001
Lambda B: llama a Holded → crea factura F-002  ← DUPLICADO
Lambda A: escribe DynamoDB → pedido 404 = invoice_created
Lambda B: escribe DynamoDB → pedido 404 = invoice_created (sobreescribe)
```

Esto ocurre cuando Step Functions reintenta una ejecución fallida o cuando hay concurrencia.

## Solución aplicada

Reemplazar check-then-insert por **operación atómica con `ConditionalExpression`**:

```typescript
await docClient.send(new PutCommand({
  TableName: process.env.DYNAMODB_TABLE_ORDERS!,
  Item: { id_pedido_tienda: pedido.id, estado: 'pending_upload', ... },
  ConditionExpression: 'attribute_not_exists(id_pedido_tienda)'
}));
```

Si el pedido ya existe en DynamoDB, DynamoDB lanza `ConditionalCheckFailedException`.
Este error se trata como **warn**, no como error de negocio:

```typescript
if (error instanceof ConditionalCheckFailedException) {
  log.warn({ idPedido }, 'Pedido registrado por otro proceso en paralelo — ignorando');
  return; // Idempotencia funcionando correctamente
}
```

## Por qué funciona

La operación `PutItem` con `attribute_not_exists` es atómica en DynamoDB.
Solo una de las dos Lambdas puede ganar la escritura. La otra recibe `ConditionalCheckFailedException`.
La que pierde la escritura sabe que el pedido ya está siendo procesado — no hay duplicado.

## Patrón documentado

→ Ver [[idempotencia-dynamodb]] para el patrón completo reutilizable.

## Plataformas involucradas

- [[holded]] — donde aparecen las facturas duplicadas
- DynamoDB como mecanismo de idempotencia

## Proyecto donde ocurrió

[[prestashop-holded-middleware-prod]]
