{
  config,
  lib,
  myLib,
  ...
}: let
  cfg = config.apps.yazi;

  edit = myLib.editor.mkEditCommands {file = "%s";} config.apps.using.editor;
in {
  options.apps.yazi.enable =
    lib.mkEnableOption "yazi";

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      enableFishIntegration = true;
      shellWrapperName = "y";

      settings = {
        mgr = {
          show_hidden = true;
          sort_by = "natural";
          sort_dir_first = true;
          linemode = "size";
        };

        preview = {
          wrap = "yes";
          tab_size = 2;
        };

        opener = {
          edit = [
            {
              run = edit.file;
              block = true;
              for = "unix";
            }
          ];

          open = [
            {
              run = "xdg-open %s1";
              orphan = true;
              for = "unix";
            }
          ];
        };

        open.rules = [
          {
            url = "*/";
            use = ["edit" "open"];
          }
          {
            mime = "text/*";
            use = ["edit" "open"];
          }
          {
            mime = "application/json";
            use = ["edit" "open"];
          }
          {
            mime = "application/x-yaml";
            use = ["edit" "open"];
          }
          {
            mime = "application/toml";
            use = ["edit" "open"];
          }
          {
            url = "*";
            use = ["open"];
          }
        ];
      };
    };

    xdg.configFile."yazi/keymap.toml".source = ./config/keymap.toml;
  };
}
