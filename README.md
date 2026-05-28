# Bigtoone Agent Ecosystem

Crea integraciones entre plataformas empresariales con código TypeScript desplegado en AWS Lambda — sin tocar código manualmente.

---

## Inicio rápido

```bash
git clone https://github.com/alvarolopez-dev/bt-engine.git
cd bt-engine
./setup.sh
```

---

## Requisitos

- [Claude Code](https://claude.ai/code) — última versión
- [Node.js](https://nodejs.org) 20+
- [Obsidian](https://obsidian.md) — para la vault de conocimiento

---

## Cómo usar

Lee [agents/MANUAL.md](agents/MANUAL.md) para la guía completa.

Lo esencial: abre Claude Code en esta carpeta, escribe `/new-integration` y describe qué quieres conectar.

> "Quiero que cuando se cierre un pedido en Revo XEF se cree una factura en Holded."

Los agentes hacen el resto: investigan las APIs, calculan el coste, escriben el código, lo prueban y lo despliegan.

---

## Qué incluye

- 10 agentes especializados (Intake, Research, FinOps, Developer, QA, Security, DevOps, Scribe, Orquestador + HOW_TO_USE)
- 11 plataformas documentadas: PrestaShop, Holded, Revo XEF, Revo Retail, Revo Flow, Revo Solo, Stripe, Shopify, WooCommerce, Zoho CRM, Business Central
- Vault de conocimiento en Obsidian (`dev-log/`) con patrones, errores reales y gotchas de producción
- Pipeline completo: análisis → coste → desarrollo → pruebas → seguridad → despliegue

---

## Stack

TypeScript · AWS Lambda · Serverless Framework v3 · nodejs20.x · DynamoDB · Claude Code

---

## Uso interno

Bigtoone — herramienta de uso interno.

---

## Autoría

Diseñado y desarrollado por **Álvaro López**
Bigtoone · 2026
