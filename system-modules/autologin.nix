{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.my.autoLogin;
in {
  options.my.autoLogin = {
    enable = lib.mkEnableOption "enable autoLogin";
    user = lib.mkOption {
      type = lib.types.str;
      default = "peon";
      description = "Select user to autoLogin as";
    };
    de = lib.mkOption {
      type = lib.types.str;
      default = "niri";
      description = "Select DE to log in to";
    };
  };

  # TODO: make this get DM from using helper
  config = lib.mkIf cfg.enable {
    services.displayManager = {
        enable = true;

        autoLogin = {
          enable = true;
          user = "${cfg.user}";
        };

        wayland = {
          enable = true;
        };
      };
      # TODO: assert de legal option
      services.displayManager.defaultSession = "${cfg.de}";
  };
}
