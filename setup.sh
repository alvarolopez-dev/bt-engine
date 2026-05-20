#!/usr/bin/env bash
# setup.sh — Bigtoone AI Agent Ecosystem
# Plataformas: macOS, Linux, Windows (Git Bash)
# Idempotente: seguro de ejecutar más de una vez

set -uo pipefail

# ── COLORES ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✅ $1${NC}"; }
err()  { echo -e "${RED}❌ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
step() { echo -e "\n${BOLD}── $1 ──────────────────────────────${NC}"; }

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════╗"
echo "║   Bigtoone AI Agent Ecosystem — Setup    ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

ERRORS=0

# ── PASO 1: VERIFICAR PREREQUISITOS ──────────────────────────────────────────
step "PASO 1 — Verificando prerequisitos"

check_cmd() {
  local cmd="$1"
  local name="$2"
  local install_url="$3"

  if command -v "$cmd" &>/dev/null; then
    ok "$name encontrado: $($cmd --version 2>&1 | head -1)"
  else
    err "$name no encontrado."
    echo -e "   Instalar desde: ${CYAN}${install_url}${NC}"
    ERRORS=$((ERRORS + 1))
  fi
}

check_cmd "node"   "Node.js"     "https://nodejs.org"
check_cmd "npm"    "npm"         "https://nodejs.org"
check_cmd "git"    "Git"         "https://git-scm.com"
check_cmd "claude" "Claude Code" "https://claude.ai/code"

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  err "Faltan $ERRORS prerequisito(s). Instálalos y vuelve a ejecutar el script."
  exit 1
fi

# ── PASO 2: VERIFICAR UBICACIÓN ───────────────────────────────────────────────
step "PASO 2 — Verificando ubicación del repositorio"

# Detectar si estamos dentro del repo comprobando ficheros clave
if [ ! -f "09_HOW_TO_USE.md" ] && [ ! -f "agents/09_HOW_TO_USE.md" ] && [ ! -f "README.md" ]; then
  warn "No parece que estés dentro del repositorio bigtoone-agents."
  echo ""
  echo -e "  Clona el repositorio primero:"
  echo -e "  ${CYAN}git clone https://github.com/bigtoone/bigtoone-agents.git${NC}"
  echo -e "  ${CYAN}cd bigtoone-agents${NC}"
  echo -e "  ${CYAN}./setup.sh${NC}"
  exit 1
fi

ok "Repositorio detectado en: $(pwd)"

# ── PASO 3: INSTALAR MCPs ─────────────────────────────────────────────────────
step "PASO 3 — Instalando MCPs de Claude Code"

install_mcp() {
  local name="$1"
  shift
  local cmd=("$@")

  # Comprobar si ya está instalado
  if claude mcp list 2>/dev/null | grep -qi "^${name}"; then
    warn "MCP '${name}' ya instalado — saltando"
    return 0
  fi

  info "Instalando MCP '${name}'..."
  if "${cmd[@]}" 2>&1; then
    ok "MCP '${name}' instalado correctamente"
  else
    warn "MCP '${name}': no se pudo confirmar la instalación. Verifica manualmente con: claude mcp list"
  fi
}

# Nota: @modelcontextprotocol/server-fetch no existe en npm.
# Claude Code incluye WebFetch nativo — no se necesita MCP de fetch externo.

install_mcp "filesystem" \
  claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem ./dev-log

# Verificación final de MCPs
echo ""
info "MCPs instalados actualmente:"
claude mcp list 2>/dev/null || warn "No se pudo listar los MCPs. Verifica con: claude mcp list"

# ── PASO 4: VERIFICAR ESTRUCTURA DE CARPETAS ──────────────────────────────────
step "PASO 4 — Verificando estructura de carpetas"

DIRS=(
  "agents"
  "dev-log"
  "dev-log/knowledge-base"
  "dev-log/knowledge-base/platforms"
  "dev-log/knowledge-base/errors"
  "dev-log/knowledge-base/patterns"
  "dev-log/knowledge-base/costs"
  "dev-log/projects"
)

for dir in "${DIRS[@]}"; do
  if [ -d "$dir" ]; then
    ok "Carpeta existe: $dir"
  else
    mkdir -p "$dir"
    ok "Carpeta creada: $dir"
  fi
done

# ── PASO 5: INSTRUCCIONES POST-SETUP ──────────────────────────────────────────
step "PASO 5 — Setup completado"

echo ""
echo -e "${GREEN}${BOLD}✅ Ecosistema Bigtoone listo${NC}"
echo ""
echo -e "${BOLD}Próximos pasos:${NC}"
echo -e "  ${CYAN}1.${NC} Abre ${BOLD}Obsidian${NC} → Open Vault → selecciona la carpeta ${CYAN}dev-log/${NC}"
echo -e "  ${CYAN}2.${NC} Abre ${BOLD}Claude Code${NC} → Open Folder → esta carpeta"
echo -e "  ${CYAN}3.${NC} Lee ${CYAN}agents/09_HOW_TO_USE.md${NC} (o ${CYAN}09_HOW_TO_USE.md${NC}) para empezar"
echo ""
echo -e "${YELLOW}Tip:${NC} Para verificar los MCPs instalados: ${CYAN}claude mcp list${NC}"
echo ""
