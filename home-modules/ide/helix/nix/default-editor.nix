{
  config,
  lib,
  ...
}:
lib.mkIf config.apps.helix.defaultEditor {
  apps.using.editor = "helix";

  home.sessionVariables = {
    EDITOR = "hxr";
    VISUAL = "hxr";
  };
}
