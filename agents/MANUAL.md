Conecta cualquier plataforma empresarial con cualquier otra. En un día.

---

# Manual de uso — Bigtoone Agent Ecosystem

---

## 1. Qué es esto

Este ecosistema crea integraciones entre plataformas empresariales usando agentes IA especializados.
Tú describes qué quieres conectar en lenguaje natural.
Los agentes investigan, presupuestan, programan, prueban y despliegan por ti.

---

## 2. Antes de empezar

Necesitas cuatro cosas instaladas:

- **Claude Code** — [claude.ai/code](https://claude.ai/code)
- **Node.js 20+** — [nodejs.org](https://nodejs.org)
- **Obsidian** (para ver el conocimiento acumulado) — [obsidian.md](https://obsidian.md)
- Este repositorio clonado y configurado:

```bash
git clone https://github.com/alvarolopez-dev/bt-engine.git
cd bt-engine
./setup.sh
```

`setup.sh` instala los dos MCPs necesarios (filesystem y obsidian-vault) y verifica la estructura de carpetas.

---

## 3. Tu primer proyecto

1. Abre **Obsidian** → Open Vault → selecciona la carpeta `dev-log/`
2. Abre **Claude Code** → Open Folder → esta carpeta (`bt-engine/`)
3. Escribe en Claude Code:

```
/new-integration
```

4. Describe lo que quieres en lenguaje natural. Ejemplo real:

> "Quiero que cuando se cierre un pedido en Revo XEF se cree una factura en Holded automáticamente."

5. Intake te hará preguntas concretas (credenciales, entorno, condiciones de negocio).
6. Los agentes trabajan en pipeline: Research → FinOps → Developer → QA → Security → DevOps.
7. Recibes el código desplegado y documentado en `dev-log/`.

No necesitas tocar código. No necesitas configurar AWS manualmente. No necesitas conocer las APIs.

---

## 4. Comandos disponibles

| Comando | Cuándo usarlo |
|---------|---------------|
| `/new-integration` | Empezar una integración nueva desde cero |
| `/diagnose [problema]` | Algo falla en producción y no sabes por qué |
| `/research [plataforma]` | Investigar una API antes de integrarla |
| `/security-audit` | Revisar seguridad antes de hacer deploy |
| `/cost-check [descripción]` | Estimar cuánto va a costar en AWS |
| `/caveman` | Sesión larga — activa modo ahorro de tokens |

---

## 5. Plataformas ya documentadas

Estas plataformas tienen perfil completo en la vault. No necesitas investigarlas desde cero.

| Plataforma | Qué hace |
|------------|----------|
| **Holded** | ERP y facturación española — API v2 con Bearer token |
| **PrestaShop** | E-commerce — 8 gotchas documentados en producción |
| **Revo XEF** | TPV para restaurantes — webhooks con HMAC SHA256 |
| **Revo Retail** | TPV para retail — misma arquitectura que XEF |
| **Revo Flow** | Gestión de sala y comandas |
| **Revo Solo** | TPV individual para autónomos |
| **Shopify** | E-commerce global — webhooks con firma HMAC |
| **WooCommerce** | E-commerce sobre WordPress |
| **Stripe** | Pagos — webhooks con firma Stripe-Signature |
| **Zoho CRM** | CRM — autenticación OAuth2 |
| **Business Central** | ERP Microsoft — API REST con OAuth2 |

Si necesitas una plataforma que no está aquí: `/research [nombre de la plataforma]`.

---

## 6. Qué hace cada agente

| Agente | Su trabajo |
|--------|------------|
| **Orquestador** | Coordina el pipeline, toma decisiones de deploy |
| **Intake** | Te pregunta todo lo necesario antes de empezar |
| **Research** | Investiga las APIs y documenta gotchas en la vault |
| **FinOps** | Calcula el coste mensual en AWS antes de escribir código |
| **Developer** | Escribe el código TypeScript de producción |
| **QA** | Prueba el código sin tocar AWS ni producción |
| **Security** | Audita OWASP, firma de webhooks y gestión de secretos |
| **DevOps** | Despliega con Serverless Framework cuando todo pasa |
| **Scribe** | Documenta cada decisión en `dev-log/` automáticamente |

---

## 7. Preguntas frecuentes

**¿Qué pasa si la plataforma no está documentada?**
Usa `/research [nombre]`. El agente investiga la API, documenta los gotchas y añade el perfil a `dev-log/knowledge-base/platforms/`. La próxima integración con esa plataforma no necesita investigación.

**¿Puedo parar a mitad del pipeline?**
Sí. El estado se guarda en `project_state.json`. Al volver, abre Claude Code en la misma carpeta y el Orquestador retoma donde se quedó.

**¿Cómo sé cuánto va a costar antes de empezar?**
`/cost-check [descripción de la integración]`. FinOps devuelve estimación mensual antes de que se escriba una línea de código. El pipeline no avanza si el coste no está aprobado.

**¿Dónde veo el conocimiento acumulado?**
Abre Obsidian → vault `dev-log/` → activa Graph View. Verás la red de plataformas, errores conocidos y patrones validados en producción.

**¿Qué hago si algo falla después del deploy?**
`/diagnose [descripción del fallo]`. El agente cruza el error contra los 7 errores documentados en producción antes de proponer ningún cambio de código.

---

## 8. Estructura del proyecto

```
bt-engine/
├── agents/          ← Definiciones de los 9 agentes (léelos si quieres entender el pipeline)
├── dev-log/         ← Vault de conocimiento (ábrela con Obsidian)
│   ├── index.md     ← Índice de todo el conocimiento
│   ├── knowledge-base/
│   │   ├── platforms/   ← Perfiles de las 11 plataformas
│   │   ├── aws/         ← Patrones Lambda, DynamoDB, Serverless Framework
│   │   ├── errors/      ← 7 errores reales documentados con solución
│   │   └── security/    ← Checklist pre-deploy, validación de webhooks
│   └── projects/    ← Una nota por integración desplegada
├── setup.sh         ← Ejecutar una vez tras clonar
└── README.md        ← Este fichero en versión muy corta
```

Todo el conocimiento generado por los agentes va a `dev-log/`. Todo el código generado va a una carpeta nueva por integración (fuera de este repo).

---

*Bigtoone · [bigto.one](https://bigto.one)*

---

*Diseñado y desarrollado por Álvaro López — Bigtoone 2026*
