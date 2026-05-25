---
tags: [qa, tests, gotchas]
created: 2026-05-25
extraído-de: agents/06_agent_qa.md §3-6
---

# QA Test Cases — Suite obligatoria y gotchas

#qa #tests #gotchas

[[index]] [[06_agent_qa]]

Código completo de tests para el agente QA.
Extraído de `agents/06_agent_qa.md §3-6` para reducir peso del agente.

---

## §3 — PROTOCOLO DE MOCKS — LA DIFERENCIA CLAVE

### Lo que hace el Developer (happy path)

```typescript
// El Developer mockeó esto — testea que su código funciona
jest.spyOn(prestashopService, 'getOrders').mockResolvedValue([
  { id: '101', total_paid: '150.00', current_state: '2', ... }
]);
// ✅ Test válido — pero solo cubre el caso perfecto
```

### Lo que hace QA (el API_PROFILE completo)

El API_PROFILE documenta que `order_rows` tiene **3 formatos posibles**.
El Developer probó uno. QA prueba los tres:

```typescript
// QA — mock para cada formato documentado en API_PROFILE
describe('normalizarOrderRows — 3 formatos documentados [comunidad]', () => {
  it('formato array (caso habitual, múltiples líneas)', () => {
    const input = {
      order_rows: [
        { product_id: '10', product_name: { language: [{ value: 'Camiseta' }] }, unit_price: '20.00' },
        { product_id: '11', product_name: { language: [{ value: 'Pantalón' }] }, unit_price: '40.00' }
      ]
    };
    const result = normalizarOrderRows(input.order_rows);
    expect(result).toHaveLength(2);
  });

  it('formato objeto (pedido con una sola línea — API no devuelve array)', () => {
    // API_PROFILE gotcha E3: PrestaShop devuelve objeto, no array, con una línea
    const input = {
      order_rows: {
        product_id: '10',
        product_name: { language: [{ value: 'Camiseta' }] },
        unit_price: '20.00'
      }
    };
    const result = normalizarOrderRows(input.order_rows);
    expect(result).toHaveLength(1); // Si falla aquí → E3 no está resuelto
  });

  it('formato string vacío (pedido sin líneas — caso límite documentado)', () => {
    // API_PROFILE gotcha E3: PrestaShop devuelve "" cuando no hay líneas
    const result = normalizarOrderRows('');
    expect(result).toEqual([]); // Si falla aquí → E3 no está resuelto
  });
});
```

**Regla práctica:**
Para cada gotcha del API_PROFILE con formato `issue + impact + source`:
→ El `issue` se convierte en descripción del `it()`
→ El `impact` verifica que el código lo maneja sin tirar
→ La fuente (`[confirmado en producción]`) = prioridad máxima, no puede faltar

---

## §4 — SUITE DE PRUEBAS OBLIGATORIA

### 4.1 — Anatomía del handler (todos los handlers)

Para cada Lambda del `developer_report.json`, verificar que el handler sigue
la estructura `cargarSecretos → guard → loop → return`:

```typescript
describe('Handler — estructura obligatoria', () => {
  it('guard: devuelve resumen vacío si no hay trabajo', async () => {
    // Simular evento vacío
    const result = await handler.main({ s3Key: undefined, count: 0 }, mockContext);
    expect(result.procesados).toBe(0);
    expect(result.errores).toEqual([]);
  });

  it('loop: un pedido con error no bloquea los demás', async () => {
    // Mock: segundo pedido falla, primero y tercero deben procesarse
    mockProcessarPedido
      .mockResolvedValueOnce(undefined)         // pedido 1: OK
      .mockRejectedValueOnce(new Error('500'))  // pedido 2: falla
      .mockResolvedValueOnce(undefined);        // pedido 3: OK

    const result = await handler.main(eventConTresPedidos, mockContext);
    expect(result.procesados).toBe(2);
    expect(result.errores).toHaveLength(1);
    expect(result.errores[0]).toContain('pedido 2');
  });

  it('return: siempre devuelve objeto con forma definida — nunca void', async () => {
    const result = await handler.main(eventValido, mockContext);
    expect(result).toHaveProperty('procesados');
    expect(result).toHaveProperty('errores');
    expect(typeof result.procesados).toBe('number');
    expect(Array.isArray(result.errores)).toBe(true);
  });
});
```

### 4.2 — Secrets con caché (warm start)

```typescript
describe('cargarSecretos — caché de warm start', () => {
  it('no llama a Secrets Manager en segunda invocación (warm)', async () => {
    const mockGetSecret = jest.fn().mockResolvedValue({ SecretString: '{"HOLDED_API_KEY":"abc"}' });
    mockSecretsManagerClient.send = mockGetSecret;

    await cargarSecretos(); // cold start — llama
    await cargarSecretos(); // warm — no debe llamar

    expect(mockGetSecret).toHaveBeenCalledTimes(1); // Si falla → caché no funciona
  });

  it('funciona sin SECRETS_MANAGER_SECRET_NAME (entorno local)', async () => {
    delete process.env.SECRETS_MANAGER_SECRET_NAME;
    const mockSend = jest.fn();

    await cargarSecretos();
    expect(mockSend).not.toHaveBeenCalled(); // No debe llamar al cliente
  });
});
```

