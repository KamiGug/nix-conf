{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.nvim;

  selected =
    if config.apps.lsp != null
    then config.apps.lsp
    else myLib.lsp.mkServers {};
in {
  config = lib.mkIf cfg.enable (
    myLib.program.mk {
      dir = ./.;
      target = "nvim";
      args = {inherit config lib pkgs myLib selected;};
    }
  );
}
