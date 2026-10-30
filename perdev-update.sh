#!/usr/bin/env bash
# perdev-update — Manage your perdev workstation environment.
#
# Installed by Home Manager to ~/.local/bin/perdev-update.
# Also usable as a one-line bootstrap:
#   curl -fsSL https://raw.githubusercontent.com/innobead/perdev/main/perdev-update.sh | bash
#
# Behaviour when run with no flags:
#   - If perdev is not yet active: runs a full install (setup.sh)
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
    --brew-upgrade     macOS: upgrade Homebrew packages only (no Nix switch)
    --no-brew          macOS: skip the Homebrew upgrade after an upgrade/local-update
    --rollback [N]     Roll back to generation N (default: previous generation)
    --diff [N]         Show package changes vs generation N (default: previous)
    --generations      List all system generations
    -h, --help         Show this help message

On macOS, upgrade and --local-update also upgrade Homebrew formulae and casks
and report Homebrew packages that are not declared in darwin.nix.

Examples:
    perdev-update                 # install or upgrade
    perdev-update --no-brew       # upgrade Nix configuration only
    perdev-update --reinstall     # wipe and reinstall
    perdev-update --self-update   # update this script to the latest version
    perdev-update --local-update  # bump all nix packages to latest
    perdev-update --brew-upgrade  # upgrade Homebrew packages only
    perdev-update --rollback      # undo the last switch
    perdev-update --diff          # see what changed in the last switch
    perdev-update --generations   # list all generations
EOF
}

# ── Argument parsing ──────────────────────────────────────────────────────────

MODE="auto"       # auto | reinstall | self-update | local-update | brew-upgrade | rollback | diff | generations
GEN_ARG=""
BREW_UPGRADE=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reinstall)      MODE="reinstall"; shift ;;
    --self-update)    MODE="self-update"; shift ;;
    --local-update)   MODE="local-update"; shift ;;
    --brew-upgrade)   MODE="brew-upgrade"; shift ;;
    --no-brew)        BREW_UPGRADE=false; shift ;;
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
  [[ -x "${HOME}/.local/bin/perdev-update" ]]
}

_detect_profile() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "mac"
  elif [[ -e /etc/NIXOS ]]; then
    echo "nixos"
  else
    error "Unsupported platform: perdev supports NixOS and macOS only."
    return 1
  fi
}

_darwin_rebuild() {
  local dr="/run/current-system/sw/bin/darwin-rebuild"
  if [[ -x "$dr" ]]; then
    sudo "$dr" "$@"
  else
    sudo nix run "github:nix-darwin/nix-darwin#darwin-rebuild" -- "$@"
  fi
}

_switch() {
  local profile; profile=$(_detect_profile)
  if [[ "$profile" == "mac" ]]; then
    _darwin_rebuild switch --flake ".#${profile}" --impure -v
    info "Configuration applied successfully."
  else
    sudo env PERDEV_USER="${PERDEV_USER:-$USER}" \
      nixos-rebuild switch --flake ".#nixos" --impure
    info "Configuration applied successfully."
  fi
}

_brew_bin() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    echo /opt/homebrew/bin/brew
  fi
}

