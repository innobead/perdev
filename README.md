# perdev

Reproducible personal development environment for x86_64 NixOS and Apple Silicon
macOS, built with Nix, Home Manager, and nix-darwin.

| Platform | Package installation | User configuration |
|---|---|---|
| NixOS | NixOS modules and Nix packages | NixOS + Home Manager |
| macOS | Homebrew packages declared in `darwin.nix`, plus selected Nix packages | nix-darwin + Home Manager |

`flake.lock` pins the Nix inputs so the same configuration can be reproduced on
another machine.

## Install

Requires `git`, `curl`, and either an existing NixOS installation or Apple
Silicon macOS. On NixOS, the profile imports
`/etc/nixos/hardware-configuration.nix` and targets UEFI with systemd-boot. On
macOS, run `xcode-select --install` first if Git is unavailable.

```bash
curl -fsSL https://raw.githubusercontent.com/innobead/perdev/main/perdev-update.sh | bash
```

This clones the repository to `~/.local/share/perdev`, installs Nix when
needed, and applies the appropriate platform configuration. Open a new shell
after installation.

To install from a working copy instead:

```bash
git clone https://github.com/innobead/perdev.git ~/perdev
cd ~/perdev
bash setup.sh
```

## Tool highlights

- **Shell:** Ghostty, Nushell, Starship, Carapace, Zoxide, Atuin, tmux, direnv
- **Languages:** Go, Rust via rustup, Python with uv, JavaScript with Bun
- **Containers:** Docker, Colima on macOS, Podman/Buildah/Skopeo on NixOS,
  Apple Container on macOS, Dive, Crane, Cosign, Trivy, Lazydocker
- **Kubernetes:** kubectl, Helm, Kind, K9s, kubectx, Kustomize, Stern,
  Kubeseal, Flux, Tilt
- **Cloud and issue tracking:** AWS CLI, Google Cloud CLI on macOS, Jira CLI,
  `bzr` for Bugzilla
- **AI:** Claude Code, Gemini CLI, GitHub Copilot CLI, Ollama, LLM, RTK,
  Antigravity
- **Utilities:** Neovim, Lazygit, ripgrep, fd, fzf, bat, eza, delta, jq, yq,
  age, SOPS, mkcert, HTTPie, grpcurl, htop, dust, procs, VHS, Stats on macOS

Bash remains the login shell for compatibility and automatically enters
Nushell for interactive sessions. Ghostty launches Nushell directly. Ollama
starts as a user service through systemd on NixOS and launchd on macOS.

## Manage the environment

`perdev-update` is installed to `~/.local/bin`:

| Command | Action |
|---|---|
| `perdev-update` | Pull the latest configuration and apply it |
| `perdev-update --reinstall` | Remove and reinstall the environment |
| `perdev-update --self-update` | Update the management script |
| `perdev-update --local-update` | Update `flake.lock` and apply it |
| `perdev-update --generations` | List system generations |
| `perdev-update --diff [N]` | Compare a generation with the current one |
| `perdev-update --rollback [N]` | Roll back to a previous generation |

When working in the repository, use `just`:

| Command | Action |
|---|---|
| `just install` | Install, or update an existing installation |
| `just apply` | Apply local configuration changes |
| `just update` | Pull the remote configuration and apply it |
| `just local-update` | Update Nix inputs and apply local configuration |
| `just uninstall` | Remove macOS-managed components; explain NixOS removal |
| `just test-mac` | Validate macOS provisioning |
| `just test-nixos` | Build the NixOS system without activating it |

Every switch creates a system generation. Use `just rollback` after a bad
update and let the configured weekly Nix garbage collection remove generations
older than 30 days.

## Package ownership

On macOS, add formulae or casks to `darwin.nix`. Home Manager still installs
Nushell, Starship, Carapace, Zoxide, and Atuin through Nix because it uses
those packages to generate shell integrations. Avoid installing duplicate
Homebrew copies because `/opt/homebrew/bin` takes PATH precedence.

On NixOS, add user packages to `home.packages` in `home.nix` and system
services or operating-system settings to `nixos.nix`. Apply changes with
`just apply`; use `just local-update` only when intentionally updating pinned
Nix inputs.

Notable exceptions:

- Docker is enabled declaratively through `virtualisation.docker` on NixOS.
- Apple Container is installed through Nix on macOS.
- The NixOS `bzr` package is pinned in `packages/bzr.nix`; macOS uses the
  upstream `randomparity/tap`.
- Homebrew cleanup is disabled, so applying the configuration does not remove
  packages installed outside this project.

## Repository layout

```text
flake.nix              Nix flake and platform profiles
flake.lock             Pinned Nix inputs
home.nix               Home Manager configuration and NixOS user packages
nixos.nix              NixOS system, boot, user, network, and Docker settings
darwin.nix             macOS system configuration and Homebrew packages
packages/              Custom Nix packages
configs/               Nushell and Ghostty configuration
setup.sh               Full installation entry point
perdev-update.sh       Install and update lifecycle command
uninstall.sh           Environment removal
scripts/               Minimal bootstrap and platform setup helpers
tests/                 NixOS and macOS provisioning checks
.github/workflows/     PR checks and automated flake updates
```

## Platform notes

### NixOS

- The profile targets x86_64 UEFI workstations using systemd-boot.
- The host-generated `/etc/nixos/hardware-configuration.nix` supplies detected
  filesystems and hardware modules.
- The profile is headless. NetworkManager, Docker, Nix garbage collection, and
  the user account are managed by `nixos.nix`.
- `PERDEV_USER` can override the configured username; otherwise evaluation uses
  `SUDO_USER`, then `USER`.

### macOS

- `darwin-rebuild` applies `darwin.nix` and the embedded Home Manager
  configuration together.
- Colima provides the Docker-compatible daemon using Apple's virtualization
  framework.
- The Nushell configuration generated under `~/.config` is linked to the
  macOS application-support location.
- Stable Homebrew and Nix tool paths are persisted for user `launchd` domains
  so applications opened from Finder or the Dock inherit them after a reboot.
- Apple Container and its CI validation require macOS 26.

## Development

Provisioning tests are non-destructive:

```bash
just test-nixos
just test-mac
```

Pull requests run both checks in GitHub Actions. A weekly workflow updates
`flake.lock`, opens a PR, runs the same checks, and merges only the tested
commit after both platforms pass.

Keep Rust managed exclusively by rustup; adding Nix `cargo` or `rustc`
packages alongside it creates toolchain conflicts. Change
`home.stateVersion` only when required by the Home Manager migration guide.
