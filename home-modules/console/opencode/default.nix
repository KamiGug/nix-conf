{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.opencode;
in {
  options.apps.opencode.enable =
    lib.mkEnableOption "OpenCode AI coding agent";

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (myLib.program.mk {
      dir = ./.;
      target = "opencode";
      context = {};
    })
    {
      home.packages = [pkgs.opencode pkgs.libnotify];
    }
  ]);
}
