#!/usr/bin/env bash
# Project N.O.M.A.D. — macOS Stop Script
set -euo pipefail

NOMAD_DIR="/opt/project-nomad"
COMPOSE_FILE="${NOMAD_DIR}/management_compose_mac.yaml"

echo "[N.O.M.A.D.] Stopping..."

# Stop Docker stack
docker compose -f "${COMPOSE_FILE}" down

# Stop native Ollama
if command -v brew &>/dev/null; then
  brew services stop ollama 2>/dev/null || true
fi

echo "[N.O.M.A.D.] Stopped. All services offline."
