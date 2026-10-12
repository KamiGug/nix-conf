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
    xdg.configFile =
      (myLib.template {
        targetPrefix = "hammerspoon";
        templateDir = ../../configs/hammerspoon;
        replacements = {
          prefixMods = "cmd,ctrl,alt,shift";
          terminal = config.apps.using.terminal;
        };
      })
      // {
        "hammerspoon/Spoons/SpoonInstall.spoon".source = pkgs.fetchzip {
          url = "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SpoonInstall.spoon.zip";
          sha256 = "sha256-3f0d4znNuwZPyqKHbZZDlZ3gsuaiobhHPsefGIcpCSE=";
        };
        "hammerspoon/Spoons/PaperWM.spoon".source = pkgs.fetchzip {
          url = "https://github.com/mogenson/PaperWM.spoon/raw/release/Spoons/PaperWM.spoon.zip";
          sha256 = "sha256-WcuP/Gmay/F79wdNcfWqfr0qOXdw/rtTg1Hpx0N+QIk=";
        };
      };
  };
}
