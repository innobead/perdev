{ lib, ... }:

# darwin.nix — macOS package management via nix-darwin + Homebrew.
#
# All CLI tools, dev toolchains, and GUI apps are installed declaratively
# through Homebrew here. Home Manager (home.nix) handles only shell/program
# configuration (configs, integrations) — it does NOT install packages on macOS.
#
# Apply with: sudo darwin-rebuild switch --flake .#mac --impure
# Or via: bash setup.sh

{
  # ── Required nix-darwin fields ────────────────────────────────────────────
  system.stateVersion = 6;
  # sudo resets $USER to root; $SUDO_USER holds the original invoking user.
  # Falls back to $USER when not using sudo (e.g. CI or first-time bootstrap).
  system.primaryUser = let
    sudoUser = builtins.getEnv "SUDO_USER";
    user     = builtins.getEnv "USER";
  in if sudoUser != "" then sudoUser else user;

  # Determinate Nix manages the Nix daemon — disable nix-darwin's conflicting
  # Nix management so darwin-rebuild switch succeeds.
  nix.enable = false;

  # ── Homebrew — all macOS packages ─────────────────────────────────────────
  # setup.sh installs Homebrew if not present. Packages are never removed by
  # uninstall.sh — manage them manually if you want to uninstall.
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate  = false;
      cleanup     = "none";   # never remove user-installed packages outside this config
      upgrade     = false;
    };

    taps = [
      "oven-sh/bun"            # bun JavaScript runtime (no formula in homebrew-core)
      "tilt-dev/homebrew-tap"  # tilt dev environment tool
    ];

    brews = [
      # ── CLI utilities ────────────────────────────────────────────────
      "ripgrep" "fd" "fzf" "bat" "eza" "git" "git-delta"
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
      "oven-sh/bun/bun"

      # ── Container / OCI ──────────────────────────────────────────────
      "dive" "crane" "cosign" "lazydocker"
      "lima" "colima"
      "docker" "docker-buildx" "docker-compose"

      # ── Kubernetes ───────────────────────────────────────────────────
      "kubectl" "helm" "kind" "k9s" "kubectx" "kustomize"
      "stern" "kubeseal"
      "fluxcd/tap/flux"
      "tilt-dev/homebrew-tap/tilt"

      # ── Shell / terminal ─────────────────────────────────────────────
      "nushell" "starship" "carapace" "zoxide" "atuin"
      "direnv" "tmux" "neovim" "lazygit" "gh"

      # ── AI tools ─────────────────────────────────────────────────────
      "ollama" "llm" "rtk"
      "gemini-cli"
    ];

    casks = [
      "ghostty"           # terminal emulator (pre-built binary)
      "claude-code"       # Anthropic agentic coding CLI
      "copilot-cli"       # GitHub Copilot CLI
      "antigravity-cli"   # mac-only — not available as formula
      "font-jetbrains-mono-nerd-font"
    ];

    masApps = {};
  };
}
