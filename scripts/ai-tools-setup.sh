#!/usr/bin/env bash
# ai-tools-setup.sh — Wire up AI tool hooks after provisioning has applied.
#
# On macOS: all AI tools are installed by Homebrew via darwin.nix
#   (claude-code cask, copilot-cli cask, gemini-cli, antigravity, rtk, ollama, llm)
# On Linux: all AI tools are managed by Nix via home.nix
#
# This script only:
#   - Verifies AI tools are on PATH
#   - Wires the RTK → Claude Code hook (rtk init -g)
#   - Checks GitHub Copilot CLI availability
#
# Run this AFTER setup.sh in a fresh shell (so PATH is active).

set -euo pipefail

if [[ "$(uname -s)" == "Darwin" ]]; then IS_MAC=true; else IS_MAC=false; fi

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

# ── Verify AI tools ───────────────────────────────────────────────────────────
_mgr="$(if $IS_MAC; then echo 'Homebrew'; else echo 'Nix'; fi)"
info "Checking ${_mgr}-managed AI tools..."
for _tool in claude gemini agy rtk llm ollama; do
  if command -v "$_tool" &>/dev/null; then
    info "  ✓ $_tool"
  else
    warn "  ✗ $_tool not found — open a new shell (${_mgr} profile may not be active yet)"
  fi
done

# ── RTK → Claude Code hook ────────────────────────────────────────────────────
if command -v rtk &>/dev/null; then
  info "Wiring RTK → Claude Code hook..."
  rtk init -g 2>/dev/null || warn "rtk init -g failed — restart Claude Code after setup"
fi

# ── GitHub Copilot CLI ────────────────────────────────────────────────────────
if $IS_MAC; then
  # copilot-cli Homebrew cask provides the standalone binary
  if command -v copilot &>/dev/null || command -v gh-copilot &>/dev/null; then
    info "copilot-cli: installed via Homebrew cask"
  else
    warn "copilot-cli not found — run: brew install --cask copilot-cli"
  fi
elif command -v gh &>/dev/null; then
  if gh copilot --version &>/dev/null; then
    info "gh copilot: built-in to gh (no extension needed)"
  elif gh auth status &>/dev/null; then
    info "Installing GitHub Copilot extension..."
    gh extension install github/gh-copilot 2>&1 || warn "gh extension install failed — run: gh auth login, then retry"
  else
    warn "gh CLI not authenticated — run: gh auth login"
  fi
else
  warn "gh CLI not found in PATH"
fi

echo ""
info "AI tools setup complete!"
info ""
info "Next steps:"
info "  Configure API keys:"
info "    export ANTHROPIC_API_KEY=sk-ant-..."
info "    export GEMINI_API_KEY=..."
info "    llm keys set claude   # for llm CLI"
info "    llm keys set gemini"
info ""
info "  Pull a local LLM model (open a new shell first — ollama daemon auto-starts):"
info "    ollama pull llama3.2       # ~2GB, fast"
info "    ollama pull deepseek-r1    # ~4GB, great for coding"
info ""
info "  Test tools:   claude --help | gemini --help | agy --help | copilot --help"
