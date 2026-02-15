{
  config,
  lib,
  pkgs,
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
      # pkgs.niri
    ];

    apps.waybar = {
      enable = true;

      configText = import ../../configs/waybar/config.json.nix {
        launcher = "fuzzel";
      };

      styleText = import ../../configs/waybar/style.css.nix {
        font = config.apps.using.terminalFont;
      };
    };

    xdg.configFile."niri/config.kdl".text = import ../../configs/niri/config.kdl.nix {
      terminal = config.apps.using.terminal;
      status-bar = "waybar";
      launcher = "fuzzel";
      lock = "swaylock";
    };
  };
}
