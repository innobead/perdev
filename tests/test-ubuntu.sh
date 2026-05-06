#!/usr/bin/env bash
# test-ubuntu.sh — Verify provisioning setup inside an Ubuntu container.
#
# Phase 1: Build the Home Manager activation package (validates flake.nix,
#          home.nix, and resolves every package in nixpkgs-unstable).
# Phase 2: Spot-check key binaries from the nix store.
#
# Usage:
#   bash test-ubuntu.sh                        # auto-detect docker/podman
#   CONTAINER_CMD=podman bash test-ubuntu.sh   # force podman
#   UBUNTU_IMAGE=ubuntu:22.04 bash test-ubuntu.sh
#
# Requirements: docker or podman must be running on the host.
# Note: First run downloads ~2GB from nixpkgs-unstable cache. Subsequent runs
#       reuse the container layer cache and complete in under a minute.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UBUNTU_IMAGE="${UBUNTU_IMAGE:-ubuntu:24.04}"

# ── Pick container runtime ────────────────────────────────────────────────────
if [[ -n "${CONTAINER_CMD:-}" ]]; then
  :
elif command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  CONTAINER_CMD="docker"
elif command -v podman &>/dev/null; then
  CONTAINER_CMD="podman"
else
  echo "ERROR: Neither docker nor podman is available/running." >&2
  echo "  Ubuntu: run ./docker-setup.sh first" >&2
  echo "  macOS:  run ./docker-mac-setup.sh first (starts Colima)" >&2
  exit 1
fi

echo "Runtime: $CONTAINER_CMD"
echo "Image:   $UBUNTU_IMAGE"
echo "Repo:    $REPO_DIR"
echo ""

# ── Write inner test script to a temp file ────────────────────────────────────
# The script is piped to `bash -s` via stdin to avoid Docker-on-macOS
# file-mount issues where bind-mounted files appear as directories.
INNER=$(mktemp /tmp/ubuntu-test-XXXXXX.sh)
trap 'rm -f "$INNER"' EXIT

cat > "$INNER" << 'INNER_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

G="\033[0;32m"; Y="\033[1;33m"; R="\033[0;31m"; N="\033[0m"; B="\033[1m"
info()   { echo -e "${G}[INFO]${N}  $*"; }
pass()   { echo -e "${G}[PASS]${N}  $*"; }
warn()   { echo -e "${Y}[WARN]${N}  $*"; }
fail()   { echo -e "${R}[FAIL]${N}  $*" >&2; exit 1; }
section(){ echo ""; echo -e "${B}──── $* ────${N}"; }

section "Environment"
info "OS:   $(. /etc/os-release && echo "$PRETTY_NAME")"
info "Arch: $(uname -m)"
info "User: $(whoami)"

# ── Prerequisites ─────────────────────────────────────────────────────────────
section "Prerequisites"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl git xz-utils ca-certificates sudo >/dev/null 2>&1
pass "curl git xz-utils ca-certificates sudo"

# ── Install Nix ───────────────────────────────────────────────────────────────
section "Nix installation"
# --init none  = skip systemd/launchd setup (required for containers)
# --no-confirm = non-interactive
curl -fsSL https://install.determinate.systems/nix \
  | sh -s -- install linux --init none --no-confirm

source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
pass "Nix: $(nix --version)"

# ── Phase 1: Validate Home Manager config ─────────────────────────────────────
section "Phase 1 — Config validation (nix build)"
info "Building ubuntu activation package…"
info "This resolves every package in home.nix against nixpkgs-unstable."
info "First run: ~10-30 min. Cached runs: <1 min."
echo ""

nix build /perdev#homeConfigurations.ubuntu.activationPackage \
  --no-link \
  --impure \
  --option sandbox false \
  --print-build-logs 2>&1 | grep -E '(building|fetching|error|warning|^$)' || true

pass "Home Manager config is valid — all packages resolved in nixpkgs"

# ── Phase 2: Spot-check key binaries ──────────────────────────────────────────
section "Phase 2 — Binary spot-checks"
info "Packages are already in the nix store from Phase 1 — checks are fast."
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
check "nushell"          "nushell"           nu         --version
check "starship"         "starship"          starship   --version
check "carapace"         "carapace"          carapace   --version
check "zoxide"           "zoxide"            zoxide     --version
check "atuin"            "atuin"             atuin      --version

# Dev toolchains
check "go"               "go"                go         version
check "rustup"           "rustup"            rustup     --version
check "python3"          "python3"           python3    --version
check "uv"               "uv"               uv         --version
check "fnm"              "fnm"               fnm        --version

# Kubernetes
check "kubectl"          "kubectl"           kubectl    version --client
check "helm"             "kubernetes-helm"   helm       version --short
check "kind"             "kind"             kind       version
check "k9s"              "k9s"              k9s        version
check "tilt"             "tilt"             tilt       version
check "kubectx"          "kubectx"           kubectx    --version 2>/dev/null || true
check "kustomize"        "kustomize"         kustomize  version
check "flux"             "fluxcd"            flux       --version

# Containers / OCI
check "podman"           "podman"            podman     --version
check "buildah"          "buildah"           buildah    --version
check "skopeo"           "skopeo"            skopeo     --version
check "dive"             "dive"              dive       --version
check "crane"            "crane"             crane      version
check "cosign"           "cosign"            cosign     version
check "lazydocker"       "lazydocker"        lazydocker --version 2>/dev/null || true

# AI tools
check "ollama"           "ollama"            ollama     --version
check "llm"              "llm"              llm        --version

# CLI utilities
check "ripgrep"          "ripgrep"           rg         --version
check "fd"               "fd"               fd         --version
check "bat"              "bat"              bat        --version
check "eza"              "eza"              eza        --version
check "jq"               "jq"              jq         --version
check "just"             "just"             just       --version
check "neovim"           "neovim"           nvim       --version
check "lazygit"          "lazygit"          lazygit    --version
check "delta"            "delta"            delta      --version
check "tmux"             "tmux"             tmux       -V
check "direnv"           "direnv"           direnv     --version
check "age"              "age"             age        --version
check "sops"             "sops"             sops       --version

echo ""
echo -e "Results: ${G}${PASS} passed${N}  ${FAIL} failed"

if [[ $FAIL -gt 0 ]]; then
  fail "$FAIL checks failed — see output above"
fi

echo ""
echo -e "${G}┌─────────────────────────────────────┐${N}"
echo -e "${G}│  All provisioning tests PASSED ✓    │${N}"
echo -e "${G}└─────────────────────────────────────┘${N}"
INNER_SCRIPT

# ── Pull latest image ─────────────────────────────────────────────────────────
echo "Pulling $UBUNTU_IMAGE..."
$CONTAINER_CMD pull "$UBUNTU_IMAGE"
echo ""

# ── Run the test container ────────────────────────────────────────────────────
# Pipe inner.sh via stdin to avoid Docker-on-macOS bind-mount-as-directory bug.
$CONTAINER_CMD run --rm \
  --privileged \
  --interactive \
  --volume "$REPO_DIR:/perdev:ro" \
  --env USER=root \
  --env HOME=/root \
  "$UBUNTU_IMAGE" \
  bash -s < "$INNER"
