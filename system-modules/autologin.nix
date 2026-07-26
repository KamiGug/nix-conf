{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.my.autologin;
in {
  options.my.autologin = {
    enable = lib.mkEnableOption "enable autologin";
    user = lib.mkOption {
      type = lib.types.string;
      default = "peon";
      description = "Select user to autologin as";
    };
    de = lib.mkOption {
      type = lib.types.string;
      default = "niri";
      description = "Select DE to log in to";
    };
  };

  # TODO: make this get DM from using helper
  config = lib.mkIf cfg.enable {
    services.displayManager.sddm = {
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
