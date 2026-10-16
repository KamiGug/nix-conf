{pkgs, ...}: {
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
