{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.zsh;
in {
  options.apps.zsh = {
    enable = lib.mkEnableOption "user shell environment (zsh + tmux helpers)";

    tmuxAutostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically enter tmux on shell startup.";
    };

    zellijAutostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically enter zellij on shell startup.";
    };
  };

  config = lib.mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "zsh";
    args = {inherit config lib pkgs myLib;};
  });
}
