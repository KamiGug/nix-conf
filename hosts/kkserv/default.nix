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

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
  ];

  services.ai = {
    enable = true;

    modelUrl = "https://huggingface.co/Lamapi/next-4b-Q4_0-GGUF/resolve/main/next-4b-q4_0.gguf";

    modelSha256 = "0g29ky6rh5ag4qw41zxbil49q53md1gddzkwyqwwbwdmh2bs6nvd";

    ctxSize = 2048;
    threads = 4;

    openClaw.enable = true;
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
