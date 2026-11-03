{pkgs, config, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.luks.devices."luks-a01807be-1532-4b76-9a05-3146d78c1d84".device = "/dev/disk/by-uuid/a01807be-1532-4b76-9a05-3146d78c1d84";

  users.users = {
  "peon" = {
    isNormalUser = true;
    description = "Peon";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
  };
  };

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

