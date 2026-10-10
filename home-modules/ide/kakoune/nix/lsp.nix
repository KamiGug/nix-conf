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

  packages = lib.concatLists (
    lib.mapAttrsToList (
      _: lang: lib.mapAttrsToList (_: server: server.package) lang.servers
    )
    selected.langs
  );
in {
  home.packages = packages ++ [pkgs.kakoune-lsp];
}
