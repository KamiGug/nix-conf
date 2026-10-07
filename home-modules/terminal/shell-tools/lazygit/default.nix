{
  config,
  lib,
  ...
}: let
  cfg = config.apps.lazygit;
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
            edit = ''
              if [ -n "$KAKOUNE_SESSION" ]; then
                kak -c "$KAKOUNE_SESSION" "{{filename}}"
              else
                kak "{{filename}}"
              fi
            '';

            editAtLine = ''
              if [ -n "$KAKOUNE_SESSION" ]; then
                kak -c "$KAKOUNE_SESSION" "{{filename}}" "{{line}}"
              else
                kak "{{filename}}" "{{line}}"
              fi
            '';

            editAtLineAndWait = ''
              if [ -n "$KAKOUNE_SESSION" ]; then
                kak -c "$KAKOUNE_SESSION" "{{filename}}" "{{line}}"
              else
                kak "{{filename}}" "{{line}}"
              fi
            '';

            open = ''
              if [ -n "$KAKOUNE_SESSION" ]; then
                kak -c "$KAKOUNE_SESSION" "{{filename}}"
              else
                kak "{{filename}}"
              fi
            '';

            editInTerminal = true;
          };

          git.diffRenderers =
            lib.optionals config.apps.gitDelta.enable [
              {
                name = "delta";
                command = "delta --paging=never";
              }
            ]
            ++ lib.optionals config.apps.difftastic.enable [
              {
                type = "extDiff";
                name = "difftastic";
                command = "difft --color=always --context={{diffContext}}";
              }
            ];
        }
        cfg.extraSettings;
    };
  };
}
