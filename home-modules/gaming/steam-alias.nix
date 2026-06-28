{ config, lib, pkgs, ... }:

let
  cfg = config.apps.steam.gamescope;

  steamGamescope = pkgs.writeShellScriptBin "steam-gamescope" ''
    exec ${lib.getExe pkgs.gamescope} \
      -b \
      --xwayland-count 3 \
      -W ${toString cfg.width} \
      -H ${toString cfg.height} \
      --mangoapp \
      --force-grab-cursor \
      ${lib.getExe pkgs.steam} "$@"
  '';

  desktopFile = pkgs.makeDesktopItem {
    name = "steam";
    desktopName = "Steam";
    genericName = "Game Launcher";
    exec = "${lib.getExe steamGamescope} %U";
    icon = "steam";
    terminal = false;
    categories = [ "Game" ];
    startupNotify = true;
    mimeTypes = [ "x-scheme-handler/steam" ];
  };
in
{
  options.apps.steam.gamescope = {
    enable = lib.mkEnableOption "Launch Steam through Gamescope";

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
      steamGamescope
      desktopFile
    ];

    # Replace the Steam desktop entry.
    xdg.desktopEntries.steam = {
      name = "Steam";
      genericName = "Game Launcher";
      exec = "${lib.getExe steamGamescope} %U";
      icon = "steam";
      terminal = false;
      categories = [ "Game" ];
      startupNotify = true;
      mimeType = [ "x-scheme-handler/steam" ];
    };
  };
}
