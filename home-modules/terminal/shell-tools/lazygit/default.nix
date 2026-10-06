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
        }
        cfg.extraSettings;
    };
  };
}
