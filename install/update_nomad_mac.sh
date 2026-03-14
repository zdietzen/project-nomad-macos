#!/usr/bin/env bash
# Project N.O.M.A.D. — macOS Update Script
set -euo pipefail

NOMAD_DIR="/opt/project-nomad"
COMPOSE_FILE="${NOMAD_DIR}/management_compose_mac.yaml"

echo "[N.O.M.A.D.] Checking for updates..."

# Pull latest ARM64 Docker images
docker compose -f "${COMPOSE_FILE}" pull

# Restart containers with new images (rolling restart)
docker compose -f "${COMPOSE_FILE}" up -d --remove-orphans

# Upgrade native Ollama
if command -v brew &>/dev/null; then
  echo "[N.O.M.A.D.] Upgrading Ollama..."
  brew upgrade ollama 2>/dev/null || true
  brew services restart ollama 2>/dev/null || true
fi

echo "[N.O.M.A.D.] Update complete."
