#!/usr/bin/env bash
# Project N.O.M.A.D. — macOS Start Script
set -euo pipefail

NOMAD_DIR="/opt/project-nomad"
COMPOSE_FILE="${NOMAD_DIR}/management_compose_mac.yaml"

echo "[N.O.M.A.D.] Starting..."

# Start native Ollama (Metal GPU)
if command -v brew &>/dev/null; then
  brew services start ollama 2>/dev/null || true
fi

# Wait for Docker daemon to be ready
until docker info &>/dev/null 2>&1; do
  echo "[N.O.M.A.D.] Waiting for Docker..."
  sleep 2
done

# Collect disk info (used by admin dashboard)
if [[ -f "${NOMAD_DIR}/collect_disk_info.sh" ]]; then
  bash "${NOMAD_DIR}/collect_disk_info.sh" &>/dev/null &
fi

# Start the Docker stack
docker compose -f "${COMPOSE_FILE}" up -d

echo "[N.O.M.A.D.] Running at http://localhost:8080"
