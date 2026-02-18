{
  config,
  pkgs,
  ...
}: {
  # users.mutableUsers = false;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
    wireplumber.enable = true;
    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  services.blueman.enable = true;

  services.power-profiles-daemon.enable = true;

  services.upower.enable = true;

  systemd.tmpfiles.rules = [
    "d /etc/nixos 2775 root config-editor -"
  ];

  system.stateVersion = "25.11"; # Did you read the comment?
}
