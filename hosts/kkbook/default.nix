{
  pkgs,
  config,
  myLib,
  # inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = "nodev";

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.useOSProber = true;

  fileSystems."/workspace" = {
    device = "/dev/disk/by-uuid/a7b0cad3-8bd9-43f4-8ca1-8eed05384dc1";
    fsType = "ext4";
    options = ["nofail" "x-systemd.automount"];
  };

  my.autoLogin.enable = true;

  my.printing = {
    enable = true;
    users = [ "peon" ];
  };

  nixpkgs.config.allowUnfree = true;
  my.gaming = {
    enable = true;

    steam.enable = true;
    lutris.enable = true;
    sunshine.enable = false;

    nvidia = {
      enable = true;
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.legacy_535;

      prime = {
        enable = true;

        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };

  nixpkgs.config.nvidia.acceptLicense = true;
  # programs.neovim = {
  #   enable = true;
  #   defaultEditor = true;
  # };

  virtualisation = {
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  environment.systemPackages = with pkgs; [
    dive
    podman-tui
    # docker-compose
    podman-compose
  ];

  networking.hostName = "kkbook";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

#   Tests
  networking.hosts."127.0.0.1" = let
    domain = "arpa";
    services = [
      "file"
      "auth"
    ];
  in map (name : "${name}.${domain}") services;
  services.my.nextcloud = {
    enable = false;
    user = "peon";
  };
# // myLib.apps.nextcloud {
#   configArgs = {
#     protocol = "http";
#     rootDomain = "arpa";
#     # domain = "127.0.0.1";
#   };
}
