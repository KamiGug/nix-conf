{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.kakoune;

  moduleArgs = {
    inherit config lib pkgs;
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

  kakouneConfig =
    lib.concatStringsSep "\n" (map (module: module.kakoune) modules);

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
      nixConfig

      {
        programs.kakoune.extraConfig = kakouneConfig;
      }

      (lib.mkIf cfg.defaultEditor {
        apps.using.editor = "kakoune";
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
