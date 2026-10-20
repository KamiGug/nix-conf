{
  config,
  lib,
  myLib,
  ...
}:
with lib; let
  cfg = config.apps.plasma;
in {
  options.apps.plasma = {
    enable = mkEnableOption "User-level Plasma configuration";
  };

  config = mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "plasma";
    args = {inherit config lib myLib;};
  });
}
