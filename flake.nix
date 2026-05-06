{
  description = "Ubuntu + macOS home environment — Nix + Home Manager";

  inputs = {
    # nixpkgs-unstable: avoids carapace+nushell bug in nixos-25.05 (HM issue #7517)
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      linuxPkgs  = nixpkgs.legacyPackages."x86_64-linux";
      darwinPkgs = nixpkgs.legacyPackages."aarch64-darwin";
    in {
      # ── Ubuntu / Linux profile ─────────────────────────────────────────────
      # Run: home-manager switch --flake .#ubuntu --impure
      homeConfigurations."ubuntu" = home-manager.lib.homeManagerConfiguration {
        pkgs = linuxPkgs;
        extraSpecialArgs = { isDarwin = false; };
        modules = [ ./home.nix ];
      };

      # ── macOS / Apple Silicon profile ─────────────────────────────────────
      # Run: home-manager switch --flake .#mac --impure
      homeConfigurations."mac" = home-manager.lib.homeManagerConfiguration {
        pkgs = darwinPkgs;
        extraSpecialArgs = { nixgl = null; isDarwin = true; };
        modules = [
          ./home.nix  # no nixGL module — macOS uses native Metal/OpenGL
        ];
      };
    };
}
