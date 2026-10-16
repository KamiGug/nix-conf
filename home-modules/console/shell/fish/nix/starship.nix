{
  config,
  lib,
  ...
}: let
  cfg = config.apps.fish;
in
  lib.mkIf cfg.starshipEnabled {
    apps.starship.enable = true;
  }
