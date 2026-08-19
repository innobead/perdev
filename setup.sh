#!/usr/bin/env bash
# setup.sh — PRIMARY entrypoint. Provisions the full development environment.
#
# Preferred over scripts/install.sh for initial setup — covers all steps in
# one run, continues past individual failures, and prints a summary.
# Safe to re-run: every step checks before acting.
#
# Usage:
#   bash setup.sh          # first run or re-run to retry failed steps
#
# Steps:
#   1. Nix          — built into NixOS; Determinate Systems installer on macOS
#   2. System       — nixos-rebuild or darwin-rebuild with embedded Home Manager
#   3. Rust         — rustup toolchain install stable
#   4. Docker       — NixOS service or Colima on macOS
#   5. AI tools     — verify Nix-managed tools, wire RTK hook, check gh copilot

# Do NOT use set -e — steps are independent; failures are tracked manually.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(uname -s)" == "Darwin" ]]; then
  IS_MAC=true; PROFILE="mac"
elif [[ -e /etc/NIXOS ]]; then
  IS_MAC=false; PROFILE="nixos"
else
  echo "Unsupported platform: perdev supports NixOS and macOS only." >&2
  exit 1
fi

# ── Colour helpers ────────────────────────────────────────────────────────────
G="\033[0;32m"; Y="\033[1;33m"; R="\033[0;31m"; B="\033[1m"; N="\033[0m"

# ── Step tracker ──────────────────────────────────────────────────────────────
declare -a _RESULTS=()

_step_result() {  # status label [detail]
  local icon
  case "$1" in
    PASS) icon="${G}✓${N}" ;;
    SKIP) icon="${Y}⊙${N}" ;;
    FAIL) icon="${R}✗${N}" ;;
    *)    icon="?" ;;
  esac
  _RESULTS+=("$1|$2|${3:-}")
  echo -e "${icon} $2${3:+ — $3}"
}

pass() { _step_result PASS "$@"; }
skip() { _step_result SKIP "$@"; }
fail() { _step_result FAIL "$@"; }
warn() { echo -e "${Y}!${N} $1${2:+ — $2}"; }

section() {
  echo ""
  echo -e "${B}┌── $* ──${N}"
}

# ── Env sourcing helpers ──────────────────────────────────────────────────────
source_nix() {
  local f="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  if [[ -f "$f" ]]; then
    set +u
    source "$f" 2>/dev/null || true
    set -u
  fi
  export PATH="/nix/var/nix/profiles/default/bin:${PATH:-}"
}

source_hm() {
  local f="${HOME}/.nix-profile/etc/profile.d/hm-session-vars.sh"
  if [[ -f "$f" ]]; then
    set +u
    source "$f" 2>/dev/null || true
    set -u
  fi
  export PATH="${HOME}/.nix-profile/bin:${HOME}/.local/bin:${PATH:-}"
}

# ─────────────────────────────────────────────────────────────────────────────
echo -e "${B}perdev setup — $(uname -s) / ${PROFILE}${N}"
echo "Repo: $REPO_DIR"

# ══ Step 1: Nix ══════════════════════════════════════════════════════════════
section "1/6  Nix"
source_nix
if ! $IS_MAC; then
  skip "Nix" "provided by NixOS — $(nix --version)"
elif command -v nix &>/dev/null; then
  skip "Nix" "already installed — $(nix --version)"
else
  echo "Installing Nix via Determinate Systems installer..."
  if curl -fsSL https://install.determinate.systems/nix \
       | sh -s -- install --no-confirm; then
    source_nix
    pass "Nix" "$(nix --version)"
  else
    fail "Nix" "installation failed — cannot continue"
    echo ""
    echo -e "${R}Nix is required. Fix the error above and re-run setup.sh.${N}"
    exit 1
  fi
fi

# ══ Step 1b: Homebrew (macOS only) ═══════════════════════════════════════════
if $IS_MAC; then
  section "1b/6  Homebrew"
  if command -v brew &>/dev/null; then
    skip "Homebrew" "already installed — $(brew --version | head -1)"
  else
    echo "Installing Homebrew..."
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
      # Add brew to PATH for the current session (Apple Silicon path)
      eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
      pass "Homebrew" "$(brew --version | head -1)"
    else
      fail "Homebrew" "installation failed — cannot continue on macOS"
      exit 1
    fi
  fi
  # Ensure brew is on PATH for subsequent steps
  eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
fi

# ══ Step 2: nix-darwin or NixOS, both with Home Manager ══════════════════════
if $IS_MAC; then
  section "2/6  nix-darwin + Home Manager — darwin-rebuild"
  echo "Profile: mac  (darwin.nix manages Homebrew packages; home.nix manages shell configs)"
  if sudo nix run nix-darwin#darwin-rebuild -- switch \
       --flake "${REPO_DIR}#mac" \
       --impure \
       -v 2>/dev/null || \
     sudo nix --extra-experimental-features "nix-command flakes" \
       run "github:nix-darwin/nix-darwin#darwin-rebuild" -- switch \
       --flake "${REPO_DIR}#mac" \
       --impure 2>/dev/null; then
    source_hm
    pass "nix-darwin + Home Manager"
  else
    # Fallback: home-manager only (skips system-level darwin config)
    echo "darwin-rebuild unavailable — falling back to home-manager switch..."
    if nix run nixpkgs#home-manager -- switch \
         --flake "${REPO_DIR}#mac" \
         --impure \
         -b bak \
         -v; then
      source_hm
      pass "Home Manager (nix-darwin fallback)"
    else
      fail "Home Manager" "switch failed — packages may be partially installed"
      source_hm
    fi
  fi
