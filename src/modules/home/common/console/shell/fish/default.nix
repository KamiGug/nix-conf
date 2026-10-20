{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.fish;
in {
  options.apps.fish = {
    enable = lib.mkEnableOption "Fish configuration";

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

    starshipEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable starship";
    };
  };

  config = lib.mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "fish";
    args = {inherit config lib pkgs myLib;};
  });
}
