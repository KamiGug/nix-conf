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

    configText = mkOption {
      type = types.lines;
      default = "";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.fuzzel
      pkgs.swaylock
      pkgs.xwayland-satellite #for legacy :D
      # pkgs.niri
    ];

    apps.waybar = {
      enable = true;

      font = config.apps.using.terminalFont;
      launcher = "fuzzel";
    };
    xdg.configFile = myLib.template {
      targetPrefix = "niri";
      templateDir = ../../configs/niri-manual;
      replacements = {
        terminal = config.apps.using.terminal;
        launcher = "fuzzel";
        status-bar = "waybar";
        lock = "swaylock";
      };
    };
  };
}
