{ lib, pkgs, username, ... }:

{
  # Use the host-generated hardware module when applying on a real NixOS
  # machine. CI evaluates the portable configuration without it.
  imports = lib.optional
    (builtins.pathExists /etc/nixos/hardware-configuration.nix)
    /etc/nixos/hardware-configuration.nix;

  system.stateVersion = "24.11";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # This default makes the portable profile buildable in CI. A real host's
  # hardware-configuration.nix overrides it with the detected root filesystem.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  networking.networkmanager.enable = true;
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings.PermitRootLogin = "no";
  };

  users.users.${username} = {
    isNormalUser = true;
    home = "/home/${username}";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
  };

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  programs.nix-ld.enable = true;
  environment.shells = [ pkgs.nushell ];
  environment.systemPackages = [ pkgs.git pkgs.curl ];
}
