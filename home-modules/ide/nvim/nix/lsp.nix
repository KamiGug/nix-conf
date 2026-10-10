{
  config,
  lib,
  myLib,
  ...
}: let
  selected =
    if config.apps.lsp != null
    then config.apps.lsp
    else myLib.lsp.mkServers {};

  allServers = lib.mergeAttrsList (
    lib.mapAttrsToList (_: lang: lang.servers) selected.langs ++ [selected.globals]
  );
in {
  home.packages = lib.mapAttrsToList (_: server: server.package) allServers;
}