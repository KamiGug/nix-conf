{ config, lib, pkgs, ... }:

let
  cfg = config.apps.lutris.gamescope;

  lutrisGamescope = pkgs.writeShellScriptBin "lutris-gamescope" ''
    exec ${lib.getExe pkgs.gamescope} \
      -b \
      --xwayland-count 3 \
      -W ${toString cfg.width} \
      -H ${toString cfg.height} \
      --mangoapp \
      --force-grab-cursor \
      ${lib.getExe pkgs.lutris} "$@"
  '';

  # desktopFile = pkgs.makeDesktopItem {
  #   name = "lutris";
  #   desktopName = "Lutris";
  #   genericName = "Game Launcher";
  #   exec = "${lib.getExe lutrisGamescope} %U";
  #   icon = "lutris";
  #   terminal = false;
  #   categories = [ "Game" ];
  #   startupNotify = true;
  #   mimeTypes = [ "x-scheme-handler/lutris" ];
  # };
in
{
  options.apps.lutris.gamescope = {
    enable = lib.mkEnableOption "Launch Lutris through Gamescope";

    width = lib.mkOption {
      type = lib.types.int;
      default = 1920;
      description = "Gamescope output width.";
    };

    height = lib.mkOption {
      type = lib.types.int;
      default = 1080;
      description = "Gamescope output height.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      lutrisGamescope
      # desktopFile
    ];

    # Replace the Steam desktop entry.
    xdg.desktopEntries.lutris = {
      name = "Lutris";
      genericName = "Game Launcher";
      exec = "${lib.getExe lutrisGamescope} %U";
      icon = "lutris";
      terminal = false;
      categories = [ "Game" ];
      startupNotify = true;
      mimeType = [ "x-scheme-handler/lutris" ];
    };
  };
}
