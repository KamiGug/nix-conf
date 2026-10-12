{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf (config.apps.kakoune.defaultEditor && pkgs.stdenv.hostPlatform.isLinux) {
  xdg = {
    dataFile."applications/kakoune.desktop".text = ''
      [Desktop Entry]
      Name=Kakoune
      GenericName=Text Editor
      Comment=Edit text files
      TryExec=kak
      Exec=kak %F
      Terminal=true
      Type=Application
      Keywords=Text;editor;
      Categories=Utility;TextEditor;
      StartupNotify=false
      MimeType=text/plain;
    '';

    mimeApps = {
      enable = true;
      defaultApplications."text/plain" = "kakoune.desktop";
    };
  };
}
