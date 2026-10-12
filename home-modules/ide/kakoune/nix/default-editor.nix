{
  config,
  lib,
  ...
}:
lib.mkIf config.apps.kakoune.defaultEditor {
  apps.using.editor = "kakoune";

  home.sessionVariables = {
    EDITOR = "kak";
    VISUAL = "kak";
  };
}
