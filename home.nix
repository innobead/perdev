{ pkgs, lib, config, isDarwin ? false, ... }:

{
  # ── Identity ──────────────────────────────────────────────────────────────
  # builtins.getEnv requires --impure (handled in install.sh).
  # HOME resolves to /home/$USER on Linux and /Users/$USER on macOS.
  home.username      = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";
  home.stateVersion  = "24.11";

  # ── Non-NixOS Linux compatibility ─────────────────────────────────────────
  # Enables font/icon caches, XDG integration, etc. on Ubuntu.
  targets.genericLinux.enable = !isDarwin;

  # ── Home Manager self-management ──────────────────────────────────────────
  programs.home-manager.enable = true;

  # ── Nushell ───────────────────────────────────────────────────────────────
  # extraEnv / extraConfig are appended to HM-generated env.nu / config.nu,
  # preserving all integration snippets from programs.* modules below.
  programs.nushell = {
    enable      = true;
    extraEnv    = builtins.readFile ./configs/nushell/env.nu;
    extraConfig = builtins.readFile ./configs/nushell/config.nu;
  };

  # ── Bash (stays as OS login shell; switches to nushell for interactive use) ─
  programs.bash = {
    enable = true;
    initExtra = ''
      if [ -z "$IN_NIX_SHELL" ] && [ -z "$BASH_EXEC_NU_SKIP" ] && \
         [ "$SHLVL" -eq 1 ] && [ -t 0 ]; then
        nu_bin="$(command -v nu 2>/dev/null)"
        if [ -n "$nu_bin" ]; then
          SHELL="$nu_bin" exec "$nu_bin"
        fi
      fi
    '';
  };

  # ── Starship prompt ───────────────────────────────────────────────────────
  programs.starship = {
    enable                   = true;
    enableNushellIntegration = true;
    enableBashIntegration    = true;
    settings = {
      add_newline     = true;
      command_timeout = 500;
    };
  };

  # ── Carapace (universal completion engine) ────────────────────────────────
  programs.carapace = {
    enable                   = true;
    enableNushellIntegration = true;
  };

  # ── Zoxide (smart cd) ─────────────────────────────────────────────────────
  programs.zoxide = {
    enable                   = true;
    enableNushellIntegration = true;
    enableBashIntegration    = true;
  };

  # ── Atuin (shell history) ─────────────────────────────────────────────────
  programs.atuin = {
    enable                   = true;
    enableNushellIntegration = true;
    enableBashIntegration    = true;
    settings = {
      auto_sync    = false;
      update_check = false;
      style        = "compact";
      enter_accept = true;
    };
  };

  # ── Ghostty ───────────────────────────────────────────────────────────────
  # Linux: wrapped with nixGL so Ghostty can find host GPU drivers.
  # macOS: ghostty-bin (pre-built); pkgs.ghostty source build is broken on Darwin.
  programs.ghostty = {
    enable  = true;
    package = if isDarwin
      then pkgs.ghostty-bin
      else config.lib.nixGL.wrap pkgs.ghostty;
    settings = {
      command       = "${pkgs.nushell}/bin/nu";
      "font-family" = "JetBrainsMono Nerd Font";
      "font-size"   = 13;
      theme         = "catppuccin-mocha";
      # shell-integration handled manually in config.nu via GHOSTTY_RESOURCES_DIR
      "shell-integration" = "none";
    } // lib.optionalAttrs (!isDarwin) {
      # GTK/Wayland window decoration — Linux only
      "window-decoration" = "server";
    };
  };

  # ── Git ───────────────────────────────────────────────────────────────────
  programs.git = {
    enable       = true;
    delta.enable = true;
    extraConfig = {
      init.defaultBranch   = "main";
      pull.rebase          = true;
      push.autoSetupRemote = true;
    };
  };

  # ── Neovim ────────────────────────────────────────────────────────────────
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    vimAlias      = true;
  };

  # ── Direnv (per-directory envs; nix-direnv caches nix evaluations) ────────
  programs.direnv = {
    enable            = true;
    nix-direnv.enable = true;
  };

  # ── Tmux ──────────────────────────────────────────────────────────────────
  programs.tmux = {
    enable       = true;
    clock24      = true;
    historyLimit = 10000;
    keyMode      = "vi";
  };

  # ── GitHub CLI ────────────────────────────────────────────────────────────
  programs.gh.enable = true;

  # ── Lazygit ───────────────────────────────────────────────────────────────
  programs.lazygit.enable = true;

  # ── Ollama service ────────────────────────────────────────────────────────
  # Linux: systemd user service. macOS: launchd user agent.
  # Pull models after first start: ollama pull llama3.2
  systemd.user.services.ollama = lib.mkIf (!isDarwin) {
    Unit.Description = "Ollama local LLM server";
    Install.WantedBy = [ "default.target" ];
    Service = {
      ExecStart   = "${pkgs.ollama}/bin/ollama serve";
      Restart     = "on-failure";
      Environment = "OLLAMA_HOST=127.0.0.1:11434";
    };
  };

  launchd.agents.ollama = lib.mkIf isDarwin {
    enable = true;
    config = {
      Label            = "com.local.ollama";
      ProgramArguments = [ "${pkgs.ollama}/bin/ollama" "serve" ];
      RunAtLoad        = true;
      KeepAlive        = true;
      EnvironmentVariables = { OLLAMA_HOST = "127.0.0.1:11434"; };
      StandardOutPath  = "/tmp/ollama.log";
      StandardErrorPath = "/tmp/ollama.err";
    };
  };

  # ── Packages ──────────────────────────────────────────────────────────────
  home.packages = with pkgs;
    [
      # ── CLI utilities (both platforms) ────────────────────────────────
      ripgrep fd fzf bat eza delta jq yq-go
      just age sops mkcert
      httpie curlie grpcurl
      htop dust procs

      # ── Go ────────────────────────────────────────────────────────────
      go gopls golangci-lint delve

      # ── Rust (rustup only — do NOT add pkgs.cargo or pkgs.rustc alongside)
      rustup

      # ── Python ────────────────────────────────────────────────────────
      python3 uv

      # ── Node.js (fnm manages versions; no global nodejs package needed)
      fnm

      # ── Container / OCI: shared tools (both platforms) ────────────────
      dive crane cosign lazydocker

      # ── Kubernetes (both platforms) ───────────────────────────────────
      kubectl kubernetes-helm kind k9s kubectx kustomize stern kubeseal flux
      tilt  # fast iterative Kubernetes dev loop (Tiltfile hot-reload)

      # ── AI tools (both platforms) ─────────────────────────────────────
      llm     # universal LLM CLI — plugins: llm-claude-3, llm-gemini, llm-ollama
      ollama  # local LLM server — pull models: ollama pull llama3.2
      # claude-code  # uncomment once nixpkgs package name is verified
      # gemini-cli   # uncomment once nixpkgs package name is verified

      # ── Fonts ─────────────────────────────────────────────────────────
      nerd-fonts.jetbrains-mono
    ]

    # ── Linux-only container / OCI tools ──────────────────────────────────
    ++ lib.optionals (!isDarwin) [
      podman   # rootless container runtime
      buildah  # OCI image builder (daemonless)
      skopeo   # OCI image inspect / copy / sign
    ]

    # ── macOS container tools (Docker CE runs inside Colima VM) ───────────
    ++ lib.optionals isDarwin [
      colima          # Docker-compatible runtime via Apple VZ (replaces Docker Desktop)
      docker-client   # Docker CLI — connects to Colima's socket
      docker-buildx   # Multi-platform image builds
      docker-compose  # Compose CLI v2
      container       # Apple Container CLI (native Apple VF, aarch64-darwin only)
    ];

  # ── Session variables ─────────────────────────────────────────────────────
  home.sessionVariables = {
    EDITOR      = "nvim";
    VISUAL      = "nvim";
    PAGER       = "bat --plain";
    CARGO_HOME  = "${config.home.homeDirectory}/.cargo";
    RUSTUP_HOME = "${config.home.homeDirectory}/.rustup";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.cargo/bin"
    "${config.home.homeDirectory}/.local/bin"
  ];

  xdg.enable = true;
}
