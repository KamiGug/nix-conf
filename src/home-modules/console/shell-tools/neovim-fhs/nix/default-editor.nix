{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.nvim;

  nvimDesktopFile = ''
    [Desktop Entry]
    Name=Neovim
    GenericName=Text Editor
    Comment=Edit text files
    TryExec=nvim-fhs
    Exec=nvim-fhs %F
    Terminal=true
    Type=Application
    Keywords=Text;editor;
    Categories=Utility;TextEditor;Development;
    StartupNotify=false
    MimeType=text/plain;
  '';
in
  lib.mkMerge [
    (lib.mkIf cfg.defaultEditor {
      home.sessionVariables = {
        EDITOR = "nvim-fhs";
        VISUAL = "nvim-fhs";
      };

      apps.using.editor = "neovim";
    })

    (lib.mkIf (cfg.defaultEditor && pkgs.stdenv.hostPlatform.isLinux) {
      xdg = {
        dataFile."applications/nvim.desktop".text = nvimDesktopFile;

        mimeApps = {
          enable = true;
          defaultApplications."text/plain" = "nvim.desktop";
        };
      };
    })
  ]
