{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.helix;

  hxrPackage = pkgs.callPackage ../../../pkgs/hxr {};

  moduleArgs = {
    inherit config lib pkgs myLib;
  };

  files =
    lib.filterAttrs
    (name: type:
      type
      == "regular"
      && lib.hasSuffix ".nix" name
      && name != "default.nix")
    (builtins.readDir ./.);

  modules =
    map
    (name: (import ./${name}) moduleArgs)
    (lib.attrNames files);

  nixConfig =
    lib.mkMerge (map (module: module.nix) modules);

  helixConfig =
    lib.mkMerge (map (module: module.helix) modules);

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
        nixConfig

        {
          programs.helix.settings = helixConfig;

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
