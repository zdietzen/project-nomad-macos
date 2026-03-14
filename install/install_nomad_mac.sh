#!/usr/bin/env bash
# =============================================================================
# Project N.O.M.A.D. — macOS Apple Silicon Installer
# Supports: macOS 13+ (Ventura) on Apple Silicon (M1/M2/M3/M4)
# =============================================================================
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*" >&2; exit 1; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       Project N.O.M.A.D. — macOS Installer           ║${NC}"
echo -e "${BOLD}║   Node for Offline Media, Archives, and Data          ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Pre-flight checks ─────────────────────────────────────────────────────────
[[ "$(uname)" == "Darwin" ]] || error "This installer requires macOS."
[[ "$(uname -m)" == "arm64" ]] || warn "Not running on Apple Silicon — performance may be reduced."

# License
echo -e "${YELLOW}This installer sets up Project N.O.M.A.D. under the Apache 2.0 License.${NC}"
read -rp "Do you accept the license? [y/N]: " ACCEPT
[[ "$(echo "$ACCEPT" | tr '[:upper:]' '[:lower:]')" == "y" ]] || error "License not accepted. Exiting."

# ── Homebrew ──────────────────────────────────────────────────────────────────
info "Checking for Homebrew..."
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for Apple Silicon
  eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
fi
success "Homebrew ready"

# ── Xcode Command Line Tools (provides Swift compiler) ────────────────────────
info "Checking for Xcode Command Line Tools..."
if ! xcode-select -p &>/dev/null; then
  info "Installing Xcode Command Line Tools (required for Swift menu bar app)..."
  xcode-select --install
  echo "Please complete the Xcode CLT installation dialog, then press Enter to continue..."
  read -r
fi
success "Xcode CLT ready"

# ── Docker Desktop ────────────────────────────────────────────────────────────
info "Checking for Docker Desktop..."
if ! command -v docker &>/dev/null; then
  info "Installing Docker Desktop for Mac..."
  brew install --cask docker
  info "Opening Docker Desktop — please complete setup and wait for it to start..."
  open -a Docker
  echo "Press Enter once Docker Desktop is running (whale icon in menu bar is steady)..."
  read -r
else
  success "Docker already installed"
  # Ensure Docker daemon is running
  if ! docker info &>/dev/null; then
    info "Starting Docker Desktop..."
    open -a Docker
    echo "Press Enter once Docker Desktop is running..."
    read -r
  fi
fi
success "Docker Desktop ready"

# ── Node.js 22 ────────────────────────────────────────────────────────────────
info "Checking for Node.js 22..."
if ! command -v node &>/dev/null || [[ "$(node --version | cut -d. -f1 | tr -d 'v')" -lt 22 ]]; then
  info "Installing Node.js 22..."
  brew install node@22
  brew link --overwrite node@22 || true
fi
success "Node.js $(node --version) ready"

# ── Ollama (native Metal GPU) ─────────────────────────────────────────────────
info "Checking for Ollama..."
if ! command -v ollama &>/dev/null; then
  info "Installing Ollama (native Apple Silicon Metal GPU support)..."
  brew install ollama
fi
success "Ollama ready"

# ── sysbench (benchmarks) ─────────────────────────────────────────────────────
info "Checking for sysbench..."
if ! command -v sysbench &>/dev/null; then
  info "Installing sysbench..."
  brew install sysbench
fi
success "sysbench ready"

# ── Directory structure ───────────────────────────────────────────────────────
# NOMAD_DIR: config, scripts, secrets (not Docker-mounted; sudo required)
# STORAGE_DIR: storage volumes + entrypoint.sh mounted into Docker containers.
#   Must live under /Users/ — Docker Desktop only shares /Users by default.
#   /Users/Shared is world-writable so no sudo needed.
NOMAD_DIR="/opt/project-nomad"
STORAGE_DIR="/Users/Shared/project-nomad"

info "Creating N.O.M.A.D. directories..."
sudo mkdir -p "${NOMAD_DIR}"
sudo chown -R "$(whoami)":staff "${NOMAD_DIR}"

# Storage dirs: created without sudo since /Users/Shared is world-writable
mkdir -p "${STORAGE_DIR}/storage/"{zim,kolibri,ollama,qdrant,flatnotes,mysql,redis,logs}
success "Directories created"

# ── Detect local IP ───────────────────────────────────────────────────────────
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")
info "Detected local IP: ${LOCAL_IP}"

# ── Generate secrets ──────────────────────────────────────────────────────────
info "Generating secrets..."
APP_KEY=$(openssl rand -base64 32)
DB_PASS=$(openssl rand -hex 16)
ROOT_PASS=$(openssl rand -hex 16)

# ── Get the install directory (where this script lives) ───────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# ── Copy compose and helper files ─────────────────────────────────────────────
info "Copying configuration files..."
cp "${SCRIPT_DIR}/management_compose_mac.yaml" "${NOMAD_DIR}/"
cp "${SCRIPT_DIR}/start_nomad_mac.sh" "${NOMAD_DIR}/"
cp "${SCRIPT_DIR}/stop_nomad_mac.sh" "${NOMAD_DIR}/"
cp "${SCRIPT_DIR}/update_nomad_mac.sh" "${NOMAD_DIR}/"
chmod +x "${NOMAD_DIR}/"*.sh

