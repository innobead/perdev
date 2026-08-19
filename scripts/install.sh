#!/usr/bin/env bash
# install.sh — Minimal NixOS or macOS system bootstrap.
#
# Use setup.sh (repo root) for a full environment setup including Docker,
# AI tools, and Ollama models. This script only handles steps 1-3 of setup.sh
# and is kept for backwards compatibility / CI use cases.
#
# Usage:
#   bash install.sh
#
# Idempotent: safe to run multiple times.
# Detects NixOS or macOS automatically.

set -euo pipefail

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Detect OS and pick the matching system profile
if [[ "$(uname -s)" == "Darwin" ]]; then
  PROFILE="${PROFILE:-mac}"
  IS_MAC=true
elif [[ -e /etc/NIXOS ]]; then
  PROFILE="${PROFILE:-nixos}"
  IS_MAC=false
else
  echo "Unsupported platform: perdev supports NixOS and macOS only." >&2
  exit 1
fi

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

info "Platform: $(uname -s) — using system profile '${PROFILE}'"

# ── Step 1: Install Nix ───────────────────────────────────────────────────────
if [[ "$IS_MAC" == "false" ]]; then
  info "Nix provided by NixOS: $(nix --version)"
elif command -v nix &>/dev/null; then
  info "Nix already installed: $(nix --version)"
else
  info "Installing Nix via Determinate Systems installer..."
  # DS installer enables flakes + nix-command and uses launchd on macOS.
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
fi

# ── Step 2: Source Nix environment ───────────────────────────────────────────
NIX_DAEMON_SH="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
if [[ -f "$NIX_DAEMON_SH" ]]; then
  # shellcheck source=/dev/null
  source "$NIX_DAEMON_SH"
elif [[ -f "/etc/profile.d/nix.sh" ]]; then
  # shellcheck source=/dev/null
  source "/etc/profile.d/nix.sh"
else
  export PATH="/nix/var/nix/profiles/default/bin:$PATH"
fi
info "Nix: $(nix --version)"

# ── Step 3: Apply configuration ──────────────────────────────────────────────
# --impure is required so builtins.getEnv "USER" / "HOME" resolve correctly.
if [[ "$IS_MAC" == "true" ]]; then
  # macOS: use nix-darwin for system-level config + Home Manager as a module.
  info "Applying nix-darwin config for macOS (user: $USER)..."
  sudo nix run "github:nix-darwin/nix-darwin#darwin-rebuild" -- switch \
       --flake "${FLAKE_DIR}#mac" \
       --impure
  info "nix-darwin configuration applied."
else
  info "Applying NixOS config with embedded Home Manager (user: $USER)..."
  sudo env PERDEV_USER="${PERDEV_USER:-$USER}" \
    nixos-rebuild switch --flake "${FLAKE_DIR}#nixos" --impure
  info "NixOS configuration applied."
fi

# ── Step 4: Register nushell as a valid login shell ───────────────────────────
NU_BIN="$(command -v nu 2>/dev/null || true)"
if [[ -n "$NU_BIN" ]]; then
  if [[ "$IS_MAC" == "true" ]] && ! grep -qF "$NU_BIN" /etc/shells; then
    info "Registering $NU_BIN in /etc/shells (sudo required)..."
    echo "$NU_BIN" | sudo tee -a /etc/shells >/dev/null
  fi
  info "Nushell: $NU_BIN"
  [[ "$IS_MAC" == "true" ]] \
    && info "Ghostty is configured to open nushell directly."
  info "Interactive bash sessions auto-switch to nushell (programs.bash.initExtra)."
else
  warn "nu not found in PATH — check home.nix packages."
fi

# ── Step 5: Install Rust stable toolchain ────────────────────────────────────
if command -v rustup &>/dev/null; then
  if ! rustup toolchain list 2>/dev/null | grep -q "^stable"; then
    info "Installing Rust stable toolchain..."
    rustup toolchain install stable \
      --component rust-analyzer \
      --component rustfmt \
      --component clippy
    rustup default stable
  else
    info "Rust stable toolchain already installed."
  fi
fi

# ── Step 6: Commit flake.lock ─────────────────────────────────────────────────
if [[ -f "${FLAKE_DIR}/flake.lock" ]] && command -v git &>/dev/null; then
  if git -C "${FLAKE_DIR}" status --porcelain flake.lock 2>/dev/null | grep -q .; then
    warn "flake.lock was generated/updated. Commit it to pin package versions:"
    warn "  git -C ${FLAKE_DIR} add flake.lock && git commit -m 'lock flake inputs'"
  fi
fi

echo ""
info "Bootstrap complete!"
info ""
if [[ "$IS_MAC" == "true" ]]; then
  info "macOS next steps (run in a new terminal):"
  info "  1. bash ${FLAKE_DIR}/scripts/docker-mac-setup.sh  — start Colima + Apple Container"
  info "  2. bash ${FLAKE_DIR}/scripts/ai-tools-setup.sh    — Claude Code, Gemini CLI, Antigravity CLI, Copilot"
  info "  3. ollama pull llama3.2                    — download a local LLM model"
  info "  4. Open Ghostty — it will launch nushell automatically"
  info ""
  info "  To apply macOS system defaults (Dock, Finder, Touch ID sudo, Homebrew):"
  info "    sudo darwin-rebuild switch --flake ${FLAKE_DIR}#mac --impure"
else
  info "NixOS next steps (run in a new terminal):"
  info "  1. bash ${FLAKE_DIR}/scripts/ai-tools-setup.sh — verify AI tools and wire RTK"
  info "  2. ollama pull llama3.2                       — download a local LLM model"
fi
