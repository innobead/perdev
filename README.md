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
| Tool | Source | Purpose |
|---|---|---|
| [Claude Code](https://claude.ai/code) | npm | Anthropic's agentic coding CLI |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | npm | Google Gemini CLI |
| [GitHub Copilot](https://github.com/github/gh-copilot) | `gh` extension | Copilot in terminal |
| [Ollama](https://ollama.com/) | Nix | Local LLM server (Llama, Mistral, Gemma, …) |
| [LLM](https://llm.datasette.io/) | Nix | Universal LLM CLI with plugin support |
| [RTK](https://github.com/rtk-ai/rtk) | `curl` / `brew` | CLI output filter — strips noise before it hits the LLM (60–90% savings) |

### CLI utilities
`vhs` · `ripgrep` · `fd` · `fzf` · `bat` · `eza` · `delta` · `jq` · `yq` · `just` · `age` · `sops` · `mkcert` · `httpie` · `curlie` · `grpcurl` · `htop` · `dust` · `procs` · `neovim` · `lazygit` · `tmux` · `direnv` · `gh`

---

## Token cost optimization

Two levers cut Claude Code API costs significantly:

| Layer | Tool | Mechanism | Savings |
|---|---|---|---|
| CLI output | **RTK** | Strips progress bars, passing tests, verbose logs before they enter the context window | 60–90% on noisy commands |
| Session effort | **`/effort`** | Lower effort level reduces thinking-token budget for simple tasks | variable |

RTK is wired up automatically via a Claude Code hook (`rtk init -g`, run by `just ai`). All Bash tool calls are transparently rewritten through `rtk` to filter noise before it hits the LLM.

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
│   │   ├── env.nu         # PATH, env vars, BUN_INSTALL
│   │   └── config.nu      # Settings, aliases, direnv/Ghostty hooks
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

- **Ghostty** uses `pkgs.ghostty` directly. On Mesa/Intel GPUs this works without extra setup. For NVIDIA, install [nixGL](https://github.com/nix-community/nixGL) separately and wrap the binary manually.
- **Docker** is installed via the official apt repository (`scripts/docker-setup.sh`) — `pkgs.docker` from Nix does not integrate with Ubuntu's systemd correctly.
- **Nushell** is set as the terminal shell via `programs.ghostty.settings.command`. Bash stays as the login shell and runs `exec nu` for interactive sessions, avoiding desktop login issues.
- **Ollama** runs as a `systemd` user service and starts automatically on login.

### macOS (Apple Silicon)

- **Ghostty** uses `pkgs.ghostty-bin` (pre-built) — the source build is broken on Darwin.
- **Docker** runs inside a [Colima](https://github.com/abiosoft/colima) VM (Apple VZ backend). `docker` CLI commands work normally against Colima's socket.
- **Apple Container** (`container` CLI) is Apple's native OCI tool using the Apple Virtualization framework — separate from Docker, requires Apple Silicon.
- **Ollama** runs as a `launchd` user agent and starts automatically on login.

---

## Managing packages

### Common operations

If you have the repository cloned locally, use these `just` commands:

```bash
just switch          # re-apply home.nix after editing
just update          # update all flake inputs to latest (updates flake.lock)
just diff            # show package version changes since the last switch
just rollback        # list generations and pick one to roll back to
just verify          # quick sanity-check of installed tools
just setup           # re-run the full idempotent setup
just uninstall       # remove everything installed by setup.sh
```

### Adding or removing a package

Edit `home.packages` in `home.nix`, then run:

```bash
just switch
```

### Updating without a local clone

If you've installed the environment but don't have the `perdev` folder locally, you can update directly from GitHub:

**macOS:**
```bash
nix run nixpkgs#home-manager -- switch --flake github:innobead/perdev#mac --impure
```

**Ubuntu:**
```bash
nix run nixpkgs#home-manager -- switch --flake github:innobead/perdev#ubuntu --impure
```

### Forcing the absolute latest versions

To bypass the `flake.lock` pinned in the repository and fetch the latest versions available in the `nixpkgs` registry, add the `--recreate-lock-file` flag to the `nix run` command:

```bash
nix run nixpkgs#home-manager -- switch --flake github:innobead/perdev#mac --impure --recreate-lock-file
```

---

## Nix behavior & rollbacks

### The "Source of Truth"
The `flake.lock` file in this repository acts as the single source of truth. It pins every package to a specific, tested version. 

**Atomic Syncing:** If you force an update to newer versions (using `--recreate-lock-file`) and later run a standard update against this repo, Nix will safely and instantly "downgrade" your environment back to the pinned versions. It does this by simply repointing symbolic links in your `$PATH` to the older versions already stored in the `/nix/store`.

### Generations & Rollbacks
Every time you `switch` your configuration, Home Manager creates a new **Generation**. This allows you to instantly revert to a previous state if an update breaks something.

- **List generations:**
  ```bash
  home-manager generations
  ```
- **Roll back to a specific generation:**
  ```bash
  home-manager switch --generation <number>
  ```
- **Cleanup:** To remove old generations and free up disk space:
  ```bash
  nix-collect-garbage -d
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
- **JavaScript**: `bun` is installed via Nix. It serves as both the runtime and the package manager. Global packages (Claude Code, Gemini CLI) are installed with `bun install -g <pkg>` and land in `~/.bun/bin`.
- **`claude-code` / `gemini-cli`**: commented out in `home.nix` pending nixpkgs package name verification. `scripts/ai-tools-setup.sh` installs them via npm in the meantime.
- **`stateVersion`**: `home.stateVersion = "24.11"` does not need to match the nixpkgs channel. Do not change it unless Home Manager's migration guide instructs you to.
