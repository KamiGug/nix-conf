{
  config,
  lib,
  myLib,
  ...
}: let
  cfg = config.apps.lazygit;

  edit =
    myLib.editor.mkEditCommands {
      file = ''"{{filename}}"'';
      line = ''"{{line}}"'';
    }
    config.apps.using.editor;
in {
  options.apps.lazygit = {
    enable = lib.mkEnableOption "lazygit";

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Extra lazygit settings merged into programs.lazygit.settings.";
    };
  };

  config = lib.mkIf cfg.enable {
    apps.difftastic.enable = lib.mkDefault true;
    apps.gitDelta.enable = lib.mkDefault true;

    programs.lazygit = {
      enable = true;

      settings =
        lib.recursiveUpdate
        {
          os = {
            edit = edit.file;

            editAtLine = edit.atLine;

            editAtLineAndWait = edit.atLine;

            open = edit.file;

            editInTerminal = true;
          };

          # The first renderer is the default; `|` cycles through the rest.
          git.diffRenderers =
            lib.optionals config.apps.difftastic.enable [
              {
                type = "extDiff";
                name = "difftastic";
                command = "difft --color=always --context={{diffContext}}";
              }
            ]
            ++ lib.optionals config.apps.gitDelta.enable [
              {
                name = "delta";
                command = "delta --paging=never";
              }
            ];

          customCommands = lib.optionals config.apps.opencode.enable [
            {
              key = "<alt+c>";
              context = "files";
              command = "gen-msg -c";
              description = "Copy AI-generated commit message";
              output = "popup";
            }
          ];
        }
        cfg.extraSettings;
    };
  };
}
