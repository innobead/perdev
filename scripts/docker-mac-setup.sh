#!/usr/bin/env bash
# docker-mac-setup.sh — Set up container tooling on macOS.
#
# All binaries are already installed by Nix (home.nix packages):
#   - colima       Docker-compatible container runtime via Apple Virtualization
#   - docker       Docker CLI (client only — daemon runs inside Colima VM)
#   - docker-buildx, docker-compose
#   - container    Apple Container CLI (native Apple VF, aarch64 only)
#
# This script starts Colima and verifies both tools work.
# Run in a new shell after install.sh so Nix-installed bins are on PATH.
#
# Container tool overview:
#   colima        → Provides Docker socket; `docker run`, `docker compose`, etc. work normally
#   container     → Apple's own OCI CLI; `container run`, `container pull`, etc.
#                   Uses Apple Virtualization framework directly (no Docker socket)
#   Socktainer    → Optional bridge: exposes Apple Container as a Docker socket
#                   (not in nixpkgs — install manually if needed)

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script is for macOS only. Use docker-setup.sh on Ubuntu." >&2
  exit 1
fi

# ── Verify Nix-installed tools are available ──────────────────────────────────
for bin in colima docker; do
  if ! command -v "$bin" &>/dev/null; then
    echo "ERROR: $bin not found. Run install.sh first and open a new shell." >&2
    exit 1
  fi
done

# ── Start Colima (Docker-compatible daemon) ───────────────────────────────────
if colima status 2>/dev/null | grep -q "Running"; then
  info "Colima is already running: $(colima status 2>/dev/null | grep 'runtime')"
else
  info "Starting Colima (Apple VZ backend, Docker runtime)..."
  # --vm-type vz    = Apple Virtualization framework (faster on Apple Silicon)
  # --mount-type virtiofs = fast file sharing between macOS and the VM
  colima start \
    --vm-type vz \
    --vz-rosetta \
    --mount-type virtiofs \
    --cpu 4 \
    --memory 8 \
    --disk 60
fi

info "Colima status:"
colima status

# ── Verify Docker CLI connects to Colima ──────────────────────────────────────
info "Testing Docker CLI..."
docker run --rm hello-world
info "Docker CLI via Colima: OK"

# ── Apple Container CLI ───────────────────────────────────────────────────────
if command -v container &>/dev/null; then
  info "Apple Container CLI available: $(container --version 2>/dev/null || echo 'installed')"
  info "Example: container run --rm docker.io/library/alpine:latest echo hello"
else
  warn "container CLI not found. It requires aarch64-darwin (Apple Silicon)."
  warn "Check: nix-env -iA nixpkgs.container"
fi

# ── Auto-start Colima on login (optional launchd agent) ──────────────────────
PLIST_PATH="$HOME/Library/LaunchAgents/com.local.colima.plist"
if [[ ! -f "$PLIST_PATH" ]]; then
  warn "Colima does not auto-start on login."
  warn "To enable auto-start, add this launchd agent:"
  cat <<PLIST

  # $PLIST_PATH
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
  <dict>
    <key>Label</key>          <string>com.local.colima</string>
    <key>ProgramArguments</key>
    <array>
      <string>$(command -v colima)</string>
      <string>start</string>
      <string>--vm-type</string>  <string>vz</string>
      <string>--vz-rosetta</string>
      <string>--mount-type</string> <string>virtiofs</string>
    </array>
    <key>RunAtLoad</key>      <true/>
    <key>StandardOutPath</key> <string>/tmp/colima.log</string>
    <key>StandardErrorPath</key> <string>/tmp/colima.err</string>
  </dict>
  </plist>

  Then: launchctl load $PLIST_PATH
PLIST
fi

echo ""
info "macOS container setup complete!"
info ""
info "Usage:"
info "  docker run ...          — via Colima Docker socket"
info "  docker compose up       — via Colima Docker socket"
info "  container run ...       — via Apple Container (native Apple VF)"
info "  colima stop             — stop the Colima VM"
info "  colima start            — restart the Colima VM"
