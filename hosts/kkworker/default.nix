{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "kkworker";
  networking.networkmanager.enable = true;
  # nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
  ];
  system.stateVersion = "25.11";
}
