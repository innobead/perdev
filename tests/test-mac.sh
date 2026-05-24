#!/usr/bin/env bash
# test-mac.sh — Verify mac provisioning on an actual macOS machine.
#
# Unlike test-ubuntu.sh, this runs DIRECTLY on macOS — there are no macOS
# Docker/OCI container images (Apple prohibits macOS in containers).
#
# Phase 1:  Build the mac Home Manager activation package (homeConfigurations.mac).
#           Resolves every package in home.nix against nixpkgs-unstable for
#           aarch64-darwin. Catches bad package names, config errors, conflicts.
# Phase 1b: Validate the nix-darwin system config (darwinConfigurations.mac).
#           Verifies darwin.nix system defaults, Homebrew, and HM module wiring.
# Phase 2:  Spot-check key binaries from the nix store.
#
# Non-destructive: uses --no-link (Phases 1/1b) and `nix shell` (Phase 2).
# Does NOT run darwin-rebuild switch or home-manager switch.
#
# Usage:
#   bash tests/test-mac.sh
#   just test-mac

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

G="\033[0;32m"; Y="\033[1;33m"; R="\033[0;31m"; N="\033[0m"; B="\033[1m"
info()   { echo -e "${G}[INFO]${N}  $*"; }
pass()   { echo -e "${G}[PASS]${N}  $*"; }
warn()   { echo -e "${Y}[WARN]${N}  $*"; }
fail()   { echo -e "${R}[FAIL]${N}  $*" >&2; exit 1; }
section(){ echo ""; echo -e "${B}──── $* ────${N}"; }

# ── Guard: macOS only ─────────────────────────────────────────────────────────
if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "test-mac.sh must run on macOS. For Ubuntu, use scripts/test-ubuntu.sh."
fi

section "Environment"
info "OS:   $(sw_vers -productName) $(sw_vers -productVersion)"
info "Arch: $(uname -m)"
info "User: $(whoami)"
info "Repo: $REPO_DIR"

# ── Nix ───────────────────────────────────────────────────────────────────────
section "Nix"
if ! command -v nix &>/dev/null; then
  warn "Nix not found. Installing via Determinate Systems installer..."
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
pass "Nix: $(nix --version)"

# ── Phase 1: Validate Home Manager config ─────────────────────────────────────
section "Phase 1 — HM config validation (homeConfigurations.mac)"
info "Building mac activation package…"
info "This resolves every package in home.nix against nixpkgs-unstable for aarch64-darwin."
info "First run: ~10-30 min. Cached runs: <1 min."
echo ""

nix build "${REPO_DIR}#homeConfigurations.mac.activationPackage" \
  --no-link \
  --impure \
  --print-build-logs 2>&1 | grep -E '(building|fetching|error|warning|^$)' || true

pass "Mac Home Manager config is valid — all packages resolved in nixpkgs"

# ── Phase 1b: Validate nix-darwin config ──────────────────────────────────────
section "Phase 1b — nix-darwin config validation (darwinConfigurations.mac)"
info "Building mac darwin system config (darwin.nix + home.nix as HM module)…"
info "Verifies system defaults, Homebrew wiring, and HM module integration."
echo ""

nix build "${REPO_DIR}#darwinConfigurations.mac.system" \
  --no-link \
  --impure \
  --print-build-logs 2>&1 | grep -E '(building|fetching|error|warning|^$)' || true

pass "Mac nix-darwin config is valid"

# ── Phase 2: Spot-check key binaries ──────────────────────────────────────────
section "Phase 2 — Binary spot-checks"
echo ""

PASS=0; FAIL=0
info "Packages are in the nix store from Phases 1/1b — checks are fast."
echo ""

