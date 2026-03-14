# Project N.O.M.A.D. — macOS Apple Silicon Porting Plan

> This document captures all architectural decisions, code changes, and hard-won fixes
> made to port Project N.O.M.A.D. from Debian/Ubuntu + NVIDIA GPU to macOS Apple Silicon (M-series).

---

## Overview

Project N.O.M.A.D. originally targets Debian/Ubuntu with NVIDIA GPU support. This port makes
it run natively and optimally on macOS Apple Silicon (M1/M2/M3/M4), with:

- **Full Metal GPU acceleration** for AI inference via native Ollama (no virtualization)
- **ARM64-native Docker images** for all other services via Docker Desktop
- **Native macOS menu bar app** (Swift) for one-click Start/Stop — zero resources when idle
- **macOS-compatible install script** replacing the Linux/apt-get-based installer

---

## Architecture: Hybrid Approach

| Layer | How it runs | Why |
|-------|------------|-----|
| Admin UI + API | Docker (AMD64 via Rosetta 2) | No ARM64 image published upstream |
| MySQL 8.0 | Docker (ARM64 native) | Official multi-arch image |
| Redis 7 | Docker (ARM64 native) | Official multi-arch image |
| Qdrant | Docker (ARM64 native) | Official multi-arch image |
| **Ollama** | **Native macOS binary** | **Full Metal GPU — no Docker overhead** |
| Dozzle (logs) | Docker (ARM64 native) | Official multi-arch image |
| Menu bar app | Native Swift app | One-click lifecycle control |

---

## Files Created

### `install/install_nomad_mac.sh`
Full macOS installer. Key behaviors:
- Checks macOS + ARM64
- Installs Homebrew, Docker Desktop, Node.js 22, Ollama, sysbench, Xcode CLT
- Creates two directory trees:
  - `/opt/project-nomad/` — scripts, config, secrets (not Docker-mounted)
  - `/Users/Shared/project-nomad/` — storage volumes + entrypoint.sh (Docker-mounted)
    - **Must be under `/Users/`** — Docker Desktop only shares `/Users` by default
- Generates secrets via `openssl rand`, injects into compose with `sed -i ''`
- Builds Swift menu bar app, creates `.app` bundle at `/Applications/NOMADMenuBar.app`
- Handles Ollama whether installed via Homebrew or manually

**macOS bash 3.2 compatibility fix:**
The default macOS shell is bash 3.2 which doesn't support bash 4+ syntax like `${var,,}`.
Uses `$(echo "$VAR" | tr '[:upper:]' '[:lower:]')` instead.

### `install/management_compose_mac.yaml`
ARM64-first Docker Compose. Key differences from `management_compose.yaml`:
- Admin service has **no `platform: linux/arm64`** — upstream image is AMD64-only; Docker Desktop runs it via Rosetta 2 automatically
- All other services: `platform: linux/arm64` for native performance
- `restart: "no"` on all services — lifecycle controlled by the menu bar app
- Ollama intentionally **absent** — runs natively on host
- `OLLAMA_URL=http://host.docker.internal:11434` — containers reach native Ollama via Docker's host bridge
- `NOMAD_PLATFORM=darwin` — tells the TypeScript app it's on macOS (necessary because the Docker container itself runs Linux)
- All volumes under `/Users/Shared/project-nomad/` not `/opt/project-nomad/`

### `install/entrypoint.sh` (modified)
Removed hard dependency on `wait-for-it.sh` (not baked into the upstream image).
Since `depends_on: condition: service_healthy` already guarantees MySQL is up,
we skip the TCP poll if the script is absent.

### `install/start_nomad_mac.sh`
Starts Ollama (brew or background), waits for Docker daemon, then `docker compose up -d`.

### `install/stop_nomad_mac.sh`
`docker compose down` then stops Ollama.

### `install/update_nomad_mac.sh`
`docker compose pull` + `up -d --remove-orphans` + `brew upgrade ollama`.

### `mac-app/Package.swift`
Swift Package Manager manifest for the menu bar app.
```swift
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "NOMADMenuBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "NOMADMenuBar",
            path: "Sources/NOMADMenuBar",
            exclude: ["Info.plist"]  // injected into .app bundle by install script
        )
    ]
)
```
**SPM gotcha:** Info.plist cannot be listed as a resource in an executable target — it must
be `exclude`d from SPM and injected directly into the `.app/Contents/` bundle by shell script.

### `mac-app/Sources/NOMADMenuBar/main.swift`
Bootstraps the NSApplication without a storyboard.

### `mac-app/Sources/NOMADMenuBar/AppDelegate.swift`
- `NSStatusItem` menu bar agent (`LSUIElement=true`, no Dock icon)
- SF Symbols: `antenna.radiowaves.left.and.right` (running) / `...slash` (stopped)
- Polls `docker inspect --format={{.State.Running}} nomad_admin` every 10 seconds
- Menu: status header, Start/Stop toggle, Open Dashboard, View Logs, Check for Updates, Quit
- Runs `/opt/project-nomad/start_nomad_mac.sh` or `stop_nomad_mac.sh` via `Process()`
- Finds Docker CLI at `/usr/local/bin/docker` or `/opt/homebrew/bin/docker`

### `mac-app/Sources/NOMADMenuBar/Info.plist`
- `LSUIElement = true` — menu bar agent, hides from Dock
- `CFBundleIdentifier = us.projectnomad.menubar`

---

## TypeScript Code Changes

