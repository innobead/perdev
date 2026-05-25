#!/usr/bin/env bash
# perdev-update — Manage your perdev workstation environment.
#
# Installed by Home Manager to ~/.local/bin/perdev-update.
# Also usable as a one-line bootstrap:
#   curl -fsSL https://raw.githubusercontent.com/innobead/perdev/main/perdev-update.sh | bash
#
# Behaviour when run with no flags:
#   - If Home Manager is not yet active: runs a full install (setup.sh)
#   - If already installed: pulls latest config from git and reapplies

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
  cat <<EOF
Usage: perdev-update [OPTIONS]

Manage your perdev workstation environment.

Options:
  (no flags)         Install if not installed; upgrade (pull + switch) if installed
  --reinstall        Uninstall then reinstall from scratch
  --self-update      Replace this script with the latest version from GitHub
  --local-update     Update flake.lock to latest packages and reapply (no git pull)
  --rollback [N]     Roll back to generation N (default: previous generation)
  --diff [N]         Show package changes vs generation N (default: previous)
  --generations      List all Home Manager generations
  -h, --help         Show this help message

Examples:
  perdev-update                 # install or upgrade
  perdev-update --reinstall     # wipe and reinstall
  perdev-update --self-update   # update this script to the latest version
  perdev-update --local-update  # bump all nix packages to latest
  perdev-update --rollback      # undo the last switch
  perdev-update --diff          # see what changed in the last switch
  perdev-update --generations   # list all generations
EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────

MODE="auto"       # auto | reinstall | self-update | local-update | rollback | diff | generations
GEN_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reinstall)      MODE="reinstall"; shift ;;
    --self-update)    MODE="self-update"; shift ;;
    --local-update)   MODE="local-update"; shift ;;
    --rollback)       MODE="rollback"; shift
                      [[ $# -gt 0 && "$1" != --* ]] && { GEN_ARG="$1"; shift; } ;;
    --diff)           MODE="diff"; shift
                      [[ $# -gt 0 && "$1" != --* ]] && { GEN_ARG="$1"; shift; } ;;
    --generations)    MODE="generations"; shift ;;
    -h|--help)        usage; exit 0 ;;
    *)                warn "Unknown option: $1 (ignored)"; shift ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────

_is_installed() {
  home-manager generations 2>/dev/null | grep -q .
}

_detect_profile() {
  [[ "$(uname -s)" == "Darwin" ]] && echo "mac" || echo "ubuntu"
}

_profile_dir() {
  local d="$HOME/.local/state/nix/profiles"
  [[ -d "$d" ]] || d="/nix/var/nix/profiles/per-user/$USER"
  echo "$d"
}

_switch() {
  local profile; profile=$(_detect_profile)
  if [[ "$profile" == "mac" ]]; then
    # Use installed darwin-rebuild (handles HOME correctly); fall back to nix run on first install.
    local dr="/run/current-system/sw/bin/darwin-rebuild"
    if [[ -x "$dr" ]]; then
      sudo "$dr" switch --flake ".#${profile}" --impure -v
    else
      sudo nix run "github:nix-darwin/nix-darwin#darwin-rebuild" -- switch --flake ".#${profile}" --impure -v
    fi
    info "Configuration applied successfully."
  else
    nix run nixpkgs#home-manager -- switch --flake ".#${profile}" --impure -v
  fi
}

_clone_or_update_repo() {
  local repo_dir="$1"
  mkdir -p "$(dirname "$repo_dir")"
  if [[ ! -d "$repo_dir" ]]; then
    info "Cloning perdev repository to ${repo_dir}..."
    git clone https://github.com/innobead/perdev.git "$repo_dir"
  fi
  if [[ ! -d "$repo_dir/.git" ]]; then
    error "${repo_dir} is not a valid git repository. Remove it and re-run."
    exit 1
  fi
  cd "$repo_dir"
  info "Fetching latest changes..."
  git fetch origin main
  if ! git diff-index --quiet HEAD --; then
    warn "Local changes detected — stashing..."
    git stash
  fi
  git reset --hard origin/main
}

# ── Mode dispatch ─────────────────────────────────────────────────────────────

REPO_DIR="${HOME}/.local/share/perdev"

case "$MODE" in

  auto)
    if _is_installed; then
      info "Already installed — upgrading from remote..."
      _clone_or_update_repo "$REPO_DIR"
      _switch
      info "Upgrade complete."
    else
      info "Not installed — running full setup..."
      _clone_or_update_repo "$REPO_DIR"
      bash "$REPO_DIR/setup.sh"
    fi
    ;;

  reinstall)
    info "Force reinstalling perdev..."
    _clone_or_update_repo "$REPO_DIR"
    if [[ -f "$REPO_DIR/uninstall.sh" ]]; then
      bash "$REPO_DIR/uninstall.sh" --force
    fi
    bash "$REPO_DIR/setup.sh"
    ;;

  self-update)
    _SELF_URL="https://raw.githubusercontent.com/innobead/perdev/main/perdev-update.sh"
    _SELF="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "$0")"
    info "Downloading latest perdev-update from GitHub..."
    if curl -fsSL "$_SELF_URL" -o "${_SELF}.tmp"; then
      chmod +x "${_SELF}.tmp"
      mv "${_SELF}.tmp" "$_SELF"
      info "Self-update complete: $_SELF"
    else
      rm -f "${_SELF}.tmp"
      error "Download failed."
      exit 1
    fi
    ;;

  local-update)
    info "Updating flake.lock and reapplying configuration locally..."
    cd "$REPO_DIR"
    nix flake update
    _switch
    info "Local update complete."
    ;;

  rollback)
    if [[ -n "$GEN_ARG" ]]; then
      info "Rolling back to generation ${GEN_ARG}..."
      pdir=$(_profile_dir)
      link="$pdir/home-manager-${GEN_ARG}-link"
      if [[ ! -L "$link" ]]; then
        error "Generation ${GEN_ARG} not found in ${pdir}"
        exit 1
      fi
      "$link/activate"
    else
      info "Rolling back to previous generation..."
      home-manager switch --rollback
    fi
    ;;

  diff)
    pdir=$(_profile_dir)
    current_link="$pdir/home-manager"
    if [[ -n "$GEN_ARG" ]]; then
      target_link="$pdir/home-manager-${GEN_ARG}-link"
    else
      current_num=$(home-manager generations | head -1 | grep -o '[0-9]\+' | tail -1)
      prev=$((current_num - 1))
      if [[ "$prev" -lt 1 ]]; then
        warn "No previous generation found."
        exit 0
      fi
      target_link="$pdir/home-manager-${prev}-link"
    fi
    if [[ ! -L "$target_link" ]]; then
      error "Generation link not found: ${target_link}"
      exit 1
    fi
    nvd diff "$target_link" "$current_link"
    ;;

  generations)
    home-manager generations
    ;;

esac

