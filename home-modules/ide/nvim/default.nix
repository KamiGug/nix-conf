{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.nvim;
in {
  config = lib.mkIf cfg.enable (
    myLib.program.mk {
      dir = ./.;
      target = "nvim";
      args = {inherit config lib pkgs myLib;};
    }
  );
}
