# perdev

Reproducible personal development environment for Ubuntu and Apple Silicon
macOS, built with Nix, Home Manager, and nix-darwin.

| Platform | Package installation | User configuration |
|---|---|---|
| Ubuntu | Nix packages declared in `home.nix` | Home Manager |
| macOS | Homebrew packages declared in `darwin.nix`, plus selected Nix packages | nix-darwin + Home Manager |

`flake.lock` pins the Nix inputs so the same configuration can be reproduced on
another machine.

## Install

Requires `git` and `curl`. On macOS, run `xcode-select --install` first if Git
is unavailable.

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
- **Containers:** Docker, Colima on macOS, Podman/Buildah/Skopeo on Linux,
  Apple Container on macOS, Dive, Crane, Cosign, Trivy, Lazydocker
- **Kubernetes:** kubectl, Helm, Kind, K9s, kubectx, Kustomize, Stern,
  Kubeseal, Flux, Tilt
- **Cloud and issue tracking:** AWS CLI, Google Cloud CLI on macOS, Jira CLI,
  `bzr` for Bugzilla
- **AI:** Claude Code, Gemini CLI, GitHub Copilot CLI, Ollama, LLM, RTK,
  Antigravity
- **Utilities:** Neovim, Lazygit, ripgrep, fd, fzf, bat, eza, delta, jq, yq,
  age, SOPS, mkcert, HTTPie, grpcurl, htop, dust, procs, VHS, Stats on macOS

Ghostty launches Nushell directly while Bash remains the login shell for
compatibility. Ollama starts as a user service through systemd on Linux and
launchd on macOS.

## Manage the environment

`perdev-update` is installed to `~/.local/bin`:

| Command | Action |
|---|---|
| `perdev-update` | Pull the latest configuration and apply it |
| `perdev-update --reinstall` | Remove and reinstall the environment |
| `perdev-update --self-update` | Update the management script |
| `perdev-update --local-update` | Update `flake.lock` and apply it |
| `perdev-update --generations` | List Home Manager generations |
| `perdev-update --diff [N]` | Compare a generation with the current one |
| `perdev-update --rollback [N]` | Roll back to a previous generation |

When working in the repository, use `just`:

| Command | Action |
|---|---|
| `just install` | Install, or update an existing installation |
| `just apply` | Apply local configuration changes |
| `just update` | Pull the remote configuration and apply it |
| `just local-update` | Update Nix inputs and apply local configuration |
| `just uninstall` | Remove the managed environment |
| `just test-mac` | Validate macOS provisioning |
| `just test-ubuntu` | Validate Ubuntu provisioning in a container |

Every switch creates a Home Manager generation. Use `just rollback` after a
bad update and `nix-collect-garbage -d` when old generations consume too much
disk space.

## Package ownership

On macOS, add formulae or casks to `darwin.nix`. Home Manager still installs
Nushell, Starship, Carapace, Zoxide, and Atuin through Nix because it uses
those packages to generate shell integrations. Avoid installing duplicate
Homebrew copies because `/opt/homebrew/bin` takes PATH precedence.

On Linux, add packages to `home.packages` in `home.nix`. Apply package-list
changes with `just apply`; use `just local-update` only when intentionally
updating pinned Nix inputs.

Notable exceptions:

- Docker CE is installed from Docker's apt repository on Ubuntu.
- Apple Container is installed through Nix on macOS.
- The Linux `bzr` package is pinned in `packages/bzr.nix`; macOS uses the
  upstream `randomparity/tap`.
- Homebrew cleanup is disabled, so applying the configuration does not remove
  packages installed outside this project.

## Repository layout

```text
flake.nix              Nix flake and platform profiles
flake.lock             Pinned Nix inputs
home.nix               Home Manager configuration and Linux packages
darwin.nix             macOS system configuration and Homebrew packages
packages/              Custom Nix packages
configs/               Nushell and Ghostty configuration
setup.sh               Full installation entry point
perdev-update.sh       Install and update lifecycle command
uninstall.sh           Environment removal
scripts/               Minimal bootstrap and platform setup helpers
tests/                 Ubuntu and macOS provisioning checks
.github/workflows/     PR checks and automated flake updates
```

## Platform notes

### Ubuntu

- Ghostty works directly on Mesa/Intel GPUs. NVIDIA systems may require a
  separate nixGL wrapper.
- Docker is installed outside Nix so it integrates with Ubuntu systemd.
- The provisioning test runs in a fresh Ubuntu container and builds the full
  Home Manager activation package.

### macOS

- `darwin-rebuild` applies `darwin.nix` and the embedded Home Manager
  configuration together.
- Colima provides the Docker-compatible daemon using Apple's virtualization
  framework.
- The Nushell configuration generated under `~/.config` is linked to the
  macOS application-support location.
- Apple Container and its CI validation require macOS 26.

## Development

Provisioning tests are non-destructive:

```bash
just test-ubuntu
just test-mac
```

Pull requests run both checks in GitHub Actions. A weekly workflow updates
`flake.lock`, opens a PR, runs the same checks, and merges only the tested
commit after both platforms pass.

Keep Rust managed exclusively by rustup; adding Nix `cargo` or `rustc`
packages alongside it creates toolchain conflicts. Change
`home.stateVersion` only when required by the Home Manager migration guide.
