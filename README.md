<div align="center">
<img src="https://raw.githubusercontent.com/Crosstalk-Solutions/project-nomad/refs/heads/main/admin/public/project_nomad_logo.png" width="200" height="200"/>

# Project N.O.M.A.D.
### Node for Offline Media, Archives, and Data

**Knowledge That Never Goes Offline**

[![Original Project](https://img.shields.io/badge/Original%20Project-Crosstalk%20Solutions-blue)](https://github.com/Crosstalk-Solutions/project-nomad)
[![Website](https://img.shields.io/badge/Website-projectnomad.us-blue)](https://www.projectnomad.us)
[![Discord](https://img.shields.io/badge/Discord-Join%20Community-5865F2)](https://discord.com/invite/crosstalksolutions)
[![License](https://img.shields.io/badge/License-Apache%202.0-green)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-Apple%20Silicon-black?logo=apple)](install/install_nomad_mac.sh)

</div>

---

> **This is a macOS Apple Silicon fork** of [Project N.O.M.A.D.](https://github.com/Crosstalk-Solutions/project-nomad) by [Crosstalk Solutions](https://github.com/Crosstalk-Solutions).
> All original work, concept, and application code belongs to the Crosstalk Solutions team.
> This fork adds native macOS Apple Silicon support with Metal GPU acceleration and a native menu bar app.

---

Project N.O.M.A.D. is a self-contained, offline-first knowledge and education server packed with critical tools, knowledge, and AI to keep you informed and empowered — anytime, anywhere. No internet required after setup.

## macOS Apple Silicon — Quick Install

> **Requirements:** macOS 13+ (Ventura), Apple Silicon (M1/M2/M3/M4), Homebrew

```bash
git clone https://github.com/dietzendev/project-nomad.git
cd project-nomad
bash install/install_nomad_mac.sh
```

That's it. The installer handles everything:
- Docker Desktop, Node.js 22, Ollama (native Metal GPU), sysbench
- Generates secrets, configures and starts all services
- Builds and installs the menu bar app to `/Applications/NOMADMenuBar.app`

After install, open your browser to **http://localhost:8080**. The antenna icon in your menu bar controls the entire stack.

## What Makes the macOS Port Different

### Native Metal GPU via Ollama
On Apple Silicon, Ollama runs as a **native macOS process** (not in Docker), giving it direct access to the M-series Neural Engine and GPU via Metal. This means:
- No virtualization overhead for AI inference
- Full unified memory bandwidth available to models
- Works out of the box — no CUDA setup, no GPU passthrough

### Menu Bar App
A lightweight Swift app sits in your menu bar with zero resource usage when N.O.M.A.D. is stopped.

| State | Icon |
|-------|------|
| Running | `antenna.radiowaves.left.and.right` (filled) |
| Stopped | `antenna.radiowaves.left.and.right.slash` |

One click starts or stops the entire stack — Docker containers, Ollama, everything.

### ARM64-Native Services
All Docker services run as native `linux/arm64` images where available. The admin container runs via Rosetta 2 (AMD64) since the upstream image doesn't yet publish an ARM64 build — this is transparent and functional.

---

## How It Works

N.O.M.A.D. is a management UI ("Command Center") and API that orchestrates a collection of containerized tools via Docker. It handles installation, configuration, and updates for everything — so you don't have to.

**Built-in capabilities include:**
- **AI Chat with Knowledge Base** — local AI chat powered by [Ollama](https://ollama.com/) with full Metal GPU acceleration, plus document upload and semantic search (RAG via [Qdrant](https://qdrant.tech/))
- **Information Library** — offline Wikipedia, medical references, ebooks, and more via [Kiwix](https://kiwix.org/)
- **Education Platform** — courses with progress tracking via [Kolibri](https://learningequality.org/kolibri/)
- **Data Tools** — encryption, encoding, and analysis via [CyberChef](https://gchq.github.io/CyberChef/)
- **Notes** — local note-taking via [FlatNotes](https://github.com/dullage/flatnotes)
- **System Benchmark** — hardware scoring with a [community leaderboard](https://benchmark.projectnomad.us)
- **Easy Setup Wizard** — guided first-time configuration with curated content collections

## What's Included

| Capability | Powered By | What You Get |
|-----------|-----------|-------------|
| Information Library | Kiwix | Offline Wikipedia, medical references, survival guides, ebooks |
| AI Assistant | Ollama + Qdrant | Built-in chat with document upload and semantic search |
| Education Platform | Kolibri | Courses, progress tracking, multi-user support |
| Data Tools | CyberChef | Encryption, encoding, hashing, and data analysis |
| Notes | FlatNotes | Local note-taking with markdown support |
| System Benchmark | Built-in | Hardware scoring and community leaderboard |

## macOS Hardware Requirements

| | Minimum | Recommended |
|-|---------|-------------|
| **Mac** | Any Apple Silicon Mac | Mac Mini M4 / MacBook Pro M4 |
| **RAM** | 8 GB | 16–64 GB (unified memory = GPU VRAM) |
| **Storage** | 20 GB free | 250+ GB SSD |
| **macOS** | 13 Ventura | 14 Sonoma or 15 Sequoia |

The Mac Mini M4 is an exceptional N.O.M.A.D. host — fanless under light load, full Metal GPU for AI, and efficient enough to run 24/7 with minimal power draw.

## macOS Helper Scripts

Once installed, all helper scripts live in `/opt/project-nomad/`:

```bash
# Start the entire stack (Ollama + Docker services)
bash /opt/project-nomad/start_nomad_mac.sh

# Stop everything
bash /opt/project-nomad/stop_nomad_mac.sh

# Pull latest images and restart
bash /opt/project-nomad/update_nomad_mac.sh
```

Or just use the menu bar app — it calls these same scripts under the hood.

## Service Ports

| Service | URL |
|---------|-----|
| Command Center | http://localhost:8080 |
| Log Viewer (Dozzle) | http://localhost:9999 |
| Ollama API | http://localhost:11434 |
| Qdrant | http://localhost:6333 |

## Privacy & Offline Use

N.O.M.A.D. is designed for offline usage. Internet is only needed during initial install and when downloading additional content. There is **zero built-in telemetry**.

## Linux / Original Installation

For the original Linux (Debian/Ubuntu) installation, see the [upstream project](https://github.com/Crosstalk-Solutions/project-nomad):

```bash
sudo apt-get update && sudo apt-get install -y curl && \
curl -fsSL https://raw.githubusercontent.com/Crosstalk-Solutions/project-nomad/refs/heads/main/install/install_nomad.sh \
  -o install_nomad.sh && sudo bash install_nomad.sh
```

---

## Credits & Attribution

This project is a macOS port of **[Project N.O.M.A.D.](https://github.com/Crosstalk-Solutions/project-nomad)**, originally created and maintained by **[Crosstalk Solutions](https://github.com/Crosstalk-Solutions)**.

The original project, application code, design, and concept are entirely the work of the Crosstalk Solutions team. This fork contributes:
- macOS Apple Silicon install script (`install/install_nomad_mac.sh`)
- macOS Docker Compose configuration (`install/management_compose_mac.yaml`)
- macOS start/stop/update helper scripts
- Native Swift menu bar app (`mac-app/`)
- Platform detection for Apple Silicon GPU in the TypeScript services

**Please support the original project:**
- [GitHub — Crosstalk Solutions](https://github.com/Crosstalk-Solutions/project-nomad)
- [Website — projectnomad.us](https://www.projectnomad.us)
- [Discord Community](https://discord.com/invite/crosstalksolutions)

## License

Project N.O.M.A.D. is licensed under the [Apache License 2.0](LICENSE).
This fork maintains the same license. See [LICENSE](LICENSE) for full terms.
