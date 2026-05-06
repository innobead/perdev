{
  description = "Ubuntu + macOS home environment — Nix + Home Manager";

  inputs = {
    # nixpkgs-unstable: avoids carapace+nushell bug in nixos-25.05 (HM issue #7517)
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixGL: OpenGL driver bridge for Nix-packaged GUI apps (Ghostty) on Ubuntu.
    # Not used on macOS — Darwin has native Metal/OpenGL support.
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nixgl, ... }:
    let
      linuxPkgs  = nixpkgs.legacyPackages."x86_64-linux";
      darwinPkgs = nixpkgs.legacyPackages."aarch64-darwin";
    in {
      # ── Ubuntu / Linux profile ─────────────────────────────────────────────
      # Run: home-manager switch --flake .#ubuntu --impure
      homeConfigurations."ubuntu" = home-manager.lib.homeManagerConfiguration {
        pkgs = linuxPkgs;
        extraSpecialArgs = { inherit nixgl; isDarwin = false; };
        modules = [
          # nixGL home-manager module adds config.lib.nixGL.wrap for GPU bridging
          nixgl.homeManagerModules.nixGL
          {
            # nixGL settings are here (not in home.nix) so macOS config stays clean
            # Change "mesa" to "nvidia" for NVIDIA GPUs
            nixGL.packages       = nixgl.packages;
            nixGL.defaultWrapper = "mesa";
            nixGL.installScripts = [ "mesa" ];
          }
          ./home.nix
        ];
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
