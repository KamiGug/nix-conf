#TODO: starship, elvish-bash-completion, carapace, atuin (+ add to ctrl + R). yazi, fzf, fd, rg, direnv
{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.elvish;
in {
  options.apps.elvish = {
    enable = lib.mkEnableOption "Elvish configuration";

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
    target = "elvish";
    args = {inherit config lib pkgs myLib;};
  });
}
