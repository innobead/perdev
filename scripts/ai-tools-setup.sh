#!/usr/bin/env bash
# ai-tools-setup.sh — Install AI development tools that require npm or special setup.
#
# Run this AFTER install.sh and in a fresh shell (so bun is on PATH).
#
# Installs:
#   - Claude Code CLI (@anthropic-ai/claude-code) via npm
#   - Gemini CLI (@google/gemini-cli) via npm
#   - GitHub Copilot extension via gh CLI
#   - LLM plugins (llm-claude-3, llm-gemini, llm-ollama) via pip/uvx
#   - RTK (Rust Token Killer) — filters CLI output noise before it hits the LLM
#
# Note: ollama and llm binaries are managed by Nix (home.nix packages).
# Note: aider was intentionally excluded; use `uvx aider` for one-off runs.

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Step 1: Ensure Bun is available ──────────────────────────────────────────
if ! command -v bun &>/dev/null; then
  error "bun not found. Run install.sh first and open a new shell."
  exit 1
fi
info "Bun available: $(bun --version)"

# ── Step 2: Claude Code CLI ───────────────────────────────────────────────────
if command -v claude &>/dev/null; then
  info "Claude Code already installed: $(claude --version 2>/dev/null || echo 'installed')"
else
  info "Installing Claude Code CLI..."
  bun install -g @anthropic-ai/claude-code
fi

# ── Step 3: Gemini CLI ────────────────────────────────────────────────────────
if command -v gemini &>/dev/null; then
  info "Gemini CLI already installed."
else
  info "Installing Gemini CLI..."
  bun install -g @google/gemini-cli
fi

# ── Step 4: GitHub Copilot CLI extension ──────────────────────────────────────
if command -v gh &>/dev/null; then
  if gh extension list 2>/dev/null | grep -q "github/gh-copilot"; then
    info "GitHub Copilot extension already installed."
  else
    info "Installing GitHub Copilot CLI extension..."
    gh extension install github/gh-copilot
  fi
else
  warn "gh CLI not found in PATH — skipping Copilot extension install."
  warn "(gh is managed by Nix; try opening a new shell after install.sh)"
fi

# ── Step 5: LLM plugins ───────────────────────────────────────────────────────
# The `llm` binary is installed via Nix (home.nix). Plugins extend it with
# support for Claude, Gemini, and local Ollama models.
if command -v llm &>/dev/null; then
  info "Installing LLM plugins..."
  llm install llm-claude-3 2>/dev/null || warn "llm-claude-3 install failed (may already be installed)"
  llm install llm-gemini 2>/dev/null   || warn "llm-gemini install failed (may already be installed)"
  llm install llm-ollama 2>/dev/null   || warn "llm-ollama install failed (may already be installed)"
  info "LLM plugins installed. Configure API keys with:"
  info "  llm keys set claude   # prompts for ANTHROPIC_API_KEY"
  info "  llm keys set gemini   # prompts for GEMINI_API_KEY"
else
  warn "llm not found — it is managed by Nix. Try opening a new shell."
fi

# ── Step 6: RTK (Rust Token Killer) ──────────────────────────────────────────
if command -v rtk &>/dev/null; then
  info "RTK already installed: $(rtk --version 2>/dev/null || echo 'installed')"
else
  info "Installing RTK (CLI output filter — 60-90% token savings)..."
  if [[ "$(uname -s)" == "Darwin" ]] && command -v brew &>/dev/null; then
    brew install rtk
  else
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
  fi
fi

if command -v rtk &>/dev/null; then
  info "Initialising RTK Claude Code hook..."
  rtk init -g 2>/dev/null || warn "rtk init -g failed — restart Claude Code after setup"
fi


echo ""
info "AI tools setup complete!"
info ""
info "Next steps:"
info "  Configure API keys in your shell (add to ~/.bashrc or nushell env.nu):"
info "    export ANTHROPIC_API_KEY=sk-ant-..."
info "    export GEMINI_API_KEY=..."
info ""
info "  Pull a local LLM model via Ollama (server auto-starts via systemd):"
info "    ollama pull llama3.2       # ~2GB, fast"
info "    ollama pull deepseek-r1    # ~4GB, great for coding"
info ""
info "  Test Claude Code:   claude --help"
info "  Test Gemini CLI:    gemini --help"
info "  Test LLM:           llm -m claude-3-5-haiku 'hello'"
info "  Test Ollama:        ollama run llama3.2"
info "  Test gh Copilot:    gh copilot suggest 'list all pods in a namespace'"
