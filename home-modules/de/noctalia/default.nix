{
  config,
  lib,
  myLib,
  ...
}:
with lib; let
  cfg = config.apps.noctalia;
in {
  options.apps.noctalia = {
    enable = mkEnableOption "User-level noctalia configuration";
  };

  config = mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "noctalia";
    args = {inherit config lib myLib;};
  });
}
