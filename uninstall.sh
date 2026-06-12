#!/usr/bin/env bash
# uninstall.sh — Remove all components installed by setup.sh.
#
# Runs steps in reverse order of setup.sh. Each step checks before acting
# and is safe to re-run if a previous attempt was partial.
#
# Usage:
#   bash uninstall.sh          # prompts for confirmation
#   bash uninstall.sh --force  # skip confirmation prompt

set -uo pipefail

if [[ "$(uname -s)" == "Darwin" ]]; then
  IS_MAC=true
else
  IS_MAC=false
fi

# ── Colour helpers ────────────────────────────────────────────────────────────
G="\033[0;32m"; Y="\033[1;33m"; R="\033[0;31m"; B="\033[1m"; N="\033[0m"

declare -a _RESULTS=()

_step_result() {
  local icon
  case "$1" in
    PASS) icon="${G}✓${N}" ;;
    SKIP) icon="${Y}⊙${N}" ;;
    FAIL) icon="${R}✗${N}" ;;
    *)    icon="?" ;;
  esac
  _RESULTS+=("$1|$2|${3:-}")
  echo -e "  ${icon} $2${3:+ — $3}"
}

pass() { _step_result PASS "$@"; }
skip() { _step_result SKIP "$@"; }
fail() { _step_result FAIL "$@"; }

section() {
  echo ""
  echo -e "${B}┌── $* ──${N}"
}

# ── Confirmation ──────────────────────────────────────────────────────────────
FORCE=false
for arg in "${@:-}"; do
  [[ "$arg" == "--force" ]] && FORCE=true
done

echo -e "${R}${B}perdev uninstall — $(uname -s)${N}"
echo ""
echo "This will remove:"
echo "  • AI tools: Claude Code, Gemini CLI, Copilot CLI, LLM plugins, RTK"
echo "  • Rust stable toolchain (rustup)"
$IS_MAC && echo "  • Colima VM and its data" || echo "  • Docker CE packages"
$IS_MAC && echo "  • nix-darwin system configuration (darwin-rebuild state, /etc patches)" || true
echo "  • Home Manager activation (symlinks and generated configs)"
echo "  • Nix (/nix store — all Nix-managed packages)"
echo ""
echo "NOT removed (manage manually if desired):"
$IS_MAC && echo "  • Homebrew and all brew-installed packages (darwin.nix formulae/casks)"
echo ""

