{
  config,
  lib,
  myLib,
  ...
}: let
  cfg = config.apps.nvim;

  selected = myLib.lsp.mkServers {blacklist = [];};

  allServers =
    lib.mergeAttrsList (
      lib.mapAttrsToList (_: lang: lang.servers) selected.langs
    )
    ++ [selected.globals];

  # Tokens substituted into every file under config/:
  # ${LSP_<id>} becomes the store path of that server binary.
  replacements =
    lib.mapAttrs
    (_: server: "${server.package}/bin/${server.command}")
    allServers;

  files = myLib.template {
    targetPrefix = "nvim";
    templateDir = ./config;
    inherit replacements;
  };
in {
  config = lib.mkIf cfg.enable {
    xdg.configFile = files;
  };
}
