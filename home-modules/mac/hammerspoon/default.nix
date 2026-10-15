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

  config = mkIf cfg.enable (mkMerge [
    (myLib.program.mk {
      dir = ./.;
      target = "hammerspoon";
      context = {
        prefixMods = "cmd,ctrl,alt,shift";
        terminal = config.apps.using.terminal;
      };
    })

    {
      xdg.configFile = {
        "hammerspoon/Spoons/SpoonInstall.spoon".source = pkgs.fetchzip {
          url = "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/SpoonInstall.spoon.zip";
          sha256 = "sha256-3f0d4znNuwZPyqKHbZZDlZ3gsuaiobhHPsefGIcpCSE=";
        };
        "hammerspoon/Spoons/PaperWM.spoon".source = pkgs.fetchzip {
          url = "https://github.com/mogenson/PaperWM.spoon/raw/release/Spoons/PaperWM.spoon.zip";
          sha256 = "sha256-g70U7BBTQ3MTL1UyRrYoivI2uuh0SLeXNmiN5i387EE=";
        };
      };
    }
  ]);
}
