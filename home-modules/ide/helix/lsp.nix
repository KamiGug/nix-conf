{
  config,
  lib,
  pkgs,
  myLib,
  lsp,
  ...
}: let
  selected =
    if lsp != null
    then lsp
    else myLib.lsp.mkServers {};

  inherit (selected) langs globals;

  allServers = lib.mergeAttrsList (
    lib.mapAttrsToList (_: lang: lang.servers) langs ++ [globals]
  );

  languageServersFor = lang:
    lib.mapAttrsToList (id: _: id) lang.servers ++ lib.attrNames globals;

  language = lib.concatLists (
    lib.mapAttrsToList (
      _: lang:
        map
        (name: {
          inherit name;
          inherit (lang) roots;
          language-servers = languageServersFor lang;
        })
        lang.editors.helix
    )
    langs
  );

  languageServers =
    lib.mapAttrs (
      _: server:
        {
          command = "${server.package}/bin/${server.command}";
        }
        // lib.optionalAttrs (server.args != []) {inherit (server) args;}
        // lib.optionalAttrs (server ? initializationOptions) {
          config = server.initializationOptions;
        }
    )
    allServers;

  packages = lib.mapAttrsToList (_: server: server.package) allServers;
in {
  nix = {
    home.packages = packages;

    programs.helix.languages = {
      language-server = languageServers;
      inherit language;
    };
  };

  helix = {};
}
