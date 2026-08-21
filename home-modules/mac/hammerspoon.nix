{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
with lib; let
  cfg = config.apps.hammerspoon;
in {
  options.apps.hammerspoon = {
    enable = mkEnableOption "Hammerspoon + PaperWM configuration";
  };

  config = mkIf cfg.enable {
    xdg.configFile = myLib.template {
      targetPrefix = "hammerspoon";
      templateDir = ../../configs/hammerspoon;
      replacements = {
        prefixMods = "cmd,ctrl,alt,shift";
        terminal = config.apps.using.terminal;
      };
    };
  };
}
