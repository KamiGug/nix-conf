{
  config,
  lib,
  ...
}:
lib.mkIf config.apps.zed.defaultEditor {
  programs.zed-editor.defaultEditor = true;
  apps.using.editor = "zed";
}
