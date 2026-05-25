# setup.ps1 — Bigtoone AI Agent Ecosystem
# Plataforma: Windows (PowerShell 5.1+ / PowerShell 7+)
# Idempotente: seguro de ejecutar más de una vez

$ErrorActionPreference = "Continue"

# ── FUNCIONES DE OUTPUT ───────────────────────────────────────────────────────
function Write-Ok   { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Err  { param($msg) Write-Host "❌ $msg" -ForegroundColor Red }
function Write-Warn { param($msg) Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function Write-Info { param($msg) Write-Host "ℹ️  $msg" -ForegroundColor Cyan }
function Write-Step { param($msg) Write-Host "`n── $msg ──────────────────────────────" -ForegroundColor White }

Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Bigtoone AI Agent Ecosystem — Setup    ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$errors = 0

# ── PASO 1: VERIFICAR PREREQUISITOS ──────────────────────────────────────────
Write-Step "PASO 1 — Verificando prerequisitos"

function Check-Command {
  param(
    [string]$Command,
    [string]$Name,
    [string]$InstallUrl
  )

  $found = Get-Command $Command -ErrorAction SilentlyContinue
  if ($found) {
    $version = & $Command --version 2>&1 | Select-Object -First 1
    Write-Ok "$Name encontrado: $version"
  } else {
    Write-Err "$Name no encontrado."
    Write-Host "   Instalar desde: $InstallUrl" -ForegroundColor Cyan
    $script:errors++
  }
}

Check-Command "node"   "Node.js"     "https://nodejs.org"
Check-Command "npm"    "npm"         "https://nodejs.org"
Check-Command "git"    "Git"         "https://git-scm.com"
Check-Command "claude" "Claude Code" "https://claude.ai/code"

if ($errors -gt 0) {
  Write-Host ""
  Write-Err "Faltan $errors prerequisito(s). Instálalos y vuelve a ejecutar el script."
  exit 1
}

# ── PASO 2: VERIFICAR UBICACIÓN ───────────────────────────────────────────────
Write-Step "PASO 2 — Verificando ubicación del repositorio"

$inRepo = (Test-Path "09_HOW_TO_USE.md") -or
          (Test-Path "agents\09_HOW_TO_USE.md") -or
          (Test-Path "README.md")

if (-not $inRepo) {
  Write-Warn "No parece que estés dentro del repositorio bigtoone-agents."
  Write-Host ""
  Write-Host "  Clona el repositorio primero:" -ForegroundColor White
  Write-Host "  git clone https://github.com/bigtoone/bigtoone-agents.git" -ForegroundColor Cyan
  Write-Host "  cd bigtoone-agents" -ForegroundColor Cyan
  Write-Host "  .\setup.ps1" -ForegroundColor Cyan
  exit 1
}

Write-Ok "Repositorio detectado en: $(Get-Location)"

# ── PASO 3: INSTALAR MCPs ─────────────────────────────────────────────────────
Write-Step "PASO 3 — Instalando MCPs de Claude Code"

function Install-MCP {
  param(
    [string]$Name,
    [string[]]$CmdArgs
  )

  # Comprobar si ya está instalado
  $mcpList = & claude mcp list 2>&1
  if ($mcpList -match "(?i)^$Name") {
    Write-Warn "MCP '$Name' ya instalado — saltando"
    return
  }

  Write-Info "Instalando MCP '$Name'..."
  try {
    & claude @CmdArgs 2>&1 | Out-Null
    Write-Ok "MCP '$Name' instalado correctamente"
  } catch {
    Write-Warn "MCP '$Name': no se pudo confirmar la instalación. Verifica con: claude mcp list"
  }
}

# Nota: @modelcontextprotocol/server-fetch no existe en npm.
# Claude Code incluye WebFetch nativo — no se necesita MCP de fetch externo.

Install-MCP -Name "filesystem" -CmdArgs @(
  "mcp", "add", "filesystem", "--",
  "npx", "-y", "@modelcontextprotocol/server-filesystem", ".\dev-log"
)

Install-MCP -Name "obsidian-vault" -CmdArgs @(
  "mcp", "add-json", "obsidian-vault",
  '{"type":"stdio","command":"npx","args":["-y","@bitbonsai/mcpvault@latest",".\\dev-log"]}'
)

# Verificación final de MCPs
Write-Host ""
Write-Info "MCPs instalados actualmente:"
& claude mcp list 2>&1

# ── PASO 4: VERIFICAR ESTRUCTURA DE CARPETAS ──────────────────────────────────
Write-Step "PASO 4 — Verificando estructura de carpetas"

$dirs = @(
  "agents",
  "dev-log",
  "dev-log\knowledge-base",
  "dev-log\knowledge-base\platforms",
  "dev-log\knowledge-base\errors",
  "dev-log\knowledge-base\patterns",
  "dev-log\knowledge-base\security",
  "dev-log\knowledge-base\costs",
  "dev-log\knowledge-base\agent-details",
  "dev-log\projects"
)

foreach ($dir in $dirs) {
  if (Test-Path $dir) {
    Write-Ok "Carpeta existe: $dir"
  } else {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Write-Ok "Carpeta creada: $dir"
  }
}

# ── PASO 5: INSTRUCCIONES POST-SETUP ──────────────────────────────────────────
Write-Step "PASO 5 — Setup completado"

Write-Host ""
Write-Host "✅ Ecosistema Bigtoone listo" -ForegroundColor Green
Write-Host ""
Write-Host "Próximos pasos:" -ForegroundColor White
Write-Host "  1. Abre " -NoNewline; Write-Host "Obsidian" -ForegroundColor White -NoNewline
Write-Host " → Open Vault → selecciona la carpeta " -NoNewline; Write-Host "dev-log\" -ForegroundColor Cyan
Write-Host "  2. Abre " -NoNewline; Write-Host "Claude Code" -ForegroundColor White -NoNewline
Write-Host " → Open Folder → esta carpeta"
Write-Host "  3. Lee " -NoNewline; Write-Host "agents\09_HOW_TO_USE.md" -ForegroundColor Cyan -NoNewline
Write-Host " para empezar"
Write-Host ""
Write-Host "Tip: Para verificar los MCPs instalados: " -NoNewline -ForegroundColor Yellow
Write-Host "claude mcp list" -ForegroundColor Cyan
Write-Host ""
