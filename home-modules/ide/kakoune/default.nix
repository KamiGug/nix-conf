{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.kakoune;

  selected =
    if config.apps.lsp != null
    then config.apps.lsp
    else myLib.lsp.mkServers {};

  languages =
    lib.mapAttrsToList (
      _: lang: {
        pattern = lib.concatStringsSep "|" lang.filetypes;
        inherit (lang) roots;
        servers =
          lib.mapAttrsToList (
            _: server:
              {
                inherit (server) command;
              }
              // lib.optionalAttrs (server.args != []) {inherit (server) args;}
          )
          lang.servers;
      }
    )
    selected.langs;

  filetypes = lib.concatStringsSep "|" (
    lib.unique (
      lib.concatLists (
        lib.mapAttrsToList (_: lang: lang.filetypes) selected.langs
      )
    )
  );

  kakouneDesktopFile = ''
    [Desktop Entry]
    Name=Kakoune
    GenericName=Text Editor
    Comment=Edit text files
    TryExec=kak
    Exec=kak %F
    Terminal=true
    Type=Application
    Keywords=Text;editor;
    Categories=Utility;TextEditor;
    StartupNotify=false
    MimeType=text/plain;
  '';
in {
  options.apps.kakoune = {
    enable = lib.mkEnableOption "Kakoune editor";

    defaultEditor = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to set kak as the default editor: $EDITOR/$VISUAL,
        apps.using.editor and the XDG text/plain handler.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (myLib.program.mk {
        dir = ./.;
        target = "kak";
        context = {
          lsp = {inherit languages filetypes;};
        };
        args = {inherit config lib pkgs myLib;};
      })

      (lib.mkIf cfg.defaultEditor {
        apps.using.editor = "kakoune";

        home.sessionVariables = {
          EDITOR = "kak";
          VISUAL = "kak";
        };
      })

      (lib.mkIf (cfg.defaultEditor && pkgs.stdenv.hostPlatform.isLinux) {
        xdg = {
          dataFile."applications/kakoune.desktop".text = kakouneDesktopFile;

          mimeApps = {
            enable = true;
            defaultApplications."text/plain" = "kakoune.desktop";
          };
        };
      })
    ]
  );
}
