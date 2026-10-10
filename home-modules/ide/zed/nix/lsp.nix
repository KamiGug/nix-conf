{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  selected =
    if config.apps.lsp != null
    then config.apps.lsp
    else myLib.lsp.mkServers {};

  langs = lib.filterAttrs (_: lang: lang.editors.zed != null) selected.langs;

  allServers = lib.mergeAttrsList (
    lib.mapAttrsToList (_: lang: lang.servers) langs ++ [selected.globals]
  );
in {
  home.packages =
    lib.mapAttrsToList (_: server: server.package) allServers
    ++ [
      pkgs.alejandra
    ];
}
