# perdev

Reproducible development workstation provisioning for **Ubuntu** and **macOS** (Apple Silicon), built on [Nix](https://nixos.org/) + [Home Manager](https://github.com/nix-community/home-manager).

Declare tools once in `home.nix`, bootstrap any new machine with one command, and get an identical environment every time — pinned versions via `flake.lock`.

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
| Node.js | `fnm` (manages versions via `.node-version`/`.nvmrc`) |

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
| Tool | Source | Purpose |
|---|---|---|
| [Claude Code](https://claude.ai/code) | npm | Anthropic's agentic coding CLI |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | npm | Google Gemini CLI |
| [GitHub Copilot](https://github.com/github/gh-copilot) | `gh` extension | Copilot in terminal |
| [Ollama](https://ollama.com/) | Nix | Local LLM server (Llama, Mistral, Gemma, …) |
| [LLM](https://llm.datasette.io/) | Nix | Universal LLM CLI with plugin support |

### CLI utilities
`ripgrep` · `fd` · `fzf` · `bat` · `eza` · `delta` · `jq` · `yq` · `just` · `age` · `sops` · `mkcert` · `httpie` · `curlie` · `grpcurl` · `htop` · `dust` · `procs` · `neovim` · `lazygit` · `tmux` · `direnv` · `gh`

---

## Quick start

```bash
git clone https://github.com/innobead/perdev.git ~/perdev
cd ~/perdev
bash setup.sh
```

> **Requires:** `git` pre-installed. On Ubuntu it's usually present; on macOS run `xcode-select --install` if missing.

`setup.sh` is the single entrypoint — it runs all six steps in sequence (Nix → Home Manager → Rust → Docker → AI tools → Ollama), is idempotent (safe to re-run), and prints a pass/skip/fail summary at the end.

After `setup.sh` completes, open a **new shell** and pull a local LLM model:

```bash
ollama pull llama3.2        # ~2 GB, fast
ollama pull deepseek-coder-v2
```

Or use `just` (installed by Nix) to run individual steps:

```bash
just setup       # re-run the full setup
just docker      # Ubuntu: Docker CE only
just docker-mac  # macOS: Colima only
just ai          # AI tools only
```

---

## Repository layout

```
perdev/
├── flake.nix              # Nix flake — defines ubuntu and mac profiles
├── home.nix               # Home Manager config — all packages and programs
├── Justfile               # Short command aliases
├── configs/
│   ├── nushell/
│   │   ├── env.nu         # PATH, env vars, fnm init
│   │   └── config.nu      # Settings, aliases, direnv/Ghostty/fnm hooks
│   └── ghostty/
│       └── config         # Reference docs (canonical config is in home.nix)
├── scripts/
│   ├── install.sh         # Bootstrap — installs Nix, applies Home Manager
│   ├── docker-setup.sh    # Ubuntu: Docker CE via apt
│   ├── docker-mac-setup.sh# macOS: start Colima, verify Apple Container
│   └── ai-tools-setup.sh  # npm + gh extension AI tools
└── tests/
    ├── test-ubuntu.sh     # Spins up Ubuntu container, validates full config
    └── test-mac.sh        # Runs directly on macOS, validates mac config
```

---

## Platform details

### Ubuntu

- **Ghostty** is wrapped with [nixGL](https://github.com/nix-community/nixGL) so it can find the host's GPU drivers. Change `nixGL.defaultWrapper = "mesa"` to `"nvidia"` in `home.nix` for NVIDIA GPUs.
- **Docker** is installed via the official apt repository (`scripts/docker-setup.sh`) — `pkgs.docker` from Nix does not integrate with Ubuntu's systemd correctly.
- **Nushell** is set as the terminal shell via `programs.ghostty.settings.command`. Bash stays as the login shell and runs `exec nu` for interactive sessions, avoiding desktop login issues.
- **Ollama** runs as a `systemd` user service and starts automatically on login.

### macOS (Apple Silicon)

- **Ghostty** uses `pkgs.ghostty-bin` (pre-built) — the source build is broken on Darwin.
- **Docker** runs inside a [Colima](https://github.com/abiosoft/colima) VM (Apple VZ backend). `docker` CLI commands work normally against Colima's socket.
- **Apple Container** (`container` CLI) is Apple's native OCI tool using the Apple Virtualization framework — separate from Docker, requires Apple Silicon.
- **Ollama** runs as a `launchd` user agent and starts automatically on login.

---

## Common operations

```bash
just switch          # re-apply home.nix after editing (auto-detects platform)
just update          # update all flake inputs to latest
just rollback        # list generations; roll back if something broke
just verify          # quick sanity-check of installed tools
just ollama-models   # pull llama3.2 and deepseek-coder-v2
```

### Adding or removing a package

Edit `home.nix`, then run:

```bash
just switch
```

### Pinning versions

After the first `install.sh` run, commit `flake.lock` to pin exact package versions across machines:

```bash
git add flake.lock
git commit -m "lock flake inputs"
```

Update all inputs to latest:

```bash
just update && just switch
```

---

## Testing

### Ubuntu (in Docker)

```bash
just test-ubuntu                    # ubuntu:24.04
just test-ubuntu-version 22.04      # specific version
CONTAINER_CMD=podman just test-ubuntu
```

Spins up a fresh Ubuntu container, installs Nix with `--init none` (no systemd needed), builds the full Home Manager activation package to validate every package resolves, then spot-checks 40 binaries.

### macOS (runs directly — no macOS containers exist)

```bash
just test-mac
```

Same two-phase logic as the Ubuntu test, but runs directly on your Mac. Non-destructive: uses `--no-link` and `nix shell` only — does not switch your active Home Manager generation.

---

## Notes

- **Rust**: only `rustup` is installed via Nix. Do not add `pkgs.cargo` or `pkgs.rustc` alongside it — they conflict. Use `rustup toolchain install stable` to get the compiler.
- **Node.js**: only `fnm` is installed. Run `fnm install --lts` to get a Node.js version. `fnm` auto-switches on directory change based on `.node-version`/`.nvmrc`.
- **`claude-code` / `gemini-cli`**: commented out in `home.nix` pending nixpkgs package name verification. `scripts/ai-tools-setup.sh` installs them via npm in the meantime.
- **`stateVersion`**: `home.stateVersion = "24.11"` does not need to match the nixpkgs channel. Do not change it unless Home Manager's migration guide instructs you to.
