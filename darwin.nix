{ pkgs, lib, config, ... }:

# darwin.nix — macOS system-level configuration via nix-darwin.
#
# Manages system defaults, Homebrew packages, and launchd services that
# need system-scope access (beyond what Home Manager can do as a user).
#
# Apply with: darwin-rebuild switch --flake .#mac --impure
# Or via: bash setup.sh (handles darwin-rebuild automatically on macOS)

{
  # ── Nix configuration ─────────────────────────────────────────────────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Allow unfree packages (ghostty-bin, etc.)
    warn-dirty = false;
  };

  # Required by nix-darwin — must match the actual macOS version
  system.stateVersion = 6;

  # Primary user for user-scoped system options (Homebrew, etc.).
  # Set via --impure so builtins.getEnv "USER" resolves at switch time.
  system.primaryUser = builtins.getEnv "USER";

  # ── System PATH ────────────────────────────────────────────────────────────
  # Ensures /run/current-system/sw/bin is on PATH for all users/processes
  # (including those launched by launchd, like Ghostty).
  environment.systemPackages = [];

  # ── macOS System Defaults ─────────────────────────────────────────────────
  system.defaults = {
    # Dock
    dock = {
      autohide               = true;
      autohide-delay         = 0.0;
      autohide-time-modifier = 0.2;
      show-recents           = false;
      tilesize               = 48;
      minimize-to-application = true;
    };

    # Finder
    finder = {
      AppleShowAllFiles         = true;
      AppleShowAllExtensions    = true;
      ShowPathbar               = true;
      ShowStatusBar             = true;
      FXPreferredViewStyle      = "Nlsv";  # list view
      _FXShowPosixPathInTitle   = true;
      FXDefaultSearchScope      = "SCcf";  # search current folder
      FXEnableExtensionChangeWarning = false;
    };

    # Keyboard / trackpad
    NSGlobalDomain = {
      AppleKeyboardUIMode            = 3;    # full keyboard access
      ApplePressAndHoldEnabled       = false; # key repeat over press-and-hold
      InitialKeyRepeat               = 15;
      KeyRepeat                      = 2;
      NSAutomaticCapitalizationEnabled      = false;
      NSAutomaticDashSubstitutionEnabled    = false;
      NSAutomaticPeriodSubstitutionEnabled  = false;
      NSAutomaticQuoteSubstitutionEnabled   = false;
      NSAutomaticSpellingCorrectionEnabled  = false;
      NSNavPanelExpandedStateForSaveMode    = true;
      PMPrintingExpandedStateForPrint       = true;
    };

    # Screenshots
    screencapture.location = "~/Desktop";
    screensaver.askForPasswordDelay = 10;

    # Login window
    loginwindow.GuestEnabled = false;

    # Activity Monitor — show all processes
    ActivityMonitor.ShowCategory = 100;
  };

  # ── Homebrew (declarative via nix-darwin) ─────────────────────────────────
  # Manages casks and Mac App Store apps that have no Nix equivalent.
  # Requires Homebrew to be installed: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate  = false;  # don't auto-update on every switch
      cleanup     = "zap";  # remove unlisted formulae/casks
      upgrade     = false;
    };

    # Formulae managed by Nix; only add here what's unavailable in nixpkgs
    brews = [];

    casks = [
      "1password"         # password manager
      "raycast"           # launcher / productivity
      "arc"               # browser
      "slack"             # messaging
      "zoom"              # video conferencing
      "obs"               # screen recording / streaming
    ];

    # Mac App Store apps (requires `mas` — installed by nix-darwin when masApps non-empty)
    masApps = {};
  };

  # ── Security / Privacy ────────────────────────────────────────────────────
  security.pam.services.sudo_local.touchIdAuth = true;  # Touch ID for sudo

  # ── Shell environment (system-wide) ───────────────────────────────────────
  # These paths are prepended system-wide so GUI apps (Ghostty, etc.) find
  # Nix-managed binaries even without sourcing bash profile.
  environment.profiles = [
    "/nix/var/nix/profiles/default"
    "\${HOME}/.nix-profile"
  ];
}