else
  section "2/6  NixOS + Home Manager — nixos-rebuild"
  echo "Profile: nixos  (nixos.nix manages the system; home.nix manages the user)"
  if sudo env PERDEV_USER="${PERDEV_USER:-$USER}" nixos-rebuild switch \
       --flake "${REPO_DIR}#nixos" \
       --impure; then
    source_hm
    pass "NixOS + Home Manager"
  else
    fail "NixOS" "switch failed — the previous generation remains active"
    source_hm
  fi
fi

# ══ Step 3: Rust stable toolchain ════════════════════════════════════════════
section "3/6  Rust stable toolchain"
if ! command -v rustup &>/dev/null; then
  fail "Rust" "rustup not found — Home Manager step may have failed"
elif rustup toolchain list 2>/dev/null | grep -q "^stable"; then
  skip "Rust" "stable toolchain already installed"
else
  echo "Installing Rust stable toolchain..."
  if rustup toolchain install stable \
       --component rust-analyzer \
       --component rustfmt \
       --component clippy \
     && rustup default stable; then
    pass "Rust" "$(rustc --version 2>/dev/null || true)"
  else
    fail "Rust" "rustup toolchain install failed"
  fi
fi

# ══ Step 4: Docker / container runtime ═══════════════════════════════════════
section "4/6  Docker / container runtime"
if $IS_MAC; then
  # macOS: Colima (Docker-compatible daemon via Apple VZ)
  if ! command -v colima &>/dev/null; then
    fail "Colima" "colima not found — Home Manager step may have failed"
  elif colima status 2>/dev/null | grep -q "Running"; then
    skip "Colima" "already running"
  else
    echo "Starting Colima (Apple VZ backend)..."
    if bash "${REPO_DIR}/scripts/docker-mac-setup.sh"; then
      pass "Colima"
    else
      fail "Colima" "startup failed — run: bash scripts/docker-mac-setup.sh"
    fi
  fi
else
  # NixOS: virtualisation.docker in nixos.nix owns the daemon and service.
  if systemctl is-active --quiet docker; then
    pass "Docker" "NixOS service active — $(docker --version)"
  else
    fail "Docker" "NixOS service is not active after rebuild"
  fi
fi

# ══ Step 5: AI tools ══════════════════════════════════════════════════════════
section "5/6  AI tools"
# On macOS: all AI tools (claude-code, gemini-cli, copilot-cli, antigravity,
#           rtk, ollama, llm) are brew-managed via darwin.nix.
# On NixOS: all AI tools are managed by Nix through home.nix.
# This step verifies availability and wires up hooks that need a running environment.

_ai_ok=true

# Verify AI tools are on PATH
for _tool in claude gemini agy rtk llm ollama; do
  if command -v "$_tool" &>/dev/null; then
    pass "$_tool" "$(if $IS_MAC; then echo 'installed via Homebrew'; else echo 'installed via Nix'; fi)"
  else
    warn "$_tool" "not found — open a new shell and re-run if this persists"
  fi
done

# GitHub Copilot CLI
if $IS_MAC; then
  # copilot-cli cask provides the standalone binary
  if command -v copilot &>/dev/null || command -v gh-copilot &>/dev/null; then
    pass "copilot-cli" "installed via Homebrew cask"
  else
    warn "copilot-cli" "not found — run: brew install --cask copilot-cli"
  fi
elif command -v gh &>/dev/null; then
  if gh copilot --version &>/dev/null; then
    pass "gh copilot" "built-in to gh"
  elif gh auth status &>/dev/null; then
    echo "Installing GitHub Copilot extension..."
    if gh extension install github/gh-copilot 2>&1; then
      pass "gh copilot"
    else
      warn "gh copilot" "extension install failed — run: gh auth login, then retry"
    fi
  else
    skip "gh copilot" "gh CLI not authenticated (run: gh auth login)"
  fi
else
  warn "gh copilot" "gh CLI not found"
fi

# Wire RTK → Claude Code hook (idempotent)
if command -v rtk &>/dev/null; then
  rtk init -g 2>/dev/null || true
fi

$_ai_ok && pass "AI tools" "all components installed" || true

# ══ Summary ═══════════════════════════════════════════════════════════════════
echo ""
echo -e "${B}── Summary ──────────────────────────────────${N}"
_any_fail=false
for r in "${_RESULTS[@]}"; do
  IFS='|' read -r status label detail <<< "$r"
  case "$status" in
    PASS) echo -e "  ${G}✓${N}  $label${detail:+  ($detail)}" ;;
    SKIP) echo -e "  ${Y}⊙${N}  $label${detail:+  ($detail)}" ;;
    FAIL) echo -e "  ${R}✗${N}  $label${detail:+  ($detail)}"; _any_fail=true ;;
  esac
done
echo -e "${B}─────────────────────────────────────────────${N}"
echo ""

if $_any_fail; then
  echo -e "${Y}Some steps failed or were skipped. Re-run setup.sh to retry.${N}"
  echo "Failed steps are safe to retry — setup.sh is idempotent."
  exit 1
else
  echo -e "${G}All steps completed successfully.${N}"
  echo ""
  echo "Open a new shell (or run: source ~/.bashrc) to start using the environment."
  $IS_MAC && echo "Ghostty will open Nushell automatically."
  echo ""
  echo -e "${B}Next steps:${N}"
  echo "  Pull a local LLM model (after opening a new shell, ollama daemon starts automatically):"
  echo "    ollama pull llama3.2        # ~2 GB, fast general model"
  echo "    ollama pull deepseek-r1     # ~4 GB, great for coding"
  echo "  Authenticate GitHub CLI (needed for gh copilot, PR workflows):"
  echo "    gh auth login"
fi
