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

  config = mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "niri-noctalia";
    args = {inherit config lib pkgs myLib;};
  });
}
