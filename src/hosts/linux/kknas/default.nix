{
  pkgs,
  lib,
  myLib,
  ...
}: let
  domain = "lab.hm";
  root = "/mnt/nas";
  postgres = myLib.services.presets.postgres {
    inherit root;
    databases = {
      nextcloud = {};
    };
  };
  nextcloud = myLib.services.presets.nextcloud {
    inherit root domain;
    networks = ["nextcloud"];
    postgres = {
      host = postgres.fullName;
    };
  };
  env = myLib.services.mkEnv {
    inherit domain root;
    services = [postgres nextcloud];
  };
in {
  imports = [
    ./hardware-configuration.nix
    env.module
  ];

  drives = [
    {
      name = "tank";
      type = "z1";
      mount = "/mnt/nas";
      disks = [
        "/dev/sda"
        "/dev/sdc"
        "/dev/sdd"
      ];
      encryptionKeys = [
        {
          device = "/dev/sda";
          keyName = "common/encryption/keys/auto";
        }
        {
          device = "/dev/sdc";
          keyName = "common/encryption/keys/auto";
        }
        {
          device = "/dev/sdd";
          keyName = "common/encryption/keys/auto";
        }
      ];
    }
  ];

  sopsSecrets.enable = true;

  sops.secrets."common/encryption/keys/auto" = {
    path = "/run/keys/common/encryption/keys/auto";
  };
  sops.secrets."common/encryption/keys/manual" = {
    path = "/run/keys/common/encryption/keys/manual";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.root = null;
  boot.zfs.forceImportRoot = false;

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

  environment.systemPackages = with pkgs; [
    vim
  ];
}