if ! $FORCE; then
  read -rp "Type 'yes' to continue: " _confirm
  if [[ "$_confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# ── Step 1: AI tools ══════════════════════════════════════════════════════════
section "1/6  AI tools"

# RTK — remove hook and binary
if command -v rtk &>/dev/null; then
  echo "Removing RTK Claude Code hook..."
  rtk deinit -g 2>/dev/null || {
    _rtk_settings="${HOME}/.claude/settings.json"
    if [[ -f "$_rtk_settings" ]] && grep -q "rtk" "$_rtk_settings" 2>/dev/null; then
      echo "  (rtk deinit unavailable — please remove RTK hook from $_rtk_settings manually)"
    fi
  }
  # RTK is brew-managed on macOS; on Linux remove the binary directly
  if ! $IS_MAC; then
    rm -f "${HOME}/.local/bin/rtk" && pass "RTK" || skip "RTK" "binary not found at ~/.local/bin/rtk"
  else
    skip "RTK" "brew-managed on macOS — run: brew uninstall rtk"
  fi
else
  skip "RTK" "not installed"
fi

# claude-code, gemini-cli — brew cask/formula on macOS; nix on Linux
if $IS_MAC; then
  skip "claude-code" "brew-managed on macOS — run: brew uninstall --cask claude-code"
  skip "gemini-cli"  "brew-managed on macOS — run: brew uninstall gemini-cli"
else
  # On Linux these are nix packages; home-manager switch --impure removes them.
  # No manual removal needed here.
  skip "claude-code" "nix-managed on Linux — removed with Home Manager"
  skip "gemini-cli"  "nix-managed on Linux — removed with Home Manager"
fi

# Antigravity CLI — brew-managed on macOS; skip
if ! $IS_MAC && command -v agy &>/dev/null; then
  echo "Removing Antigravity CLI..."
  rm -f "${HOME}/.local/bin/agy" 2>/dev/null || true
  rm -rf "${HOME}/.gemini/antigravity-cli" 2>/dev/null || true
  pass "Antigravity CLI" "removed"
else
  skip "Antigravity CLI" "$(if $IS_MAC; then echo 'brew-managed on macOS — skipped'; else echo 'not installed'; fi)"
fi

# GitHub Copilot — copilot-cli cask on macOS; gh extension on Linux
if $IS_MAC; then
  skip "copilot-cli" "brew-managed on macOS — run: brew uninstall --cask copilot-cli"
elif command -v gh &>/dev/null && gh extension list 2>/dev/null | grep -q "github/gh-copilot"; then
  gh extension remove github/gh-copilot 2>/dev/null \
    && pass "gh copilot" || fail "gh copilot" "remove failed"
else
  skip "gh copilot" "not installed"
fi

# LLM plugins
if command -v llm &>/dev/null; then
  for _plugin in llm-claude-3 llm-gemini llm-ollama; do
    llm uninstall "$_plugin" -y 2>/dev/null \
      && pass "LLM plugin: $_plugin" \
      || skip "LLM plugin: $_plugin" "not installed"
  done
else
  skip "LLM plugins" "llm not found"
fi

# ── Step 2: Rust ══════════════════════════════════════════════════════════════
section "2/6  Rust"
if command -v rustup &>/dev/null; then
  echo "Removing Rust toolchains and rustup..."
  rustup self uninstall -y \
    && pass "Rust / rustup" || fail "Rust / rustup" "rustup self uninstall failed"
else
  skip "Rust" "rustup not installed"
fi

# ── Step 3: Docker / container runtime ═══════════════════════════════════════
section "3/6  Docker / container runtime"
if $IS_MAC; then
  if command -v colima &>/dev/null; then
    echo "Stopping and deleting Colima VM..."
    colima stop 2>/dev/null || true
    colima delete --force 2>/dev/null \
      && pass "Colima" "VM deleted" \
      || fail "Colima" "colima delete failed"
  else
    skip "Colima" "not installed"
  fi
else
  _docker_pkgs="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
  if dpkg -l docker-ce &>/dev/null 2>&1; then
    echo "Removing Docker CE packages..."
    # shellcheck disable=SC2086
    sudo apt-get remove -y $_docker_pkgs 2>/dev/null \
      && sudo apt-get autoremove -y 2>/dev/null \
      && pass "Docker CE" \
      || fail "Docker CE" "apt-get remove failed"
    sudo rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg 2>/dev/null || true
  else
    skip "Docker CE" "not installed via apt"
  fi
fi

# ── Step 4: nix-darwin (macOS only) ══════════════════════════════════════════
section "4/6  nix-darwin"
if $IS_MAC; then
  if command -v nix &>/dev/null; then
    echo "Running nix-darwin uninstaller (restores /etc files, removes system profile)..."
    if sudo nix --extra-experimental-features "nix-command flakes" run nix-darwin#darwin-uninstaller 2>/dev/null; then
      pass "nix-darwin" "system configuration removed"
    elif sudo nix --extra-experimental-features "nix-command flakes" \
           run "github:nix-darwin/nix-darwin#darwin-uninstaller" 2>/dev/null; then
      pass "nix-darwin" "system configuration removed (via github flake)"
    else
      fail "nix-darwin" "uninstaller failed — run manually: sudo nix run nix-darwin#darwin-uninstaller"
    fi
  else
    skip "nix-darwin" "nix not found — already removed or not installed"
  fi
else
  skip "nix-darwin" "Linux — not applicable"
fi

# ── Step 5: Home Manager ══════════════════════════════════════════════════════
section "5/6  Home Manager"
if $IS_MAC; then
  # On macOS, HM is embedded as a nix-darwin module — no standalone HM generation.
  # nix-darwin uninstaller (step 4) already removed generated configs and symlinks.
  skip "Home Manager" "macOS — managed as nix-darwin module; removed in step 4"
elif command -v home-manager &>/dev/null; then
  echo "Removing Home Manager activation (symlinks and generated configs)..."
  home-manager uninstall \
    && pass "Home Manager" \
    || fail "Home Manager" "uninstall failed"
elif command -v nix &>/dev/null; then
  echo "home-manager binary not on PATH — trying via nix run..."
  nix run nixpkgs#home-manager -- uninstall 2>/dev/null \
    && pass "Home Manager" \
    || fail "Home Manager" "nix run home-manager uninstall failed"
else
  skip "Home Manager" "neither home-manager nor nix found"
fi

# ── Step 6: Nix ══════════════════════════════════════════════════════════════
section "6/6  Nix"
if [[ -x /nix/nix-installer ]]; then
  echo "Running Determinate Systems uninstaller (/nix/nix-installer uninstall)..."
  /nix/nix-installer uninstall --no-confirm \
    && pass "Nix" "/nix removed" \
    || fail "Nix" "uninstaller failed — run manually: sudo /nix/nix-installer uninstall"
elif [[ -d /nix ]]; then
  fail "Nix" "/nix exists but /nix/nix-installer not found — uninstall manually"
else
  skip "Nix" "not installed"
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
  echo -e "${Y}Some steps failed. Re-run uninstall.sh to retry, or remove manually.${N}"
  exit 1
else
  echo -e "${G}Uninstall complete.${N}"
  echo "Open a new shell to clear any sourced Nix/Home Manager environment variables."
fi
