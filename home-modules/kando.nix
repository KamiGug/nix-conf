{
  config,
  lib,
  pkgs,
  # myLib,
  ...
}:
with lib; let
  cfg = config.apps.kando;

  # templateDir = ../configs/waybar;
in {
  options.apps.kando = {
    enable = mkEnableOption "Enable Kando (action ring)";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      kando
    ];
  };
}
