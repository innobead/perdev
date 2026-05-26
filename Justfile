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
    bash perdev-update.sh

# Update flake.lock to latest package versions without pulling from remote (local dev use)
nix-flake-update:
    nix flake update

# Apply current local config without pulling from remote or updating flake.lock (local dev use)
apply:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(uname -s)" = "Darwin" ]; then
        DR="/run/current-system/sw/bin/darwin-rebuild"
        [ -x "$DR" ] || DR="nix run github:nix-darwin/nix-darwin#darwin-rebuild --"
        sudo $DR switch --flake ".#mac" --impure -v
    else
        nix run nixpkgs#home-manager -- switch --flake ".#ubuntu" --impure -v
    fi

# Update flake.lock to latest package versions and reapply from current directory (local dev use)
local-update:
    #!/usr/bin/env bash
    set -euo pipefail
    just nix-flake-update
    if [ "$(uname -s)" = "Darwin" ]; then
        DR="/run/current-system/sw/bin/darwin-rebuild"
        [ -x "$DR" ] || DR="nix run github:nix-darwin/nix-darwin#darwin-rebuild --"
        sudo $DR switch --flake ".#mac" --impure -v
    else
        nix run nixpkgs#home-manager -- switch --flake ".#ubuntu" --impure -v
    fi

# Remove all components installed by perdev (prompts for confirmation)
uninstall:
    bash uninstall.sh

# ── Generations ───────────────────────────────────────────────────────────────

# List all Home Manager generations
generations:
    bash perdev-update.sh --generations

# Roll back to generation N (default: previous generation)
rollback gen="":
    bash perdev-update.sh --rollback {{gen}}

# Show package version changes between generation N and current (default: previous)
diff gen="":
    bash perdev-update.sh --diff {{gen}}

# ── Tests (dev) ───────────────────────────────────────────────────────────────

# Run provisioning verification on macOS (non-destructive)
test-mac:
    bash tests/test-mac.sh

# Run provisioning verification inside an Ubuntu Docker container
test-ubuntu:
    bash tests/test-ubuntu.sh

