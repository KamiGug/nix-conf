{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf (config.apps.zed.defaultEditor && pkgs.stdenv.hostPlatform.isLinux) {
  xdg.mimeApps = {
    enable = true;
    defaultApplications."text/plain" = "dev.zed.Zed.desktop";
  };
}
