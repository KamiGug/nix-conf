{
  config,
  lib,
  ...
}: let
  cfg = config.apps.zsh;
in
  lib.mkIf cfg.zellijAutostart {
    apps.zellij.enable = lib.mkDefault true;
  }