# Warn about Homebrew packages installed on request but not declared in darwin.nix.
_brew_report_unmanaged() {
  local flake_dir="$1" brew="$2" jq_bin declared_brews declared_casks
  jq_bin=$(command -v jq || true)
  [[ -x "$jq_bin" ]] || jq_bin=/opt/homebrew/bin/jq
  if [[ ! -x "$jq_bin" ]]; then
    warn "jq not found — skipping unmanaged Homebrew package check."
    return 0
  fi

  if ! declared_brews=$(nix eval --impure --raw "${flake_dir}#darwinConfigurations.mac.config.homebrew.brews" \
        --apply 'bs: builtins.concatStringsSep " " (map (b: b.name) bs)' 2>/dev/null) ||
     ! declared_casks=$(nix eval --impure --raw "${flake_dir}#darwinConfigurations.mac.config.homebrew.casks" \
        --apply 'cs: builtins.concatStringsSep " " (map (c: c.name) cs)' 2>/dev/null); then
    warn "Could not read Homebrew packages from darwin.nix — skipping unmanaged package check."
    return 0
  fi

  # Resolve core aliases (e.g. kubectl → kubernetes-cli) to installed names.
  # Tap formulae (owner/tap/name) are matched by their short name, so untrusted
  # taps never need to be loaded.
  local core_brews=() tap_brew_names=() b
  local declared_formula_names declared_cask_names unmanaged_formulae unmanaged_casks
  for b in $declared_brews; do
    if [[ "$b" == */*/* ]]; then tap_brew_names+=("${b##*/}"); else core_brews+=("$b"); fi
  done
  declared_formula_names=$(
    {
      printf '%s\n' ${tap_brew_names[@]+"${tap_brew_names[@]}"}
      "$brew" info --json=v2 --formula ${core_brews[@]+"${core_brews[@]}"} 2>/dev/null \
        | "$jq_bin" -r '.formulae[] | .full_name, .name' || true
    } | sort -u)
  # shellcheck disable=SC2086
  declared_cask_names=$(
    {
      printf '%s\n' $declared_casks
      "$brew" info --json=v2 --cask $declared_casks 2>/dev/null \
        | "$jq_bin" -r '.casks[] | .full_token, .token' || true
    } | sort -u)

  # Leaves exclude dependencies; trusted tap formulae are listed as owner/tap/name.
  # Formulae from untrusted taps cannot be loaded, so leaves omits them; add any
  # installed formula Homebrew cannot load.
  local leaves loadable untrusted_installed
  leaves=$("$brew" leaves --installed-on-request | sed 's#.*/##')
  loadable=$("$brew" info --json=v2 --installed 2>/dev/null | "$jq_bin" -r '.formulae[].name' || true)
  untrusted_installed=$(comm -23 <("$brew" list --formula -1 | sort -u) <(echo "$loadable" | sort -u))
  unmanaged_formulae=$(comm -23 <(printf '%s\n%s\n' "$leaves" "$untrusted_installed" | sed '/^$/d' | sort -u) \
    <(echo "$declared_formula_names"))
  unmanaged_casks=$(comm -23 <("$brew" list --cask -1 | sort -u) <(echo "$declared_cask_names"))

  if [[ -z "$unmanaged_formulae" && -z "$unmanaged_casks" ]]; then
    info "All installed Homebrew packages are declared in darwin.nix."
    return 0
  fi
  warn "Homebrew packages installed but not declared in darwin.nix:"
  [[ -n "$unmanaged_formulae" ]] && echo "$unmanaged_formulae" | sed 's/^/    formula: /'
  [[ -n "$unmanaged_casks" ]] && echo "$unmanaged_casks" | sed 's/^/    cask:    /'
  warn "Add them to darwin.nix to keep them, or 'brew uninstall' them."
}

# Homebrew's bin precedes ~/.nix-profile/bin on PATH, so a Homebrew copy of a
# Nix-managed shell tool silently replaces the version Home Manager configured.
_brew_check_shadowing() {
  local brew="$1" prefix tool shadowed=()
  prefix=$("$brew" --prefix)
  for tool in nu starship carapace zoxide atuin; do
    [[ -e "$prefix/bin/$tool" ]] && shadowed+=("$tool")
  done
  [[ ${#shadowed[@]} -eq 0 ]] && return 0
  warn "Homebrew copies shadow Nix-managed tools: ${shadowed[*]}"
  warn "Remove them with 'brew uninstall' (nu is provided by the nushell formula)."
}

# Upgrade Homebrew packages (macOS only). nix-darwin's onActivation.upgrade stays
# false so that switches and rollbacks never mutate Homebrew.
_brew_upgrade() {
  local flake_dir="$1" brew
  [[ "$(uname -s)" == "Darwin" ]] || return 0
  brew=$(_brew_bin)
  if [[ -z "$brew" ]]; then
    warn "Homebrew not found — skipping Homebrew upgrade."
    return 0
  fi
  _brew_check_shadowing "$brew"
  if [[ "$BREW_UPGRADE" != true ]]; then
    info "Skipping Homebrew upgrade (--no-brew)."
    return 0
  fi

  info "Upgrading Homebrew packages..."
  "$brew" update || warn "brew update failed."
  "$brew" upgrade --formula || warn "brew upgrade --formula failed."
  "$brew" upgrade --cask --greedy || warn "brew upgrade --cask failed."
  _brew_report_unmanaged "$flake_dir" "$brew"
}

_system_current_generation() {
  local target
  target=$(readlink /nix/var/nix/profiles/system)
  [[ "$target" =~ system-([0-9]+)-link$ ]] || {
    error "Could not determine the current system generation."
    return 1
  }
  echo "${BASH_REMATCH[1]}"
}

_system_previous_generation() {
  local current candidate
  current=$(_system_current_generation)
  while IFS= read -r candidate; do
    if (( candidate < current )); then
      echo "$candidate"
      return 0
    fi
  done < <(
    find /nix/var/nix/profiles -maxdepth 1 -type l -name 'system-*-link' \
      -exec basename {} \; \
      | sed -E 's/system-([0-9]+)-link/\1/' \
      | sort -rn
  )
  error "No previous system generation found."
  return 1
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
      _brew_upgrade "$REPO_DIR"
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
    # Always write to the install location — realpath would resolve the HM
    # symlink into the read-only Nix store, making the write fail.
    _SELF="${HOME}/.local/bin/perdev-update"
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
    _brew_upgrade "$REPO_DIR"
    info "Local update complete."
    ;;

  brew-upgrade)
    if [[ "$(uname -s)" != "Darwin" ]]; then
      error "--brew-upgrade is only supported on macOS."
      exit 1
    fi
    # Prefer the checkout this script lives in (e.g. `just`), else the installed clone.
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$script_dir/flake.nix" ]]; then flake_dir="$script_dir"; else flake_dir="$REPO_DIR"; fi
    BREW_UPGRADE=true
    _brew_upgrade "$flake_dir"
    info "Homebrew upgrade complete."
    ;;

  rollback)
    profile=$(_detect_profile)
    if [[ "$profile" == "nixos" ]]; then
      if [[ -n "$GEN_ARG" ]]; then
        link="/nix/var/nix/profiles/system-${GEN_ARG}-link"
        if [[ ! -L "$link" ]]; then
          error "NixOS generation ${GEN_ARG} not found."
          exit 1
        fi
        info "Switching to NixOS generation ${GEN_ARG}..."
        sudo nix-env --profile /nix/var/nix/profiles/system \
          --switch-generation "$GEN_ARG"
        sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
      else
        info "Rolling back to the previous NixOS generation..."
        sudo nixos-rebuild switch --rollback
      fi
    elif [[ -n "$GEN_ARG" ]]; then
      link="/nix/var/nix/profiles/system-${GEN_ARG}-link"
      if [[ ! -L "$link" ]]; then
        error "macOS system generation ${GEN_ARG} not found."
        exit 1
      fi
      info "Switching to macOS system generation ${GEN_ARG}..."
      _darwin_rebuild switch --switch-generation "$GEN_ARG"
    else
      info "Rolling back to the previous macOS system generation..."
      _darwin_rebuild switch --rollback
    fi
    ;;

  diff)
    profile=$(_detect_profile)
    if [[ "$profile" == "nixos" ]]; then
      current_link="/run/current-system"
      generation="${GEN_ARG:-$(_system_previous_generation)}"
      target_link="/nix/var/nix/profiles/system-${generation}-link"
    else
      current_link="/run/current-system"
      generation="${GEN_ARG:-$(_system_previous_generation)}"
      target_link="/nix/var/nix/profiles/system-${generation}-link"
    fi
    if [[ ! -L "$target_link" ]]; then
      error "Generation link not found: ${target_link}"
      exit 1
    fi
    nvd diff "$target_link" "$current_link"
    ;;

  generations)
    profile=$(_detect_profile)
    if [[ "$profile" == "nixos" ]]; then
      sudo nixos-rebuild list-generations
    else
      _darwin_rebuild --list-generations
    fi
    ;;

esac
