{
  config,
  lib,
  ...
}: let
  cfg = config.apps.zellij;
in {
  options.apps.zellij.enable =
    lib.mkEnableOption "zellij";

  config = lib.mkIf cfg.enable {
    programs.zellij.enable = true;

    xdg.configFile."zellij".source = ./config;
  };
}
