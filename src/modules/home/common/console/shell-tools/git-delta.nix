{
  config,
  lib,
  ...
}: let
  cfg = config.apps.gitDelta;
in {
  options.apps.gitDelta = {
    enable = lib.mkEnableOption "git-delta as the git diff pager";

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {
        line-numbers = true;
      };
      example = {
        line-numbers = true;
        side-by-side = true;
        syntax-theme = "base16";
      };
      description = "Options written to the [delta] section of the git config.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.delta.enable = true;
  };
}
