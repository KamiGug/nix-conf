{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.my.avahi;
in {
  options.my.avahi = {
    enable = mkEnableOption "Enable the avahi daemon";
  };

  config = mkIf cfg.enable {
    services.avahi = {
      enable = true;
      publish = {
        enable = true;
        domain = true;
      };
      nssmdns4 = true;
      nssmdns6 = true;
    };
  };
}
