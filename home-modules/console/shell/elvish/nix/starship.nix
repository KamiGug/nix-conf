{
  config,
  lib,
  ...
}: let
  cfg = config.apps.elvish;
in
  lib.mkIf cfg.starshipEnabled {
    apps.starship.enable = true;
  }
