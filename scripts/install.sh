#!/usr/bin/env bash
# install.sh — Bootstrap Ubuntu or macOS with Nix + Home Manager
#
# Usage:
#   bash install.sh
#
# Idempotent: safe to run multiple times.
# Detects OS automatically: uses profile "ubuntu" on Linux, "mac" on macOS.
# After: run docker-setup.sh (Linux) or docker-mac-setup.sh (macOS),
#        then ai-tools-setup.sh in a new shell.

set -euo pipefail

FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Detect OS and pick the matching Home Manager profile
if [[ "$(uname -s)" == "Darwin" ]]; then
  HM_PROFILE="${HM_PROFILE:-mac}"
  IS_MAC=true
else
  HM_PROFILE="${HM_PROFILE:-ubuntu}"
  IS_MAC=false
fi

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

info "Platform: $(uname -s) — using Home Manager profile '${HM_PROFILE}'"

# ── Step 1: Install Nix ───────────────────────────────────────────────────────
if command -v nix &>/dev/null; then
  info "Nix already installed: $(nix --version)"
else
  info "Installing Nix via Determinate Systems installer..."
  # DS installer: enables flakes + nix-command by default.
  # On Ubuntu: multi-user install via systemd.
  # On macOS: multi-user install via launchd.
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

# ── Step 3: Apply Home Manager configuration ──────────────────────────────────
# --impure is required so builtins.getEnv "USER" / "HOME" resolve correctly.
info "Applying Home Manager config for profile '${HM_PROFILE}' (user: $USER)..."
nix run nixpkgs#home-manager -- switch \
  --flake "${FLAKE_DIR}#${HM_PROFILE}" \
  --impure \
  --backup-extension bak \
  -v

info "Home Manager configuration applied."

# ── Step 4: Register nushell as a valid login shell ───────────────────────────
NU_BIN="$(command -v nu 2>/dev/null || true)"
if [[ -n "$NU_BIN" ]]; then
  if ! grep -qF "$NU_BIN" /etc/shells; then
    info "Registering $NU_BIN in /etc/shells (sudo required)..."
    echo "$NU_BIN" | sudo tee -a /etc/shells >/dev/null
  fi
  info "Nushell: $NU_BIN"
  info "Ghostty is configured to open nushell directly (programs.ghostty.settings.command)."
  info "Interactive bash sessions auto-switch to nushell (programs.bash.initExtra)."
else
  warn "nu not found in PATH — check home.nix packages."
fi

# ── Step 5: Install Rust stable toolchain ────────────────────────────────────
if command -v rustup &>/dev/null; then
  if ! rustup toolchain list 2>/dev/null | grep -q "^stable"; then
    info "Installing Rust stable toolchain..."
    rustup toolchain install stable --component rust-analyzer rustfmt clippy
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
  info "  2. bash ${FLAKE_DIR}/scripts/ai-tools-setup.sh    — Claude Code, Gemini CLI, Copilot"
  info "  3. ollama pull llama3.2                    — download a local LLM model"
  info "  4. Open Ghostty — it will launch nushell automatically"
else
  info "Ubuntu next steps (run in a new terminal):"
  info "  1. bash ${FLAKE_DIR}/scripts/docker-setup.sh      — install Docker CE"
  info "  2. bash ${FLAKE_DIR}/scripts/ai-tools-setup.sh    — Claude Code, Gemini CLI, Copilot"
  info "  3. ollama pull llama3.2                    — download a local LLM model"
  info "  4. Open Ghostty — it will launch nushell automatically"
fi
