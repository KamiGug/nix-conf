{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
with lib; let
  cfg = config.apps.niri;
in {
  options.apps.niri = {
    enable = mkEnableOption "User-level Niri configuration";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.xwayland-satellite #for legacy :D
    ];
    xdg.configFile =
      myLib.template {
        targetPrefix = "niri";
        templateDir = ../../configs/niri-noctalia;
        replacements = {
          terminal = config.apps.using.terminal;
          # launcher = "fuzzel";
          # status-bar = "waybar";
          # lock = "swaylock";
        };
      }
      // myLib.template {
        targetPrefix = "noctalia";
        templateDir = ../../configs/noctalia;
      #   replacements = {
      #   };
      };

    programs.noctalia-shell = {
      enable = true;
    };
  };
}