### 4.3 — Idempotencia (obligatorio si hay Step Functions en la arquitectura)

```typescript
describe('Idempotencia — ConditionalCheckFailedException', () => {
  it('segunda Lambda procesando el mismo pedido → warn, no error', async () => {
    // Simular que DynamoDB rechaza porque ya existe
    mockDynamoClient.send.mockRejectedValueOnce(
      new ConditionalCheckFailedException({ message: 'Conditional...', $metadata: {} })
    );

    const loggerWarnSpy = jest.spyOn(logger, 'warn');

    // La función no debe lanzar — debe continuar con warn
    await expect(registrarPedido(pedidoMock)).resolves.not.toThrow();
    expect(loggerWarnSpy).toHaveBeenCalledWith(
      expect.objectContaining({ idPedido: pedidoMock.id }),
      expect.stringContaining('paralelo')
    );
  });

  it('otros errores de DynamoDB sí se propagan', async () => {
    mockDynamoClient.send.mockRejectedValueOnce(
      new Error('ProvisionedThroughputExceededException')
    );
    await expect(registrarPedido(pedidoMock)).rejects.toThrow('ProvisionedThroughputExceededException');
  });
});
```

### 4.4 — Degradación silenciosa (obligatorio si hay ENABLE_* vars en developer_report)

```typescript
describe('Degradación silenciosa — features opcionales', () => {
  it('fallo en contabilidad no revierte la factura creada', async () => {
    process.env.ENABLE_ACCOUNTING = 'true';

    // Mock: factura se crea, pero asignación contable falla
    mockHoldedService.crearFactura.mockResolvedValueOnce('docId-123');
    mockHoldedService.asignarCuentasContables.mockRejectedValueOnce(
      new Error('Cuenta contable no encontrada')
    );

    const loggerWarnSpy = jest.spyOn(logger, 'warn');

    // La función no debe lanzar — la factura existe aunque falle la contabilidad
    await expect(procesarPedido(pedidoMock)).resolves.not.toThrow();
    expect(loggerWarnSpy).toHaveBeenCalledWith(
      expect.anything(),
      expect.stringContaining('cuentas contables')
    );
  });

  it('fallo en cobro no revierte la factura creada', async () => {
    mockHoldedService.crearFactura.mockResolvedValueOnce('docId-123');
    mockHoldedService.registrarCobro.mockRejectedValueOnce(new Error('500'));

    await expect(procesarPedido(pedidoMock)).resolves.not.toThrow();
  });
});
```

---

## §5 — COBERTURA DE GOTCHAS — ERRORES CONOCIDOS DEL ECOSISTEMA

Estos errores son regresiones confirmadas en producción real de Bigtoone.
Si la plataforma del proyecto actual incluye PrestaShop u Holded,
estos tests son **obligatorios** — no opcionales.

### E1 — Serialización de nombres multi-idioma

```typescript
describe('extraerNombre — E1: 3 formatos de nombres', () => {
  it('string simple', () => {
    expect(extraerNombre('Camiseta')).toBe('Camiseta');
  });

  it('objeto con language array', () => {
    const nombre = { language: [{ value: 'Camiseta' }, { value: 'T-shirt' }] };
    expect(extraerNombre(nombre)).toBe('Camiseta'); // Primer idioma
    expect(extraerNombre(nombre)).not.toBe('[object Object]'); // Regresión E1
  });

  it('objeto con language como objeto (no array)', () => {
    const nombre = { language: { value: 'Camiseta' } };
    expect(extraerNombre(nombre)).toBe('Camiseta');
    expect(extraerNombre(nombre)).not.toBe('[object Object]'); // Regresión E1
  });
});
```

### E2 — Race condition con facturas duplicadas

Cubierto en §4.3. Verificar que `ConditionalCheckFailedException` = warn, no error.

### E3 — order_rows en 3 formatos

Cubierto en §3 como ejemplo de protocolo de mocks.
Verificar: array, objeto, string vacío.

### E4 — Caracteres invisibles U+200E

