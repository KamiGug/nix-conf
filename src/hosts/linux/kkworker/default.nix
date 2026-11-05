{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "kkworker";
  networking.networkmanager.enable = true;

  my.sshd = {
    enable = true;
    authorizedKeys.wisp = ["ssh/public/hosts/kkworker"];
  };
  # nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
  ];
}
