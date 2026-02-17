{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
with lib; let
  cfg = config.apps.waybar;

  templateDir = ../configs/waybar;
in {
  options.apps.waybar = {
    enable = mkEnableOption "User-level Waybar configuration";

    font = mkOption {
      type = types.str;
      description = "Font family used in Waybar style";
    };

    launcher = mkOption {
      type = types.str;
      description = "Launcher";
      default = "fuzzel";
    };
  };

  config = mkIf cfg.enable {
    programs.waybar.enable = true;

    xdg.configFile = myLib.template {
      targetPrefix = "waybar";
      inherit templateDir;
      replacements = {
        font = cfg.font;
        launcher = cfg.launcher;
      };
    };

    home.packages = with pkgs; [
      # nerd-fonts.geist-mono
      # font-awesome
      networkmanagerapplet
      blueman
      pavucontrol
    ];
  };
}
