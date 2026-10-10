{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.zed;

  selected =
    if config.apps.lsp != null
    then config.apps.lsp
    else myLib.lsp.mkServers {};

  langs = lib.filterAttrs (_: lang: lang.editors.zed != null) selected.langs;

  allServers = lib.mergeAttrsList (
    lib.mapAttrsToList (_: lang: lang.servers) langs ++ [selected.globals]
  );

  languageServersFor = lang:
    lib.mapAttrsToList (id: _: id) lang.servers ++ lib.attrNames selected.globals;

  zedLanguages =
    lib.foldl' (
      acc: lang:
        acc
        // lib.genAttrs lang.editors.zed (_: {language_servers = languageServersFor lang;})
    )
    {}
    (lib.attrValues langs);

  languages =
    zedLanguages
    // lib.optionalAttrs (langs ? nix) {
      "Nix" =
        (zedLanguages."Nix" or {})
        // {
          formatter.external = {
            command = lib.getExe pkgs.alejandra;
            arguments = ["-"];
          };
        };
    };

  lsp =
    lib.mapAttrs (
      _: server:
        {
          binary =
            {
              path = "${server.package}/bin/${server.command}";
            }
            // lib.optionalAttrs (server.args != []) {arguments = server.args;};
        }
        // lib.optionalAttrs (server ? initializationOptions) {
          initialization_options = server.initializationOptions;
        }
    )
    allServers;
in {
  options.apps.zed = {
    enable = lib.mkEnableOption "Zed Editor (LSP + Vim motions + Typos)";

    defaultEditor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to set zeditor as the default editor: $EDITOR/$VISUAL,
        apps.using.editor and the XDG text/plain handler.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (myLib.program.mk {
        dir = ./.;
        target = "zed";
        context = {inherit lsp languages;};
        args = {inherit config lib pkgs myLib;};
      })

      (lib.mkIf cfg.defaultEditor {
        programs.zed-editor.defaultEditor = true;
        apps.using.editor = "zed";
      })

      (lib.mkIf (cfg.defaultEditor && pkgs.stdenv.hostPlatform.isLinux) {
        xdg.mimeApps = {
          enable = true;
          defaultApplications."text/plain" = "dev.zed.Zed.desktop";
        };
      })
    ]
  );
}
