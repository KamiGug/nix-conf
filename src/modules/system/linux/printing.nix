# TODO: make it actually work
# TODO: add pkg for scaning
{
  config,
  lib,
  pkgs,
  ...
}: {
  options.my.hardware.printing = {
    enable = lib.mkEnableOption "printing and scanning support";

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Users that should be added to the printer and scanner groups.
      '';
    };

    drivers = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      example = lib.literalExpression "with pkgs; [ hplip splix ]";
      description = ''
        Additional CUPS drivers to install.
      '';
    };
  };

  config = lib.mkIf config.my.hardware.printing.enable {
    services.printing = {
      enable = true;

      drivers =
        [
          pkgs.gutenprint
          pkgs.cups-filters
        ]
        ++ config.my.hardware.printing.drivers;
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

    users.users = lib.genAttrs config.my.hardware.printing.users (_: {
      extraGroups = [
        "lp"
        "scanner"
      ];
    });
  };
}
