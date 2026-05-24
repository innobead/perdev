# Justfile — perdev command runner
# Requires: just (included in home.nix). Run: just <recipe>

# List available recipes
default:
    @just --list

# ── Install / Update ──────────────────────────────────────────────────────────

# Smart install: full install if not yet installed; upgrade if already installed.
# Pass force=true to wipe and reinstall: just install force=true
install force="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{force}}" = "true" ]; then
        echo "Force reinstall: removing existing installation..."
        bash uninstall.sh --force
        bash setup.sh
    elif home-manager generations 2>/dev/null | grep -q .; then
        echo "Already installed — upgrading..."
        just update
    else
        bash setup.sh
    fi

# Pull latest perdev config from the remote repo and reapply
update:
    #!/usr/bin/env bash
    set -euo pipefail
    REPO_DIR="${HOME}/.local/share/perdev"
    if [ ! -d "$REPO_DIR/.git" ]; then
        echo "perdev repo not found at $REPO_DIR — run: just install"
        exit 1
    fi
    cd "$REPO_DIR"
    git fetch origin main
    if ! git diff-index --quiet HEAD --; then
        git stash
    fi
    git merge origin/main
    if [ "$(uname -s)" = "Darwin" ]; then
        nix run "github:nix-darwin/nix-darwin#darwin-rebuild" -- switch --flake ".#mac" --impure -v \
          || nix run nixpkgs#home-manager -- switch --flake ".#mac" --impure -v
    else
        nix run nixpkgs#home-manager -- switch --flake ".#ubuntu" --impure -v
    fi

# Update flake.lock to latest package versions and reapply (local dev use)
local-update:
    #!/usr/bin/env bash
    set -euo pipefail
    nix flake update
    if [ "$(uname -s)" = "Darwin" ]; then
        nix run "github:nix-darwin/nix-darwin#darwin-rebuild" -- switch --flake ".#mac" --impure -v \
          || nix run nixpkgs#home-manager -- switch --flake ".#mac" --impure -v
    else
        nix run nixpkgs#home-manager -- switch --flake ".#ubuntu" --impure -v
    fi

# Remove all components installed by perdev (prompts for confirmation)
uninstall:
    bash uninstall.sh

# ── Generations ───────────────────────────────────────────────────────────────

# List all Home Manager generations
generations:
    home-manager generations

# Roll back to generation N (default: previous generation)
rollback gen="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "{{gen}}" ]; then
        profile_dir="$HOME/.local/state/nix/profiles"
        [ -d "$profile_dir" ] || profile_dir="/nix/var/nix/profiles/per-user/$USER"
        home-manager generations | awk -v g="{{gen}}" '$0 ~ g {print $NF}' | head -1 | xargs -I{} {}/activate
    else
        home-manager switch --rollback
    fi

# Show package version changes between generation N and current (default: previous)
diff gen="":
    #!/usr/bin/env bash
    set -euo pipefail
    profile_dir="$HOME/.local/state/nix/profiles"
    [ -d "$profile_dir" ] || profile_dir="/nix/var/nix/profiles/per-user/$USER"
    current_link="$profile_dir/home-manager"
    if [ -n "{{gen}}" ]; then
        target_link="$profile_dir/home-manager-{{gen}}-link"
    else
        current_num=$(home-manager generations | head -1 | awk '{print $NF}' | grep -o '[0-9]*' | tail -1)
        prev=$((current_num - 1))
        if [ "$prev" -lt 1 ]; then
            echo "No previous generation found."
            exit 0
        fi
        target_link="$profile_dir/home-manager-${prev}-link"
    fi
    nvd diff "$target_link" "$current_link"

# ── Tests (dev) ───────────────────────────────────────────────────────────────

# Run provisioning verification on macOS (non-destructive)
test-mac:
    bash tests/test-mac.sh

# Run provisioning verification inside an Ubuntu Docker container
test-ubuntu:
    bash tests/test-ubuntu.sh