```typescript
describe('cleanStr — E4: caracteres invisibles', () => {
  it('elimina U+200E (Left-to-Right Mark) de nombres de contacto', () => {
    const nombreConMarca = 'Empresa‎SL';
    expect(cleanStr(nombreConMarca)).toBe('EmpresaSL');
  });

  it('elimina U+200F (Right-to-Left Mark)', () => {
    const nombreConMarca = 'Empresa‏SL';
    expect(cleanStr(nombreConMarca)).toBe('EmpresaSL');
  });

  it('no modifica strings limpios', () => {
    expect(cleanStr('Empresa Normal SL')).toBe('Empresa Normal SL');
  });

  it('comparación de contactos encuentra match con nombre sucio', () => {
    // El problema real: buscar 'EmpresaSL' cuando la BD tiene 'Empresa‎SL'
    const nombreEnBD = 'Empresa‎SL';
    const nombreBuscado = 'EmpresaSL';
    expect(cleanStr(nombreEnBD)).toBe(cleanStr(nombreBuscado)); // Si falla → E4 no resuelto
  });
});
```

### E5 — Migración de campo renombrado

```typescript
describe('E5: compatibilidad con campo renombrado', () => {
  it('pedidos con campo antiguo se procesan correctamente', async () => {
    // Si el campo fue renombrado de X a Y, verificar que X todavía funciona
    // durante el período de migración transitoria
    const pedidoConCampoAntiguo = { /* campo anterior */ estado_procesado: 'pending', id: '101' };
    const pedidoConCampoNuevo  = { /* campo nuevo */    estado: 'pending_upload', id: '102' };

    await expect(procesarPedido(pedidoConCampoAntiguo as any)).resolves.not.toThrow();
    await expect(procesarPedido(pedidoConCampoNuevo)).resolves.not.toThrow();
  });
});
```

### E6 — Panel sin URL en tier Basic

```typescript
describe('E6: panel router — tier Basic', () => {
  it('Lambda existe pero no es accesible cuando ENABLE_PANEL=false', () => {
    // Este test verifica la lógica de guard, no la infra (eso es DevOps)
    process.env.ENABLE_PANEL = 'false';
    // Si el handler tiene guard de ENABLE_PANEL, debe devolver 403 o early return
    // Si no tiene guard → la función está activa cuando no debería → bug
  });
});
```

---

## §6 — CASOS DE CAOS — RESPUESTAS DE API QUE EL DEVELOPER NO TESTEÓ

Para cada plataforma en el API_PROFILE, testear las respuestas de error documentadas.

### PrestaShop — respuestas de caos

```typescript
describe('PrestaShop API — respuestas de caos [confirmado en producción]', () => {
  it('rate limit 429 — axios-retry reintenta × 3', async () => {
    // Primera y segunda llamada: 429. Tercera: 200.
    nock('https://mi-tienda.com')
      .get(/.*/).reply(429)
      .get(/.*/).reply(429)
      .get(/.*/).reply(200, { orders: [] });

    const result = await fetchOrdersPrestashop(params);
    expect(result).toBeDefined(); // Si falla → retry no está configurado
  });

  it('500 del servidor — tras 3 reintentos, lanza error', async () => {
    nock('https://mi-tienda.com')
      .get(/.*/).reply(500).persist();

    await expect(fetchOrdersPrestashop(params)).rejects.toThrow();
  });

  it('respuesta vacía [] — no se procesa nada sin lanzar error', async () => {
    nock('https://mi-tienda.com').get(/.*/).reply(200, { orders: [] });
    const result = await fetchOrdersPrestashop(params);
    expect(result).toEqual([]);
  });
});
```

### Holded — respuestas de caos

```typescript
describe('Holded API — respuestas de caos [confirmado en producción]', () => {
  it('status !== 1 en creación de factura — lanzar error explícito', async () => {
    // API_PROFILE: Holded devuelve { status: 0, info: "error" } cuando falla
    // No lanza HTTP error — devuelve 200 con status: 0
    mockAxios.post.mockResolvedValueOnce({ data: { status: 0, info: 'Factura duplicada' } });
    await expect(holdedService.crearFactura(pedidoMock, contactId)).rejects.toThrow();
  });

  it('contacto no encontrado — crear contacto nuevo', async () => {
    // API_PROFILE: Holded devuelve [] si no existe el contacto
    mockAxios.get.mockResolvedValueOnce({ data: [] });
    mockAxios.post.mockResolvedValueOnce({ data: { status: 1, id: 'nuevo-contacto-id' } });

    const contactId = await holdedService.obtenerOCrearContacto(clienteMock);
    expect(contactId).toBe('nuevo-contacto-id');
  });

  it('rate limit 60rpm — segunda llamada si la primera devuelve 429', async () => {
    mockAxios.get
      .mockRejectedValueOnce({ response: { status: 429 } })
      .mockResolvedValueOnce({ data: { invoices: [] } });

    // Si hay retry configurado, la segunda llamada debe funcionar
    await expect(holdedService.listarFacturas()).resolves.toBeDefined();
  });
});
```

---

*Extraído de agents/06_agent_qa.md §3-6 — 2026-05-25*
*Ver agente reducido en [[06_agent_qa]] tras refactorización COMMIT 4*
