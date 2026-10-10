{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.helix;

  hxrPackage = pkgs.callPackage ../../../pkgs/hxr {};

  selected =
    if config.apps.lsp != null
    then config.apps.lsp
    else myLib.lsp.mkServers {};

  inherit (selected) langs globals;

  allServers = lib.mergeAttrsList (
    lib.mapAttrsToList (_: lang: lang.servers) langs ++ [globals]
  );

  languageServersFor = lang:
    lib.mapAttrsToList (id: _: id) lang.servers ++ lib.attrNames globals;

  languages = lib.concatLists (
    lib.mapAttrsToList (
      _: lang:
        map
        (name: {
          inherit name;
          inherit (lang) roots;
          servers = languageServersFor lang;
        })
        lang.editors.helix
    )
    langs
  );

  servers =
    lib.mapAttrsToList (
      id: server:
        {
          inherit id;
          bin = "${server.package}/bin/${server.command}";
        }
        // lib.optionalAttrs (server.args != []) {inherit (server) args;}
        // lib.optionalAttrs (server ? initializationOptions) {
          config = server.initializationOptions;
        }
    )
    allServers;

  defaultEditors = lib.filter (enabled: enabled) [
    (cfg.enable && cfg.defaultEditor)
    (config.apps.kakoune.enable && config.apps.kakoune.defaultEditor)
    (config.apps.nvim.enable && config.apps.nvim.defaultEditor)
    (config.apps.zed.enable && config.apps.zed.defaultEditor)
  ];
in {
  options.apps.helix = {
    enable = lib.mkEnableOption "Helix editor";

    defaultEditor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to set helix as the default editor: $EDITOR/$VISUAL (via hxr),
        apps.using.editor and the XDG text/plain handler.
      '';
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = lib.length defaultEditors <= 1;
          message = "Only one default editor can be active, disable apps.helix.defaultEditor, apps.kakoune.defaultEditor, apps.nvim.defaultEditor or apps.zed.defaultEditor.";
        }
      ];
    }

    (lib.mkIf cfg.enable (
      lib.mkMerge [
        (myLib.program.mk {
          dir = ./.;
          target = "helix";
          context = {inherit languages servers;};
          args = {inherit config lib pkgs myLib;};
        })

        {
          home.packages = [hxrPackage];
        }

        (lib.mkIf cfg.defaultEditor {
          apps.using.editor = "helix";

          home.sessionVariables = {
            EDITOR = "hxr";
            VISUAL = "hxr";
          };
        })

        (lib.mkIf (cfg.defaultEditor && pkgs.stdenv.hostPlatform.isLinux) {
          xdg = {
            dataFile."applications/Helix.desktop".text = ''
              [Desktop Entry]
              Name=Helix
              GenericName=Text Editor
              Comment=Edit text files through hxr
              TryExec=hxr
              Exec=hxr %F
              Terminal=true
              Type=Application
              Keywords=Text;editor;
              Icon=helix
              Categories=Utility;TextEditor;ConsoleOnly
              StartupNotify=false
              MimeType=text/english;text/plain;text/x-makefile;text/x-c++hdr;text/x-c++src;text/x-chdr;text/x-csrc;text/x-java;text/x-moc;text/x-pascal;text/x-tcl;text/x-tex;application/x-shellscript;text/x-c;text/x-c++;
            '';

            mimeApps = {
              enable = true;
              defaultApplications."text/plain" = "Helix.desktop";
            };
          };
        })
      ]
    ))
  ];
}