### `admin/app/services/docker_service.ts`
**`_detectGPUType()`** — added `darwin` branch before the Linux `lspci` fallback:
```typescript
if (process.platform === 'darwin') {
  const { stdout } = await execAsync(
    'system_profiler SPDisplaysDataType 2>/dev/null | grep -i "metal" || true'
  )
  return stdout.toLowerCase().includes('metal')
    ? { type: 'apple_silicon' }
    : { type: 'none' }
}
```
Return type extended: `'nvidia' | 'amd' | 'apple_silicon' | 'none'`

**`_createContainer()`** — `apple_silicon` case marks Ollama as installed without creating
a Docker container; broadcasts "Native Ollama (Metal GPU) registered successfully".

### `admin/app/services/system_service.ts`
- `getSystemInfo()`: `darwin`/`NOMAD_PLATFORM` branch reads GPU via `systeminformation`,
  sets `gpuHealth.status = 'ok'` and `ollamaGpuAccessible = true` without nvidia-smi
- `_syncContainersWithDatabase()`: Skips Ollama container sync on macOS (no Docker container
  exists for it — would incorrectly mark it as uninstalled)

### `admin/app/services/benchmark_service.ts`
- Apple Silicon GPU detection via `systeminformation` controllers (Apple vendor)
- Detects `isMacOS`, skips Docker sysbench image; routes to native sysbench binary
- `_runSysbenchCommandNative()`: finds sysbench at `/opt/homebrew/bin/sysbench`,
  handles `sh -c` compound commands for disk tests
- All four sysbench methods accept `nativeMode = false` parameter

### `admin/database/seeders/service_seeder.ts`
- Ollama entry annotated with note about native macOS mode
- Kolibri entry annotated: `treehouses/kolibri:0.12.8` is AMD64-only, runs via Rosetta 2

---

## Key Bugs Fixed During Installation

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| `${ACCEPT,,}: bad substitution` | macOS bash 3.2 doesn't support bash 4+ lowercase expansion | Use `tr '[:upper:]' '[:lower:]'` |
| SPM error: `Info.plist forbidden as resource` | SPM can't bundle Info.plist as a resource in executable targets | Add `exclude: ["Info.plist"]` to target; inject into `.app` bundle via shell |
| Docker "mounts denied" for `/opt/project-nomad/` | Docker Desktop only shares `/Users/` by default | Move all Docker-mounted paths to `/Users/Shared/project-nomad/` |
| Admin container: `wait-for-it.sh: not found` | Script not baked into upstream image | Skip gracefully; MySQL healthcheck already guarantees it's up |
| Admin container: `ENOENT: storage/logs/admin.log` | `logs/` subdirectory not created | Added `logs` to `mkdir -p` in installer |
| `brew services start ollama` fails | Ollama installed outside Homebrew | Check if already running → try brew → fallback to `nohup ollama serve` |
| Admin image has no ARM64 build | Upstream only publishes AMD64 | Remove `platform: linux/arm64` from admin service; Rosetta 2 handles it |

---

## ARM64 Image Compatibility Matrix

| Service | Image | ARM64 | Notes |
|---------|-------|-------|-------|
| Admin | `ghcr.io/crosstalk-solutions/project-nomad` | ⚠️ Rosetta 2 | AMD64 only upstream |
| MySQL | `mysql:8.0` | ✅ Native | |
| Redis | `redis:7-alpine` | ✅ Native | |
| Dozzle | `amir20/dozzle:v10.0` | ✅ Native | |
| Qdrant | `qdrant/qdrant:v1.16` | ✅ Native | |
| **Ollama** | `brew install ollama` | ✅ Metal GPU | Native macOS, full M-series acceleration |
| Kiwix | `ghcr.io/kiwix/kiwix-serve:3.8.1` | ✅ Native | |
| CyberChef | `ghcr.io/gchq/cyberchef:10.19.4` | ✅ Native | |
| FlatNotes | `dullage/flatnotes:v5.5.4` | ✅ Native | |
| Kolibri | `treehouses/kolibri:0.12.8` | ⚠️ Rosetta 2 | AMD64 only upstream |

---

## Directory Structure (macOS)

```
/opt/project-nomad/           ← scripts, config, secrets
  management_compose_mac.yaml
  start_nomad_mac.sh
  stop_nomad_mac.sh
  update_nomad_mac.sh
  .env                        ← generated secrets (chmod 600)

/Users/Shared/project-nomad/ ← Docker-mounted volumes (under /Users/ for Docker Desktop access)
  entrypoint.sh               ← mounted into admin container
  storage/
    zim/                      ← Kiwix ZIM files
    kolibri/                  ← Kolibri data
    ollama/                   ← Ollama models
    qdrant/                   ← Qdrant vector store
    flatnotes/                ← FlatNotes data
    mysql/                    ← MySQL data
    redis/                    ← Redis data
    logs/                     ← Admin app logs

/Applications/NOMADMenuBar.app ← Swift menu bar agent
```

---

## Verification Checklist

1. `bash install/install_nomad_mac.sh` — completes without errors
2. NOMAD antenna icon appears in macOS menu bar
3. Click "Start N.O.M.A.D." → icon fills, status shows "● Running"
4. `http://localhost:8080` loads the Command Center
5. `curl http://localhost:11434` → "Ollama is running"
6. Activity Monitor → GPU History shows usage during AI inference
7. Settings → Benchmark → shows "Apple Silicon (Metal)" as GPU
8. Click "Stop N.O.M.A.D." → all containers stop, `docker ps` shows no nomad containers
9. After stop: CPU/memory from N.O.M.A.D. drops to zero
