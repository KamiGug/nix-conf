# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    # ../../system-modules/de/plasma
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

  # programs.neovim = {
  #   enable = true;
  #   defaultEditor = true;
  # };

  virtualisation = {
    docker = {
      enable = true;
    };
  };

  programs.zsh.enable = true;

  networking.hostName = "kkbook";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;
}
