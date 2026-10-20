{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
with lib; let
  cfg = config.apps.waybar;
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

  config = mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "waybar";
    context = {
      inherit (cfg) font launcher;
      terminal = config.apps.using.terminal;
    };
    args = {inherit config lib pkgs myLib;};
  });
}
