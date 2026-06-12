{ pkgs, lib, config, isDarwin ? false, nixgl ? null, ... }:

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
  # Nix package needed to generate nushell init script at build time.
  # Brew's version takes PATH precedence at runtime on macOS.
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
  # Nix package needed to generate nushell init script at build time.
  programs.carapace = {
    enable                   = true;
    enableNushellIntegration = true;
  };

  # ── Zoxide (smart cd) ─────────────────────────────────────────────────────
  # Nix package needed to generate nushell init script at build time.
  programs.zoxide = {
    enable                   = true;
    enableNushellIntegration = true;
    enableBashIntegration    = true;
  };

  # ── Atuin (shell history) ─────────────────────────────────────────────────
  # Nix package needed to generate nushell init script at build time.
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
  # macOS: installed via Homebrew cask — package = null skips Nix install.
  # Linux: pkgs.ghostty works on Mesa/Intel. For NVIDIA, wrap manually with nixGL.
  programs.ghostty = {
    enable  = true;
    package = if isDarwin then null else pkgs.ghostty;
    settings = {
      # nushell is Nix-managed on both platforms via programs.nushell
      command       = "${pkgs.nushell}/bin/nu";
      "font-family" = "JetBrainsMono Nerd Font";
      "font-size"   = 13;
      theme         = "Github Dark";
    } // lib.optionalAttrs (!isDarwin) {
      "window-decoration" = "server";
    };
  };

  # ── Git ───────────────────────────────────────────────────────────────────
  # macOS: package = null — git and delta are brew-managed.
  # HM still generates ~/.config/git/config and wires delta as the pager.
  programs.delta = {
    enable               = true;
    enableGitIntegration = true;
  };

  programs.git = {
    enable   = true;
    package  = if isDarwin then null else pkgs.git;
    settings = {
      init.defaultBranch   = "main";
      pull.rebase          = true;
      push.autoSetupRemote = true;
    };
  };

  # ── Neovim ────────────────────────────────────────────────────────────────
  # programs.neovim does not support package = null; Nix installs it as a side
  # effect of config generation. Brew version takes PATH precedence on macOS.
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    vimAlias      = true;
    withRuby      = false;
    withPython3   = false;
  };

  # ── Direnv (per-directory envs; nix-direnv caches nix evaluations) ────────
  # programs.direnv does not support package = null; Nix installs it as a side
  # effect of config generation. Brew version takes PATH precedence on macOS.
  programs.direnv = {
    enable                   = true;
    enableNushellIntegration = false;  # custom hook in config.nu uses PATH-based which direnv
    nix-direnv.enable        = true;
  };

  # ── Tmux ──────────────────────────────────────────────────────────────────
  programs.tmux = {
    enable       = true;
    package      = if isDarwin then null else pkgs.tmux;
    clock24      = true;
    historyLimit = 10000;
    keyMode      = "vi";
  };

  # ── GitHub CLI ────────────────────────────────────────────────────────────
  # programs.gh does not support package = null; Nix installs it as a side
  # effect of config generation. Brew version takes PATH precedence on macOS.
  programs.gh = {
    enable = true;
  };

  # ── Lazygit ───────────────────────────────────────────────────────────────
  programs.lazygit = {
    enable  = true;
    package = if isDarwin then null else pkgs.lazygit;
  };

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
      ProgramArguments = [ "/opt/homebrew/bin/ollama" "serve" ];
      RunAtLoad        = true;
      KeepAlive        = true;
      EnvironmentVariables = { OLLAMA_HOST = "127.0.0.1:11434"; };
      StandardOutPath  = "/tmp/ollama.log";
      StandardErrorPath = "/tmp/ollama.err";
    };
  };

  # ── Packages ──────────────────────────────────────────────────────────────
  # On macOS all tools are installed by Homebrew (darwin.nix). Nix only
  # installs packages on Linux here, plus the Apple Container CLI (not in brew).
  home.packages = with pkgs;
    # Linux — managed by Nix; on macOS Homebrew installs these instead
    lib.optionals (!isDarwin) [
      # ── CLI utilities ─────────────────────────────────────────────
      ripgrep fd fzf bat eza delta jq yq-go rsync
      just age sops mkcert
      httpie curlie grpcurl
      htop dust procs
      vhs ffmpeg ttyd nvd

      # ── Go ────────────────────────────────────────────────────────
      go gopls golangci-lint delve

      # ── Rust (rustup only — do NOT add pkgs.cargo or pkgs.rustc alongside)
      rustup

      # ── Python ────────────────────────────────────────────────────
      python3 uv

      # ── JavaScript runtime ────────────────────────────────────────
      bun

      # ── Container / OCI: shared tools ────────────────────────────
      dive crane cosign lazydocker
      lima colima docker-client docker-buildx docker-compose

      # ── Kubernetes ────────────────────────────────────────────────
      kubectl kubernetes-helm kind k9s kubectx kustomize stern kubeseal flux
      tilt  # fast iterative Kubernetes dev loop (Tiltfile hot-reload)

      # ── AI tools ─────────────────────────────────────────────────
      (llm.withPlugins {
        llm-anthropic = true;
        llm-gemini    = true;
        llm-ollama    = true;
      })
      ollama       # local LLM server — pull models after first start: ollama pull llama3.2
      rtk          # CLI output filter — reduces LLM token usage 60-90%
      claude-code  # Anthropic agentic coding CLI
      gemini-cli   # Google Gemini CLI
      antigravity  # Google Antigravity CLI

      # ── Fonts ─────────────────────────────────────────────────────
      nerd-fonts.jetbrains-mono
    ]

    # ── Linux-only container / OCI tools ──────────────────────────────────
    ++ lib.optionals (!isDarwin) [
      podman   # rootless container runtime
      buildah  # OCI image builder (daemonless)
      skopeo   # OCI image inspect / copy / sign
    ]

    # ── macOS-only container tools ────────────────────────────────────────
    ++ lib.optionals isDarwin [
      container       # Apple Container CLI (native Apple VF, aarch64-darwin only — not in brew)
    ];

  # ── Session variables ─────────────────────────────────────────────────────
  home.sessionVariables = {
    EDITOR        = "nvim";
    VISUAL        = "nvim";
    PAGER         = "bat --plain";
    CARGO_HOME    = "${config.home.homeDirectory}/.cargo";
    RUSTUP_HOME   = "${config.home.homeDirectory}/.rustup";
    BUN_INSTALL   = "${config.home.homeDirectory}/.bun";
    # Include Nix profile terminfo so xterm-ghostty is found over SSH.
    TERMINFO_DIRS = "${config.home.homeDirectory}/.nix-profile/share/terminfo:/usr/share/terminfo";
  };

  home.sessionPath =
    # macOS: brew-managed tools take PATH precedence over Nix equivalents.
    lib.optionals isDarwin [
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
    ] ++ [
      # Applied only for POSIX login shells (bash/zsh via ~/.profile).
      # nushell PATH is set explicitly in configs/nushell/env.nu instead.
      "/nix/var/nix/profiles/default/bin"
      "${config.home.homeDirectory}/.nix-profile/bin"
      "${config.home.homeDirectory}/.cargo/bin"
      "${config.home.homeDirectory}/.local/bin"
      "${config.home.homeDirectory}/.bun/bin"
      "${config.home.homeDirectory}/go/bin"
    ];

  home.file.".local/bin/perdev-update" = {
    source = ./perdev-update.sh;
    executable = true;
  };

  # ── macOS: symlink nushell config dir to XDG location ───────────────────────
  # nushell on macOS defaults to ~/Library/Application Support/nushell/
  # but HM writes configs to ~/.config/nushell/ (XDG). Symlink so they match.
  home.activation.nushellMacOSConfig = lib.mkIf isDarwin (lib.hm.dag.entryAfter ["writeBoundary"] ''
    mac_dir="$HOME/Library/Application Support/nushell"
    nix_dir="$HOME/.config/nushell"
    if [ -d "$mac_dir" ] && [ ! -L "$mac_dir" ]; then
      $DRY_RUN_CMD mv "$mac_dir" "$mac_dir.bak"
    fi
    if [ ! -L "$mac_dir" ]; then
      $DRY_RUN_CMD ln -sf "$nix_dir" "$mac_dir"
    fi
  '');

  xdg.enable = true;
}
