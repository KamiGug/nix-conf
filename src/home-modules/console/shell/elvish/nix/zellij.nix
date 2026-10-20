{
  config,
  lib,
  ...
}: let
  cfg = config.apps.elvish;
in
  lib.mkIf cfg.zellijAutostart {
    apps.zellij.enable = lib.mkDefault true;
  }
