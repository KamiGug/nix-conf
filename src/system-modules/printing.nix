# TODO: make it actually work
# TODO: add pkg for scaning
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.hardware.printing;
in {
  options.my.hardware.printing = {
    enable = lib.mkEnableOption "printing and scanning support";

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Users that should be added to the printer and scanner groups.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.printing = {
      enable = true;

      drivers = [
        pkgs.gutenprint
        pkgs.cups-filters
      ];
    };

    hardware.sane = {
      enable = true;

      extraBackends = [
        pkgs.gutenprint
      ];
    };

    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;

      publish = {
        enable = true;
        userServices = true;
      };
    };

    users.users = lib.genAttrs cfg.users (_: {
      extraGroups = [
        "lp"
        "scanner"
      ];
    });
  };
}
