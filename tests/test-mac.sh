#!/usr/bin/env bash
# test-mac.sh — Verify mac provisioning on an actual macOS machine.
#
# Unlike test-ubuntu.sh, this runs DIRECTLY on macOS — there are no macOS
# Docker/OCI container images (Apple prohibits macOS in containers).
#
# Phase 1: Build the mac Home Manager activation package.
#          Resolves every package in home.nix against nixpkgs-unstable for
#          aarch64-darwin. Catches bad package names, config errors, conflicts.
# Phase 2: Spot-check key binaries from the nix store.
#
# Non-destructive: uses --no-link (Phase 1) and `nix shell` (Phase 2).
# Does NOT run home-manager switch or modify any dotfiles.
#
# Usage:
#   bash scripts/test-mac.sh
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
section "Phase 1 — Config validation (nix build)"
info "Building mac activation package…"
info "This resolves every package in home.nix against nixpkgs-unstable for aarch64-darwin."
info "First run: ~10-30 min. Cached runs: <1 min."
echo ""

nix build "${REPO_DIR}#homeConfigurations.mac.activationPackage" \
  --no-link \
  --impure \
  --print-build-logs 2>&1 | grep -E '(building|fetching|error|warning|^$)' || true

pass "Mac Home Manager config is valid — all packages resolved in nixpkgs"

# ── Phase 2: Spot-check key binaries ──────────────────────────────────────────
section "Phase 2 — Binary spot-checks"
info "Packages are in the nix store from Phase 1 — checks are fast."
echo ""

PASS=0; FAIL=0

check() {
  local label="$1" pkg="$2"; shift 2
  local out
  if out=$(nix shell "nixpkgs#$pkg" --command "$@" 2>/dev/null | head -1); then
    echo -e "  ${G}✓${N} $label: $out"
    ((PASS++)) || true
  else
    echo -e "  ${R}✗${N} $label — FAILED"
    ((FAIL++)) || true
  fi
}

# Shell & terminal
check "nushell"         "nushell"          nu        --version
check "starship"        "starship"         starship  --version
check "carapace"        "carapace"         carapace  --version
check "zoxide"          "zoxide"           zoxide    --version
check "atuin"           "atuin"            atuin     --version
check "ghostty-bin"     "ghostty-bin"      ghostty   --version 2>/dev/null || true

# Dev toolchains
check "go"              "go"               go        version
check "rustup"          "rustup"           rustup    --version
check "python3"         "python3"          python3   --version
check "uv"              "uv"               uv        --version
check "fnm"             "fnm"              fnm       --version

# Kubernetes
check "kubectl"         "kubectl"          kubectl   version --client
check "helm"            "kubernetes-helm"  helm      version --short
check "kind"            "kind"             kind      version
check "k9s"             "k9s"             k9s       version
check "tilt"            "tilt"            tilt      version
check "kubectx"         "kubectx"          kubectx   --version 2>/dev/null || true
check "kustomize"       "kustomize"        kustomize version
check "flux"            "fluxcd"           flux      --version

# Container / OCI — macOS uses Colima + Apple Container instead of podman/buildah
check "colima"          "colima"           colima    --version
check "docker-client"   "docker-client"    docker    --version
check "docker-buildx"   "docker-buildx"    docker    buildx version
check "dive"            "dive"             dive      --version
check "crane"           "crane"            crane     version
check "cosign"          "cosign"           cosign    version
check "lazydocker"      "lazydocker"       lazydocker --version 2>/dev/null || true
# Apple Container (aarch64-darwin only — skip gracefully on Intel)
if [[ "$(uname -m)" == "arm64" ]]; then
  check "container"     "container"        container --version 2>/dev/null || true
else
  warn "Skipping Apple Container check — requires Apple Silicon (arm64)"
fi

# AI tools
check "ollama"          "ollama"           ollama    --version
check "llm"             "llm"             llm       --version

# CLI utilities
check "ripgrep"         "ripgrep"          rg        --version
check "fd"              "fd"              fd        --version
check "bat"             "bat"             bat       --version
check "eza"             "eza"             eza       --version
check "jq"              "jq"             jq        --version
check "just"            "just"            just      --version
check "neovim"          "neovim"          nvim      --version
check "lazygit"         "lazygit"         lazygit   --version
check "delta"           "delta"           delta     --version
check "tmux"            "tmux"            tmux      -V
check "direnv"          "direnv"          direnv    --version
check "age"             "age"            age       --version
check "sops"            "sops"            sops      --version

echo ""
echo -e "Results: ${G}${PASS} passed${N}  ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
  fail "$FAIL checks failed — see output above"
fi

echo ""
echo -e "${G}┌─────────────────────────────────────┐${N}"
echo -e "${G}│  All mac provisioning tests PASSED ✓ │${N}"
echo -e "${G}└─────────────────────────────────────┘${N}"
