{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "kknas";
  networking.networkmanager.enable = true;

  my.sshd = {
    enable = true;
    authorizedKeys.wisp = ["ssh/public/hosts/kknas"];
  };
  # nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
  ];
  system.stateVersion = "25.11";
}