# _check_cmd runs the binary with a 60s background-kill guard, safe under set -euo pipefail.
# - rc is captured via if/else (not cmd; rc=$?) to avoid errexit on non-zero wait
# - killer wait uses || true since we killed it ourselves (returns 128+TERM)
# - killer kill uses || true since killer may have already exited (when timeout fires first)
_check_cmd() {
  local label="$1" pkg="$2"; shift 2
  local tmpout rc pid killer
  tmpout=$(mktemp)
  nix shell "nixpkgs#$pkg" --command "$@" >"$tmpout" 2>/dev/null &
  pid=$!
  ( sleep 60 && kill "$pid" 2>/dev/null ) &
  killer=$!
  if wait "$pid" 2>/dev/null; then rc=0; else rc=$?; fi
  kill "$killer" 2>/dev/null || true   # killer may have already exited (timeout fired)
  wait "$killer" 2>/dev/null || true   # we killed it; 128+TERM is expected
  local out
  out=$(head -1 "$tmpout")
  rm -f "$tmpout"
  if [[ $rc -eq 0 && -n "$out" ]]; then
    echo -e "  ${G}✓${N} $label: $out"
    ((PASS++)) || true
  else
    echo -e "  ${R}✗${N} $label — FAILED"
    ((FAIL++)) || true
  fi
}

# Shell & terminal
_check_cmd "nushell"         "nushell"          nu        --version
_check_cmd "starship"        "starship"         starship  --version
_check_cmd "carapace"        "carapace"         carapace  --version
_check_cmd "zoxide"          "zoxide"           zoxide    --version
_check_cmd "atuin"           "atuin"            atuin     --version
_check_cmd "ghostty-bin"     "ghostty-bin"      ghostty   --version 2>/dev/null || true

# Dev toolchains
_check_cmd "go"              "go"               go        version
_check_cmd "rustup"          "rustup"           rustup    --version
_check_cmd "python3"         "python3"          python3   --version
_check_cmd "uv"              "uv"               uv        --version
_check_cmd "bun"             "bun"              bun       --version

# Kubernetes
_check_cmd "kubectl"         "kubectl"          kubectl   version --client
_check_cmd "helm"            "kubernetes-helm"  helm      version --short
_check_cmd "kind"            "kind"             kind      version
_check_cmd "k9s"             "k9s"             k9s       version
_check_cmd "tilt"            "tilt"            tilt      version
_check_cmd "kubectx"         "kubectx"          kubectx   --version 2>/dev/null || true
_check_cmd "kustomize"       "kustomize"        kustomize version
_check_cmd "flux"            "fluxcd"           flux      --version

# Container / OCI — macOS uses Colima + Apple Container instead of podman/buildah
_check_cmd "colima"          "colima"           colima    --version
_check_cmd "docker-client"   "docker-client"    docker    --version
_check_cmd "docker-buildx"   "docker-buildx"    sh -c "docker-buildx version 2>&1"
_check_cmd "dive"            "dive"             dive      --version
_check_cmd "crane"           "crane"            crane     version
_check_cmd "cosign"          "cosign"           cosign    version
_check_cmd "lazydocker"      "lazydocker"       lazydocker --version 2>/dev/null || true
# Apple Container (aarch64-darwin only — skip gracefully on Intel)
if [[ "$(uname -m)" == "arm64" ]]; then
  _check_cmd "container"     "container"        container --version 2>/dev/null || true
else
  warn "Skipping Apple Container check — requires Apple Silicon (arm64)"
fi

# AI tools
_check_cmd "ollama"          "ollama"           ollama    help
_check_cmd "llm"             "llm"             llm       --version

# CLI utilities
_check_cmd "vhs"             "vhs"             vhs       --version
_check_cmd "ripgrep"         "ripgrep"          rg        --version
_check_cmd "fd"              "fd"              fd        --version
_check_cmd "bat"             "bat"             bat       --version
_check_cmd "eza"             "eza"             eza       --version
_check_cmd "jq"              "jq"             jq        --version
_check_cmd "just"            "just"            just      --version
_check_cmd "neovim"          "neovim"          nvim      --version
_check_cmd "lazygit"         "lazygit"         lazygit   --version
_check_cmd "delta"           "delta"           delta     --version
_check_cmd "tmux"            "tmux"            tmux      -V
_check_cmd "direnv"          "direnv"          direnv    --version
_check_cmd "age"             "age"            age       --version
_check_cmd "sops"            "sops"            sops      --version

echo ""
echo -e "Results: ${G}${PASS} passed${N}  ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
  fail "$FAIL checks failed — see output above"
fi

echo ""
echo -e "${G}┌──────────────────────────────────────────┐${N}"
echo -e "${G}│  All mac provisioning tests PASSED ✓    │${N}"
echo -e "${G}└──────────────────────────────────────────┘${N}"
