#!/usr/bin/env bash
# Validate the NixOS system and its custom Linux packages without activating it.
#
# Usage:
#   bash tests/test-nixos.sh
#   just test-nixos

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "ERROR: NixOS validation requires an x86_64 Linux builder." >&2
  exit 1
fi

if ! command -v nix &>/dev/null; then
  echo "ERROR: Nix is required." >&2
  exit 1
fi

export PERDEV_USER="${PERDEV_USER:-perdev}"
NIX_FLAGS=(--extra-experimental-features "nix-command flakes")

echo "Building the NixOS system closure..."
nix "${NIX_FLAGS[@]}" build "path:${REPO_DIR}#nixosConfigurations.nixos.config.system.build.toplevel" \
  --no-link \
  --impure \
  --print-build-logs

echo "Building and running the custom bzr package..."
bzr_path="$(
  nix "${NIX_FLAGS[@]}" build "path:${REPO_DIR}#bzr" \
    --no-link \
    --print-out-paths
)"
"${bzr_path}/bin/bzr" --version

echo "NixOS provisioning checks passed."
