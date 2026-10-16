{
  config,
  lib,
  ...
}: let
  cfg = config.apps.fish;
in
  lib.mkIf cfg.zellijAutostart {
    apps.zellij.enable = lib.mkDefault true;
  }
