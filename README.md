# perdev

Reproducible development workstation provisioning for **Linux** and **macOS**, built on [Nix](https://nixos.org/) + [Home Manager](https://github.com/nix-community/home-manager) + [nix-darwin](https://github.com/nix-darwin/nix-darwin).

**Package management by platform:**
- **macOS** — packages installed via [Homebrew](https://brew.sh/) (managed declaratively in `darwin.nix`); Home Manager handles shell/program configuration only.
- **Linux** — packages installed via Nix (Home Manager `home.packages`).

Declare tools once in `home.nix`, bootstrap any new machine with one command, and get an identical environment every time — pinned versions via `flake.lock`.

---

## Quick start

### One-line install

```bash
curl -fsSL https://raw.githubusercontent.com/innobead/perdev/main/perdev-update.sh | bash
```

> **Requires:** `git` and `curl` pre-installed. On macOS run `xcode-select --install` if git is missing.

This downloads and runs `perdev-update`, which:
1. Clones the repo to `~/.local/share/perdev`
2. Installs Nix (Determinate Systems installer) if not present
3. Applies the full Home Manager (+ nix-darwin on macOS) configuration

After it completes, open a **new shell** — all tools are ready.

### Or clone and run directly

```bash
git clone https://github.com/innobead/perdev.git ~/perdev
cd ~/perdev
bash setup.sh
```

---

## What's included

### Shell & terminal
| Tool | Purpose |
|---|---|
| [Ghostty](https://ghostty.org/) | Terminal emulator — launches Nushell directly |
| [Nushell](https://www.nushell.sh/) | Primary shell (Bash stays as login shell) |
| [Starship](https://starship.rs/) | Cross-shell prompt |
| [Carapace](https://carapace.sh/) | Universal tab completion engine |
| [Zoxide](https://github.com/ajeetdsouza/zoxide) | Smart `cd` with frecency ranking |
| [Atuin](https://atuin.sh/) | Shell history with SQLite backend |

### Development toolchains
| Language | Tools |
|---|---|
| Go | `go`, `gopls`, `golangci-lint`, `delve` |
| Rust | `rustup` (manages stable/nightly toolchains) |
| Python | `python3`, `uv` |
| JavaScript | `bun` (runtime + package manager) |

### Containers & OCI
| Tool | Ubuntu | macOS |
|---|---|---|
| Docker daemon | Docker CE via apt | [Colima](https://github.com/abiosoft/colima) (Apple VZ backend) |
| Docker CLI | via Docker CE | `docker-client`, `docker-buildx`, `docker-compose` |
| Native containers | `podman`, `buildah`, `skopeo` | [Apple Container](https://github.com/apple/container) (`container` CLI) |
| Image tools | `dive`, `crane`, `cosign`, `lazydocker` | same |

### Kubernetes
`kubectl` · `helm` · `kind` · `k9s` · `kubectx`/`kubens` · `kustomize` · `stern` · `kubeseal` · `flux` · `tilt`

### AI development tools
| Tool | macOS source | Linux source | Purpose |
|---|---|---|---|
| [Claude Code](https://claude.ai/code) | `brew` cask | Nix | Anthropic's agentic coding CLI |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `brew` | Nix | Google Gemini CLI |
| [Antigravity CLI](https://antigravity.google) | `brew` (mac-only) | — | Official Google Antigravity CLI |
| [GitHub Copilot CLI](https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli) | `brew` cask | `gh` extension | Copilot in terminal |
| [Ollama](https://ollama.com/) | `brew` | Nix | Local LLM server (Llama, Mistral, Gemma, …) |
| [LLM](https://llm.datasette.io/) | `brew` | Nix | Universal LLM CLI with plugin support |
| [RTK](https://github.com/rtk-ai/rtk) | `brew` | Nix | CLI output filter — strips noise before it hits the LLM (60–90% savings) |

### CLI utilities
`vhs` · `ripgrep` · `fd` · `fzf` · `bat` · `eza` · `delta` · `jq` · `yq` · `just` · `age` · `sops` · `mkcert` · `httpie` · `curlie` · `grpcurl` · `htop` · `dust` · `procs` · `neovim` · `lazygit` · `tmux` · `direnv` · `gh`

---

## Token cost optimization

Two levers cut Claude Code API costs significantly:

| Layer | Tool | Mechanism | Savings |
|---|---|---|---|
| CLI output | **RTK** | Strips progress bars, passing tests, verbose logs before they enter the context window | 60–90% on noisy commands |
| Session effort | **`/effort`** | Lower effort level reduces thinking-token budget for simple tasks | variable |

RTK is wired up automatically via a Claude Code hook (`rtk init -g`, run by `scripts/ai-tools-setup.sh`). All Bash tool calls are transparently rewritten through `rtk` to filter noise before it hits the LLM.

---

## Repository layout

```
perdev/
├── flake.nix              # Nix flake — defines ubuntu and mac profiles
├── flake.lock             # Pinned package versions
├── home.nix               # Home Manager config — shell/program configs (packages on Linux only)
├── darwin.nix             # nix-darwin config — Homebrew package list for macOS
├── setup.sh               # Full setup entrypoint (all steps)
├── uninstall.sh           # Remove everything installed by perdev
├── perdev-update.sh       # Installed to ~/.local/bin/perdev-update; bootstrap entry point
├── justfile               # Developer command aliases (just <recipe>)
├── configs/
│   ├── nushell/
│   │   ├── env.nu         # PATH, env vars
│   │   └── config.nu      # Settings, aliases, direnv hook
│   └── ghostty/
│       └── config         # Reference config docs
├── scripts/
│   ├── install.sh         # Minimal Nix + HM bootstrap (used by setup.sh)
│   ├── docker-setup.sh    # Ubuntu: Docker CE via apt
│   ├── docker-mac-setup.sh# macOS: start Colima, verify Apple Container
│   └── ai-tools-setup.sh  # Verify AI tools on PATH and wire RTK hook
└── tests/
    ├── test-ubuntu.sh     # Ubuntu container validation
    └── test-mac.sh        # macOS direct validation
```

---

## Managing your environment

### `perdev-update` — the main tool

After install, `perdev-update` is on your PATH. It manages the full lifecycle:

```bash
perdev-update                 # upgrade: pull latest config + reapply
perdev-update --reinstall     # wipe and reinstall from scratch
perdev-update --self-update   # replace this script with the latest from GitHub
perdev-update --local-update  # bump all Nix packages to latest versions
perdev-update --rollback      # roll back to the previous generation
perdev-update --rollback 42   # roll back to a specific generation number
perdev-update --diff          # show what changed in the last switch
perdev-update --diff 42       # diff generation 42 against current
perdev-update --generations   # list all Home Manager generations
```

### `just` — developer shortcuts

If you have the repository cloned locally, `just` provides shortcuts:

```bash
just install          # smart install/upgrade (or: just install force=true to reinstall)
just update           # pull latest config from git + reapply
just apply            # apply local changes without git pull or flake update (macOS: sudo darwin-rebuild)
just local-update     # nix flake update + reapply (bumps package pins)
just uninstall        # remove everything
just rollback         # roll back to previous generation
just rollback 42      # roll back to generation 42
just diff             # show changes since last switch
just diff 42          # diff generation 42 against current
just generations      # list all generations
just test-mac         # run macOS provisioning tests
just test-ubuntu      # run Ubuntu provisioning tests (Docker required)
```

### Adding or removing a package

**macOS** — edit `homebrew.brews` or `homebrew.casks` in `darwin.nix`, then run:

```bash
just apply   # sudo darwin-rebuild switch --flake .#mac --impure
```

**Linux** — edit `home.packages` in `home.nix`, then run:

```bash
perdev-update --local-update   # apply immediately from local repo
# or
just local-update
```

### Generations & rollbacks

Every `switch` creates a new Home Manager generation — a complete, atomic snapshot of your environment. Roll back instantly if something breaks:

```bash
perdev-update --generations    # list all generations
perdev-update --rollback       # revert to previous
perdev-update --rollback 42    # revert to a specific generation
```

To free up disk space from old generations:

```bash
nix-collect-garbage -d
```

---

## Platform details

### Ubuntu

- **Ghostty** uses `pkgs.ghostty` directly. On Mesa/Intel GPUs this works without extra setup. For NVIDIA, install [nixGL](https://github.com/nix-community/nixGL) separately and wrap the binary manually.
- **Docker** is installed via the official apt repository (`scripts/docker-setup.sh`) — `pkgs.docker` from Nix does not integrate with Ubuntu's systemd correctly.
- **Nushell** is set as the terminal shell via `programs.ghostty.settings.command`. Bash stays as the login shell for compatibility.
- **Ollama** runs as a `systemd` user service and starts automatically on login.

### macOS (Apple Silicon)

- **nix-darwin** manages Homebrew declaratively via `darwin.nix` and runs Home Manager as a sub-activation via `darwin-rebuild switch` (requires `sudo`).
- **Package split**: CLI tools and GUI apps are installed via Homebrew. Shell-integration tools (`nushell`, `starship`, `carapace`, `zoxide`, `atuin`) are Nix-managed via `programs.*` in `home.nix` — they must be Nix packages because Home Manager uses them at build time to generate nushell init scripts.
- **Homebrew cleanup** is set to `none` — `darwin-rebuild` only ensures listed packages are installed, never removes packages you've installed yourself.
- **Nushell config**: on macOS, nushell reads from `~/Library/Application Support/nushell/`. Home Manager generates configs to `~/.config/nushell/`. A `home.activation` step automatically symlinks the macOS path to the HM-managed location.
- **Ghostty** is installed as a Homebrew cask (`ghostty`).
- **Docker** runs inside a [Colima](https://github.com/abiosoft/colima) VM (Apple VZ backend). `docker` CLI commands work normally against Colima's socket.
- **Apple Container** (`container` CLI) is Apple's native OCI tool — installed via Nix (not available in Homebrew), requires Apple Silicon.
- **Ollama** runs as a `launchd` user agent and starts automatically on login.

---

## Testing

### macOS (runs directly — no macOS containers exist)

```bash
just test-mac
```

Non-destructive: uses `nix build --no-link` and `nix shell` — does not switch your active Home Manager generation. Validates the HM config, the nix-darwin config, and spot-checks 40+ binaries.

### Ubuntu (in Docker)

```bash
just test-ubuntu
```

Spins up a fresh Ubuntu container, installs Nix with `--init none` (no systemd needed), builds the full Home Manager activation package, then spot-checks 40+ binaries.

---

## Notes

- **Rust**: only `rustup` is installed via Nix. Do not add `pkgs.cargo` or `pkgs.rustc` alongside it — they conflict. Use `rustup toolchain install stable` to get the compiler.
- **JavaScript**: `bun` is the runtime and package manager. Global packages land in `~/.bun/bin`.
- **`stateVersion`**: `home.stateVersion` does not need to match the nixpkgs channel. Do not change it unless Home Manager's migration guide instructs you to.
- **Git identity not required**: `perdev-update` syncs the repo with `git reset --hard origin/main` — no merge commits are created, so no `user.email`/`user.name` git config is needed on fresh installs.
- **Direnv in nushell**: the direnv hook uses `which direnv` (PATH lookup) rather than a hardcoded Nix store path. This means it survives `nix-collect-garbage` and flake updates without breaking the shell.
- **`--self-update` writes to `~/.local/bin/perdev-update`**: Home Manager installs the script as a symlink into the read-only Nix store. `--self-update` always writes to the install path directly, replacing the symlink with a real file containing the latest version.
- **Pinned versions**: `flake.lock` pins every package to a specific version. `perdev-update --local-update` (or `just local-update`) updates the pins to latest.
