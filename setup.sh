#!/usr/bin/env bash
# setup.sh — Single entrypoint to provision the full development environment.
#
# Runs all steps in sequence, continues past individual failures, and prints
# a summary at the end. Safe to re-run: every step checks before acting.
#
# Usage:
#   bash setup.sh          # first run or re-run to retry failed steps
#   nix run .#setup        # after Nix is installed (re-runs only)
#
# Steps:
#   1. Nix          — Determinate Systems installer
#   2. Home Manager — nix run nixpkgs#home-manager switch (all packages)
#   3. Rust         — rustup toolchain install stable
#   4. Docker       — Docker CE (Ubuntu) or Colima start (macOS)
#   5. AI tools     — Claude Code, Gemini CLI, gh Copilot, LLM plugins
#   6. Ollama models — pull llama3.2 if ollama daemon is reachable

# Do NOT use set -e — steps are independent; failures are tracked manually.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(uname -s)" == "Darwin" ]]; then
  IS_MAC=true; HM_PROFILE="mac"
else
  IS_MAC=false; HM_PROFILE="ubuntu"
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

section() {
  echo ""
  echo -e "${B}┌── $* ──${N}"
}

# ── Env sourcing helpers ──────────────────────────────────────────────────────
source_nix() {
  local f="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  [[ -f "$f" ]] && source "$f" 2>/dev/null || true
  export PATH="/nix/var/nix/profiles/default/bin:${PATH:-}"
}

source_hm() {
  local f="${HOME}/.nix-profile/etc/profile.d/hm-session-vars.sh"
  [[ -f "$f" ]] && source "$f" 2>/dev/null || true
  export PATH="${HOME}/.nix-profile/bin:${HOME}/.local/bin:${PATH:-}"
}

source_fnm() {
  if command -v fnm &>/dev/null; then
    eval "$(fnm env --shell bash 2>/dev/null)" || true
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
echo -e "${B}perdev setup — $(uname -s) / ${HM_PROFILE}${N}"
echo "Repo: $REPO_DIR"

# ══ Step 1: Nix ══════════════════════════════════════════════════════════════
section "1/6  Nix"
source_nix
if command -v nix &>/dev/null; then
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

# ══ Step 2: Home Manager (all packages) ══════════════════════════════════════
section "2/6  Home Manager — nix run"
echo "Profile: ${HM_PROFILE}  (applies home.nix — installs all packages)"
if nix run nixpkgs#home-manager -- switch \
     --flake "${REPO_DIR}#${HM_PROFILE}" \
     --impure \
     --backup-extension bak \
     -v 2>&1; then
  source_hm
  pass "Home Manager"
else
  fail "Home Manager" "switch failed — packages may be partially installed"
  source_hm  # source whatever was applied before the failure
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
       --component rust-analyzer rustfmt clippy \
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
  # Ubuntu: Docker CE via official apt repo
  if command -v docker &>/dev/null; then
    skip "Docker CE" "already installed — $(docker --version)"
  else
    echo "Installing Docker CE via apt..."
    if bash "${REPO_DIR}/scripts/docker-setup.sh"; then
      pass "Docker CE"
    else
      fail "Docker CE" "installation failed — run: bash scripts/docker-setup.sh"
    fi
  fi
fi

# ══ Step 5: AI tools ══════════════════════════════════════════════════════════
section "5/6  AI tools"
# Initialise fnm so npm is available; fall back to nix shell if fnm isn't ready.
source_fnm
if ! command -v node &>/dev/null; then
  echo "node not on PATH — bootstrapping via nix shell nixpkgs#nodejs..."
  # Run the npm installs via a nix shell so fnm is not required at this point.
  _npm_via_nix() {
    nix shell nixpkgs#nodejs --command npm install -g "$@"
  }
else
  _npm_via_nix() { npm install -g "$@"; }
fi

_ai_ok=true

# Claude Code
if command -v claude &>/dev/null; then
  skip "Claude Code" "already installed"
else
  echo "Installing Claude Code..."
  _npm_via_nix @anthropic-ai/claude-code || { fail "Claude Code" "npm install failed"; _ai_ok=false; }
  command -v claude &>/dev/null && pass "Claude Code"
fi

# Gemini CLI
if command -v gemini &>/dev/null; then
  skip "Gemini CLI" "already installed"
else
  echo "Installing Gemini CLI..."
  _npm_via_nix @google/gemini-cli || { fail "Gemini CLI" "npm install failed"; _ai_ok=false; }
  command -v gemini &>/dev/null && pass "Gemini CLI"
fi

# GitHub Copilot extension
if command -v gh &>/dev/null; then
  if gh extension list 2>/dev/null | grep -q "github/gh-copilot"; then
    skip "gh copilot" "already installed"
  else
    echo "Installing GitHub Copilot extension..."
    if gh extension install github/gh-copilot 2>/dev/null; then
      pass "gh copilot"
    else
      fail "gh copilot" "gh extension install failed"
      _ai_ok=false
    fi
  fi
else
  fail "gh copilot" "gh CLI not found"
  _ai_ok=false
fi

# LLM plugins
if command -v llm &>/dev/null; then
  echo "Installing LLM plugins..."
  for plugin in llm-claude-3 llm-gemini llm-ollama; do
    llm install "$plugin" 2>/dev/null \
      && pass "LLM plugin: $plugin" \
      || skip "LLM plugin: $plugin" "already installed or failed"
  done
else
  fail "LLM plugins" "llm not found — Home Manager step may have failed"
  _ai_ok=false
fi

$_ai_ok && pass "AI tools" "all components installed" || true

# ══ Step 6: Ollama — pull starter model ══════════════════════════════════════
section "6/6  Ollama starter model"
if ! command -v ollama &>/dev/null; then
  fail "Ollama" "ollama not found — Home Manager step may have failed"
elif ollama list 2>/dev/null | grep -q "llama3.2"; then
  skip "llama3.2" "already pulled"
else
  echo "Pulling llama3.2 (~2 GB)..."
  if ollama pull llama3.2; then
    pass "llama3.2"
  else
    fail "llama3.2" "pull failed — Ollama daemon may not be running yet"
    echo "  Retry after a new shell: ollama pull llama3.2"
  fi
fi

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
  echo "Ghostty will open Nushell automatically."
fi
