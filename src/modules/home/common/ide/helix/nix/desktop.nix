{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf (config.apps.helix.defaultEditor && pkgs.stdenv.hostPlatform.isLinux) {
  xdg = {
    dataFile."applications/Helix.desktop".text = ''
      [Desktop Entry]
      Name=Helix
      GenericName=Text Editor
      Comment=Edit text files through hxr
      TryExec=hxr
      Exec=hxr %F
      Terminal=true
      Type=Application
      Keywords=Text;editor;
      Icon=helix
      Categories=Utility;TextEditor;ConsoleOnly
      StartupNotify=false
      MimeType=text/english;text/plain;text/x-makefile;text/x-c++hdr;text/x-c++src;text/x-chdr;text/x-csrc;text/x-java;text/x-moc;text/x-pascal;text/x-tcl;text/x-tex;application/x-shellscript;text/x-c;text/x-c++;
    '';

    mimeApps = {
      enable = true;
      defaultApplications."text/plain" = "Helix.desktop";
    };
  };
}
