{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  # NixOs conf
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Enable sound.

  # Surface conf
  # touch
  services.iptsd = {
    enable = true;
    config = {
      Config = {
        BlockOnPalm = true;
        TouchThreshold = 20;
        StabilityThreshold = 0.1;
      };
    };
  };
  # volume buttons
  boot.kernelModules = ["pinctrl_sunrisepoint"];
  #   services.xserver.wacom.enable = true;

  hardware.microsoft-surface.kernelVersion = "longterm";
  hardware.enableRedistributableFirmware = true;
  #   hardware.cpu.intel.updateMicrocode = true;
  # boot.kernelPatches = [
  #   {
  #     name = "disable-rust";
  #     patch = null;
  #     extraConfig = ''
  #       RUST n
  #     '';
  #   }
  # ];

  networking.networkmanager.enable = true;
  networking.hostName = "kktab";

  services.libinput.enable = true;

  my.autoLogin = {
    enable = true;
    de = "plasma";
  };

  # environment.plasma6.excludePackages = with pkgs.kdePackages; [
  #   konsole
  # ];

  system.stateVersion = "25.11";
}
