# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{pkgs, ...}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."luks-49d2d068-28eb-4625-8f0e-26bb8d4ad65c".device = "/dev/disk/by-uuid/49d2d068-28eb-4625-8f0e-26bb8d4ad65c";
  networking.hostName = "kkserv";
  networking.networkmanager.enable = true;

  my.sshd = {
    enable = true;
    authorizedKeys.wisp = ["ssh/public/hosts/kkserv"];
  };

  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
  ];
}
