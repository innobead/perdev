#!/usr/bin/env bash
# perdev-update — Update the perdev workstation packages to the latest configuration.
#
# This script is automatically managed and installed by Home Manager to ~/.local/bin/perdev-update.

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Helper to print script usage
usage() {
  echo "Usage: perdev-update [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -u, --upgrade  Bypass flake.lock and fetch absolute latest package versions"
  echo "  -h, --help     Show this help message"
  echo ""
}

# Parse arguments
UPGRADE=false
for arg in "$@"; do
  case "$arg" in
    -u|--upgrade)
      UPGRADE=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      # Ignore other unknown args
      ;;
  esac
done

# Detect OS
if [[ "$(uname -s)" == "Darwin" ]]; then
  PROFILE="mac"
else
  PROFILE="ubuntu"
fi

REPO_DIR="${HOME}/.local/share/perdev"

# Ensure the parent directory exists
mkdir -p "$(dirname "$REPO_DIR")"

# Automate cloning if not already present
if [[ ! -d "$REPO_DIR" ]]; then
  info "Repository not found locally. Cloning to ${REPO_DIR}..."
  if ! git clone https://github.com/innobead/perdev.git "$REPO_DIR"; then
    error "Failed to clone repository. Please check your internet connection."
    exit 1
  fi
fi

cd "$REPO_DIR"

# Verify directory is a git repository
if [[ ! -d ".git" ]]; then
  error "${REPO_DIR} is not a valid git repository. Please remove it and re-run."
  exit 1
fi

info "Checking for remote configuration updates..."
# Fetch the latest commits
git fetch origin main

# Check if there are local uncommitted changes
if ! git diff-index --quiet HEAD --; then
  warn "Local repository has uncommitted changes. Stashing changes..."
  git stash
fi

# Merge changes
info "Pulling latest changes from main..."
git merge origin/main

# Build configuration switch command
CMD=(nix run nixpkgs#home-manager -- switch --flake ".#${PROFILE}" --impure -v)

if [[ "$UPGRADE" == "true" ]]; then
  info "Upgrading packages (recreating lock file)..."
  CMD+=(--recreate-lock-file)
fi

info "Applying updated configuration via Home Manager..."
if "${CMD[@]}"; then
  info "Workstation environment update completed successfully!"
else
  error "Failed to apply configuration updates."
  exit 1
fi
