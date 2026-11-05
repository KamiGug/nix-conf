{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.root = null;

  usbLuksKey = {
    enable = false;
  };

  users.users = {
    "peon" = {
      isNormalUser = true;
      description = "Peon";
      extraGroups = ["networkmanager" "wheel"];
      packages = with pkgs; [];
    };
  };

  networking.hostName = "kknas";
  networking.hostId = "5b977f66";
  networking.networkmanager.enable = true;

  my.sshd = {
    enable = true;
    authorizedKeys.wisp = ["ssh/public/hosts/kknas"];
  };
  # nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
  ];
}
