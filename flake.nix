{
  description = "Ubuntu + macOS home environment — Nix + Home Manager + nix-darwin";

  inputs = {
    # nixpkgs-unstable: avoids carapace+nushell bug in nixos-25.05 (HM issue #7517)
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-darwin: macOS system-level configuration (Homebrew, launchd)
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nix-darwin, ... }:
    let
      linuxPkgs  = import nixpkgs { system = "x86_64-linux";  config.allowUnfree = true; };
      darwinPkgs = import nixpkgs { system = "aarch64-darwin"; config.allowUnfree = true; };
    in {
      # ── Ubuntu / Linux profile ─────────────────────────────────────────────
      # Run: home-manager switch --flake .#ubuntu --impure
      homeConfigurations."ubuntu" = home-manager.lib.homeManagerConfiguration {
        pkgs = linuxPkgs;
        extraSpecialArgs = { isDarwin = false; };
        modules = [ ./home.nix ];
      };

      # ── macOS / Apple Silicon profile ─────────────────────────────────────
      # Run: sudo darwin-rebuild switch --flake .#mac --impure
      #
      # Uses nix-darwin for system-level config (defaults, Homebrew, launchd)
      # with Home Manager as a nix-darwin module for user-level config.
      darwinConfigurations."mac" =
        let
          # Prefer SUDO_USER (set by sudo) so darwin-rebuild works correctly
          # when invoked with `sudo` — USER would otherwise be "root".
          username =
            let sudoUser = builtins.getEnv "SUDO_USER";
            in if sudoUser != "" then sudoUser else builtins.getEnv "USER";
        in
        nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { isDarwin = true; nixgl = null; };
          modules = [
            { nixpkgs.config.allowUnfree = true; }
            ./darwin.nix  # macOS system defaults, Homebrew, system PATH
            home-manager.darwinModules.home-manager
            {
              # HM's nixos/common.nix looks up config.users.users.${name} to
              # derive username/homeDirectory — must define the user here.
              users.users.${username} = {
                name = username;
                home = "/Users/${username}";
              };
              home-manager = {
                useGlobalPkgs    = true;
                useUserPackages  = false;  # keep packages in ~/.nix-profile (HM-generated configs reference this path)
                extraSpecialArgs = { isDarwin = true; nixgl = null; };
                users.${username} = { lib, ... }: {
                  imports = [ ./home.nix ];
                  # On macOS homeDirectory is always /Users/$USER; override because
                  # builtins.getEnv "HOME" is empty during nix-darwin module evaluation.
                  home.username      = lib.mkForce username;
                  home.homeDirectory = lib.mkForce "/Users/${username}";
                };
              };
            }
          ];
        };
    };
}
