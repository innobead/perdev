{ lib, ... }:

# darwin.nix — macOS package management via nix-darwin + Homebrew.
#
# All CLI tools, dev toolchains, and GUI apps are installed declaratively
# through Homebrew here. Home Manager (home.nix) handles only shell/program
# configuration (configs, integrations) — it does NOT install packages on macOS.
#
# Apply with: darwin-rebuild switch --flake .#mac --impure
# Or via: bash setup.sh

{
  # ── Required nix-darwin fields ────────────────────────────────────────────
  system.stateVersion = 6;
  system.primaryUser  = builtins.getEnv "USER";

  # ── Homebrew — all macOS packages ─────────────────────────────────────────
  # setup.sh installs Homebrew if not present. Packages are never removed by
  # uninstall.sh — manage them manually if you want to uninstall.
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate  = false;
      cleanup     = "zap";   # removes unlisted formulae/casks on darwin-rebuild
      upgrade     = false;
    };

    brews = [
      # ── CLI utilities ────────────────────────────────────────────────
      "ripgrep" "fd" "fzf" "bat" "eza" "git-delta"
      "jq" "yq" "just" "age" "sops" "mkcert"
      "httpie" "curlie" "grpcurl"
      "htop" "dust" "procs"
      "vhs" "ffmpeg" "ttyd"

      # ── Go ────────────────────────────────────────────────────────────
      "go" "gopls" "golangci-lint" "delve"

      # ── Rust ─────────────────────────────────────────────────────────
      "rustup"

      # ── Python ───────────────────────────────────────────────────────
      "python3" "uv"

      # ── JavaScript ───────────────────────────────────────────────────
      "bun"

      # ── Container / OCI ──────────────────────────────────────────────
      "dive" "crane" "cosign" "lazydocker"
      "lima" "colima"
      "docker" "docker-buildx" "docker-compose"

      # ── Kubernetes ───────────────────────────────────────────────────
      "kubectl" "helm" "kind" "k9s" "kubectx" "kustomize"
      "stern" "kubeseal"
      "fluxcd/tap/flux"
      "tilt-dev/tap/tilt"

      # ── Shell / terminal ─────────────────────────────────────────────
      "nushell" "starship" "carapace" "zoxide" "atuin"
      "direnv" "tmux" "neovim" "lazygit" "gh"

      # ── AI tools ─────────────────────────────────────────────────────
      "ollama" "llm" "rtk"
      "antigravity"   # mac-only — not available in nixpkgs
      "gemini-cli"
    ];

    casks = [
      "ghostty"           # terminal emulator (pre-built binary)
      "claude-code"       # Anthropic agentic coding CLI
      "copilot-cli"       # GitHub Copilot CLI
      "font-jetbrains-mono-nerd-font"

      # ── GUI apps ─────────────────────────────────────────────────────
      "1password"
      "raycast"
      "arc"
      "slack"
      "zoom"
      "obs"
    ];

    masApps = {};
  };
}
