{
  config,
  lib,
  ...
}: let
  cfg = config.apps.yazi;
in {
  options.apps.yazi.enable =
    lib.mkEnableOption "yazi";

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      enableFishIntegration = true;
      shellWrapperName = "y";
    };

    xdg.configFile."yazi".source = ./config;
  };
}
