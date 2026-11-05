{
  pkgs,
  lib,
  ...
}: let
  manualKey = "/run/secrets/common/encryption/keys/manual";
  autoKey = "/run/secrets/common/encryption/keys/auto";

  dataDisk = index: device: {
    name = "tank_${toString index}";
    value = {
      type = "disk";
      inherit device;
      content = {
        type = "gpt";
        partitions.zfs = {
          size = "100%";
          content = {
            type = "luks";
            name = "crypt_tank_${toString index}";
            settings = {
              keyFile = autoKey;
              allowDiscards = true;
            };
            additionalKeyFiles = [manualKey];
            content = {
              type = "zfs";
              pool = "tank";
            };
          };
        };
      };
    };
  };

  dataDisks = lib.imap0 dataDisk [
    "/dev/sda"
    "/dev/sdc"
    "/dev/sdd"
  ];
in {
  imports = [
    ./hardware-configuration.nix
  ];

  disko.devices = {
    disk = builtins.listToAttrs dataDisks;

    zpool.tank = {
      type = "zpool";
      mode = "raidz1";
      datasets.root = {
        type = "zfs_fs";
        mountpoint = "/mnt/pool";
        options.mountpoint = "legacy";
      };
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;
  boot.zfs.forceImportRoot = false;

  usbLuksKey = {
    enable = true;
    devices = [
      "crypt_root"
      "crypt_swap"
      "crypt_tank_0"
      "crypt_tank_1"
      "crypt_tank_2"
    ];
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
