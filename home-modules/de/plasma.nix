{
  config,
  # pkgs,
  lib,
  ...
}: let
  cfg = config.apps.plasma;
in {
  options.apps.plasma = {
    enable = lib.mkEnableOption "KDE Plasma";
  };

  config = lib.mkIf cfg.enable {
    # home.packages = with pkgs; [
    #   #             plasma
    #   kdePackages.kate
    #   kdePackages.konsole
    #   kdePackages.dolphin
    #   kdePackages.okular
    #   kdePackages.kio-extras
    #   kdePackages.kdeconnect-kde
    #   kdePackages.bluedevil
    # ];

    # home.sessionVariables = {
    # XDG_CURRENT_DESKTOP = "KDE";
    # XDG_SESSION_DESKTOP = "KDE";
    # QT_QPA_PLATFORM = "wayland;xcb";
    # QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    # };

    # xdg.configFile."kdeglobals".text = ''
    #   [General]
    #   ColorScheme=BreezeDark
    # '';

    # programs.kde = {
    #   enable = true;
    # };
  };
}
