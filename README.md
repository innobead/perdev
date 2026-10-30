# perdev

Reproducible development environment for x86_64 NixOS and Apple Silicon macOS,
built with Nix, Home Manager, and nix-darwin. `flake.lock` pins every input.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/innobead/perdev/main/perdev-update.sh | bash
```

This clones the repo to `~/.local/share/perdev`, installs Nix (and Homebrew on
macOS) if needed, and applies the configuration. Open a new shell afterwards.

- **macOS:** run `xcode-select --install` first if Git is missing. Leftovers of
  a previous Nix install (stale keychain password, old uninstall receipt) are
  cleaned up automatically.
- **NixOS:** requires UEFI with systemd-boot and
  `/etc/nixos/hardware-configuration.nix`.

## Update

| Command | Action |
|---|---|
| `perdev-update` | Pull the latest config and apply it |
| `perdev-update --no-brew` | Same, without upgrading Homebrew |
| `perdev-update --local-update` | Update `flake.lock` and apply it |
| `perdev-update --brew-upgrade` | macOS: upgrade Homebrew packages only |
| `perdev-update --reinstall` | Uninstall, then install from scratch |
| `perdev-update --self-update` | Update the `perdev-update` script |
| `perdev-update --generations` | List system generations |
| `perdev-update --diff [N]` | Compare generation N with the current one |
| `perdev-update --rollback [N]` | Roll back to generation N (default: previous) |

On macOS, updates also:

- upgrade Determinate Nix in place (`determinate-nixd upgrade`);
- run `brew update` and `brew upgrade` (casks that update themselves, such as
  Ghostty or Antigravity, are left to their own updaters);
- list Homebrew packages not declared in `darwin.nix`, and warn when Homebrew
  copies shadow the Nix-managed shell tools.

Rollbacks never touch Homebrew. Weekly garbage collection removes generations
older than 30 days.

## Tools

- **Shell:** Ghostty, Nushell, Starship, Carapace, Zoxide, Atuin, tmux, direnv
- **Languages:** Go, Rust (rustup), Python (uv), Bun
- **Containers:** Docker, Colima / Apple Container (macOS), Podman (NixOS),
  Dive, Crane, Cosign, Trivy, Lazydocker
- **Kubernetes:** kubectl, Helm, Kind, K9s, kubectx, Kustomize, Stern,
  Kubeseal, Tilt
- **Cloud:** AWS CLI, Google Cloud CLI, Jira CLI, `bzr`
- **AI:** Claude Code, Gemini CLI, Copilot CLI, Ollama, LLM, RTK, Antigravity,
  herdr, OpenSuperWhisper
- **Utilities:** Neovim, Lazygit, ripgrep, fd, fzf, bat, eza, delta, jq, yq,
  age, SOPS, mkcert, HTTPie, grpcurl, htop, dust, procs, VHS, Stats

Bash stays the login shell and enters Nushell for interactive sessions.

## Adding packages

| Platform | Where |
|---|---|
| macOS | Homebrew formulae and casks in `darwin.nix` |
| NixOS | `home.packages` in `home.nix`; system settings in `nixos.nix` |

Nushell, Starship, Carapace, Zoxide, and Atuin always come from Nix because
Home Manager generates their shell integrations; don't install them with
Homebrew. Keep Rust managed by rustup only.

## Development

| Command | Action |
|---|---|
| `just apply` | Apply local changes |
| `just local-update` | Update Nix inputs and Homebrew, then apply |
| `just test-mac` / `just test-nixos` | Non-destructive provisioning checks |
| `just uninstall` | Remove perdev from macOS |

CI runs both checks on every PR. A weekly workflow updates `flake.lock` and
auto-merges it once both platforms pass.

```text
flake.nix  home.nix  nixos.nix  darwin.nix   configuration
packages/  configs/                          custom packages, Nushell/Ghostty config
setup.sh  perdev-update.sh  uninstall.sh     lifecycle scripts
scripts/  tests/  .github/workflows/         helpers, checks, CI
```
