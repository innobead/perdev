#!/usr/bin/env bash
# nix-cleanup-mac.sh — Remove leftovers of a broken or partially removed Nix
# install on macOS so the Determinate installer can start fresh.
#
# Call only when Nix is not working (setup.sh) or after Nix was uninstalled
# (uninstall.sh). Exits 1 when manual action is required.

set -uo pipefail

[[ "$(uname -s)" == "Darwin" ]] || exit 0

KEYCHAIN=/Library/Keychains/System.keychain
KEY_ARGS=(-a "Nix Store" -s "Nix Store" -D "Encrypted volume password")

_volume_exists()   { diskutil info "Nix Store" >/dev/null 2>&1; }
_password_exists() { security find-generic-password "${KEY_ARGS[@]}" "$KEYCHAIN" >/dev/null 2>&1; }

# A previous install with an uninstall receipt: let the installer undo it.
if [[ -x /nix/nix-installer ]]; then
  echo "Removing the previous Nix install (/nix/nix-installer uninstall)..."
  /nix/nix-installer uninstall --no-confirm || exit 1
fi

# Never delete the password while the encrypted volume exists: macOS needs it
# to unlock the volume at boot.
if _volume_exists; then
  cat >&2 <<'EOF'
A "Nix Store" volume exists without a working Nix install. Remove it, then re-run:
  sudo launchctl bootout system/org.nixos.darwin-store
  sudo launchctl bootout system/org.nixos.nix-daemon
  sudo diskutil apfs deleteVolume "Nix Store"
EOF
  exit 1
fi

# The installer aborts when a password exists for a volume that is gone.
if _password_exists; then
  echo "Removing stale \"Nix Store\" keychain passwords..."
  for _ in $(seq 1 20); do
    sudo security delete-generic-password "${KEY_ARGS[@]}" "$KEYCHAIN" >/dev/null 2>&1 || break
  done
  if _password_exists; then
    echo "Could not remove the \"Nix Store\" keychain password; delete it in Keychain Access (System)." >&2
    exit 1
  fi
fi

exit 0
