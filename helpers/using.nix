{
  # config,
  lib,
  # pkgs,
  ...
}: let
  # cfg = config.apps.using;
in {
  options.apps.using = {
    terminal = lib.mkOption {
      type = lib.types.str;
      default = "kitty";
    };

    shell = lib.mkOption {
      type = lib.types.str;
      default = "zsh";
    };

    terminalFont = lib.mkOption {
      type = lib.types.str;
      default = "GeistMono Nerd Font";
    };
  };
}
