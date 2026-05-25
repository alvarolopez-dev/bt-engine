# Bigtoone AI Agent Ecosystem

Pipeline de 8 agentes especializados para integrar plataformas B2B con AWS Lambda.
Convierte "quiero sincronizar A con B" en código TypeScript desplegado, al menor coste posible.
Patrón universal: `PLATAFORMA A → Lambda → PLATAFORMA B`.

---

## Prerequisitos

| Herramienta | Versión mínima | Instalación |
|-------------|----------------|-------------|
| Node.js | 20.x | https://nodejs.org |
| Git | cualquiera | https://git-scm.com |
| Claude Code | última | https://claude.ai/code |
| Obsidian | cualquiera | https://obsidian.md *(opcional, para la vault)* |

---

## Instalación

```bash
git clone https://github.com/bigtoone/bigtoone-agents.git
cd bigtoone-agents
./setup.sh          # macOS / Linux / Git Bash
```

```powershell
# Windows (PowerShell)
.\setup.ps1
```

El script verifica prerequisitos, instala los MCPs necesarios en Claude Code,
y crea la estructura de carpetas si no existe. Seguro de ejecutar más de una vez.

---

## Cómo usar

Ver [`agents/09_HOW_TO_USE.md`](agents/09_HOW_TO_USE.md) — responde tres preguntas:
qué es esto, cómo arranco un proyecto, y qué hago si algo falla.

Para la memoria del ecosistema: abre Obsidian → Open Vault → carpeta `dev-log/`.

---

## Estructura del repositorio

```
bigtoone-agents/
├── README.md
├── setup.sh                          # macOS / Linux / Git Bash
├── setup.ps1                         # Windows PowerShell
│
├── agents/
│   ├── 00_CONSTRAINTS.md             # Constraints universales — leer ANTES de todo
│   ├── 00_TREE.md                    # Mapa del ecosistema — pipeline + vault + agentes
│   ├── 01_agent_orchestrator.md      # Director del pipeline — QUÉ y QUIÉN, nunca CÓMO
│   ├── 02_agent_intake.md            # Interrogador — extrae, nunca asume
│   ├── 03_agent_research.md          # Investigador de APIs — hechos, nunca estrategias
│   ├── 04_agent_finops.md            # Guardián de costes — calcula, aprueba o bloquea
│   ├── 05_agent_developer.md         # Programador — TypeScript strict, nada más
│   ├── 06_agent_qa.md                # QA — tests con API_PROFILE real, no con suposiciones
│   ├── 07_agent_devops.md            # Despliegue — despliega, verifica, reporta
│   ├── 08_agent_scribe.md            # Memoria permanente — siempre activo en segundo plano
│   ├── 09_HOW_TO_USE.md             # Guía de uso del ecosistema
│   └── 10_agent_security.md          # Auditor de seguridad — audita y reporta
│
└── dev-log/                          # Vault de Obsidian — memoria del ecosistema
    ├── index.md                      # Mapa de la red
    ├── knowledge-base/
    │   ├── platforms/                # Perfiles de plataformas con gotchas documentados
    │   ├── errors/                   # Errores resueltos con síntoma, causa y solución
    │   ├── patterns/                 # Patrones validados en producción
    │   ├── security/                 # Checklist pre-deploy, GDPR, webhook validation
    │   ├── costs/                    # Histórico de costes reales por proyecto
    │   └── agent-details/            # Templates y schemas extraídos de agentes
    └── projects/                     # Documentación por proyecto (intake, dev log, lessons learned)
```

---

## MCPs instalados por el setup

| MCP | Propósito |
|-----|-----------|
| `filesystem` | Acceso directo a `dev-log/` — fallback cuando obsidian-vault no está disponible |
| `obsidian-vault` | Leer/escribir la vault con semántica Obsidian (búsqueda, frontmatter, enlaces) |

> `@modelcontextprotocol/server-fetch` no existe en npm. Claude Code incluye WebFetch nativo — no se necesita MCP externo para fetch.

---

## Stack de referencia

Proyectos del ecosistema usan este stack. Los agentes lo conocen.

```
Runtime:     Node.js 20.x + TypeScript (strict: true obligatorio)
Framework:   Serverless Framework v3 (v4 evaluado y rechazado — ADR-4)
AWS:         Lambda + Step Functions Express + EventBridge + DynamoDB + S3 + SNS
HTTP:        axios + axios-retry (×3, backoff exponencial)
Validación:  Zod (solo en boundary de datos externos)
Logging:     Pino (JSON estructurado — nunca console.log)
AWS SDK:     @aws-sdk/* v3 modular
Tests:       Jest + ts-jest
```

Coste real de referencia: `$0.00–$0.82/mes` para ~30 pedidos/día en `eu-west-2`.
Coste dominante: Secrets Manager (`$0.40/secreto/mes`), no Lambda.