# entrypoint.sh must be in the Docker-accessible STORAGE_DIR (not /opt)
cp "${SCRIPT_DIR}/entrypoint.sh" "${STORAGE_DIR}/entrypoint.sh"
chmod +x "${STORAGE_DIR}/entrypoint.sh"

# ── Inject secrets into compose file ─────────────────────────────────────────
info "Configuring environment..."
COMPOSE_FILE="${NOMAD_DIR}/management_compose_mac.yaml"
sed -i '' "s|APP_KEY=replaceme|APP_KEY=${APP_KEY}|g" "${COMPOSE_FILE}"
sed -i '' "s|DB_PASSWORD=replaceme|DB_PASSWORD=${DB_PASS}|g" "${COMPOSE_FILE}"
sed -i '' "s|MYSQL_PASSWORD=replaceme|MYSQL_PASSWORD=${DB_PASS}|g" "${COMPOSE_FILE}"
sed -i '' "s|MYSQL_ROOT_PASSWORD=replaceme|MYSQL_ROOT_PASSWORD=${ROOT_PASS}|g" "${COMPOSE_FILE}"
sed -i '' "s|URL=replaceme|URL=http://${LOCAL_IP}:8080|g" "${COMPOSE_FILE}"

# ── Save secrets for reference ────────────────────────────────────────────────
cat > "${NOMAD_DIR}/.env" <<EOF
# N.O.M.A.D. macOS Configuration — generated $(date)
APP_KEY=${APP_KEY}
DB_PASSWORD=${DB_PASS}
DB_ROOT_PASSWORD=${ROOT_PASS}
LOCAL_IP=${LOCAL_IP}
NOMAD_URL=http://${LOCAL_IP}:8080
STORAGE_DIR=${STORAGE_DIR}
EOF
chmod 600 "${NOMAD_DIR}/.env"

# ── Build the Swift menu bar app ──────────────────────────────────────────────
info "Building N.O.M.A.D. menu bar app..."
MAC_APP_DIR="${PROJECT_ROOT}/mac-app"
if [[ -d "${MAC_APP_DIR}" ]]; then
  cd "${MAC_APP_DIR}"
  swift build --configuration release 2>&1 | tail -5
  BINARY="${MAC_APP_DIR}/.build/release/NOMADMenuBar"
  if [[ -f "${BINARY}" ]]; then
    # Create a minimal .app bundle
    APP_BUNDLE="/Applications/NOMADMenuBar.app"
    mkdir -p "${APP_BUNDLE}/Contents/MacOS"
    cp "${BINARY}" "${APP_BUNDLE}/Contents/MacOS/NOMADMenuBar"
    cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>NOMADMenuBar</string>
  <key>CFBundleIdentifier</key><string>us.projectnomad.menubar</string>
  <key>CFBundleName</key><string>NOMAD</string>
  <key>CFBundleVersion</key><string>1.0.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
    success "Menu bar app installed to ${APP_BUNDLE}"
  else
    warn "Menu bar app build failed — you can build it later with: cd mac-app && swift build -c release"
  fi
  cd - >/dev/null
else
  warn "mac-app directory not found — skipping menu bar app build"
fi

# ── Start Ollama ──────────────────────────────────────────────────────────────
info "Starting Ollama (Metal GPU service)..."
if curl -sf http://localhost:11434 &>/dev/null; then
  success "Ollama already running at http://localhost:11434"
elif brew list ollama &>/dev/null 2>&1; then
  brew services start ollama
  sleep 3
  success "Ollama running at http://localhost:11434"
else
  # Ollama installed outside Homebrew — start as background process
  nohup ollama serve &>/dev/null &
  sleep 3
  success "Ollama running at http://localhost:11434"
fi

# ── Pull ARM64 Docker images ──────────────────────────────────────────────────
info "Pulling ARM64-native Docker images (this may take a few minutes)..."
docker compose -f "${NOMAD_DIR}/management_compose_mac.yaml" pull

# ── Start the stack ───────────────────────────────────────────────────────────
info "Starting N.O.M.A.D. Docker stack..."
docker compose -f "${NOMAD_DIR}/management_compose_mac.yaml" up -d

# ── Launch menu bar app ───────────────────────────────────────────────────────
if [[ -d "/Applications/NOMADMenuBar.app" ]]; then
  info "Launching menu bar app..."
  open /Applications/NOMADMenuBar.app
  # Add to login items via osascript
  osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/NOMADMenuBar.app", hidden:false}' 2>/dev/null || \
    warn "Could not add to Login Items automatically — do it manually in System Settings → General → Login Items"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║           N.O.M.A.D. Installation Complete!           ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Dashboard:    ${CYAN}http://localhost:8080${NC}"
echo -e "  Network:      ${CYAN}http://${LOCAL_IP}:8080${NC}"
echo -e "  Logs:         ${CYAN}http://localhost:9999${NC} (Dozzle)"
echo -e "  Ollama API:   ${CYAN}http://localhost:11434${NC}"
echo ""
echo -e "  Menu bar app: Click the antenna icon to start/stop N.O.M.A.D."
echo -e "  Config:       ${NOMAD_DIR}/.env"
echo ""
echo -e "  To stop:  ${YELLOW}bash ${NOMAD_DIR}/stop_nomad_mac.sh${NC}"
echo -e "  To start: ${YELLOW}bash ${NOMAD_DIR}/start_nomad_mac.sh${NC}"
echo -e "  To update:${YELLOW}bash ${NOMAD_DIR}/update_nomad_mac.sh${NC}"
echo ""
