{
  config,
  lib,
  myLib,
  ...
}: let
  cfg = config.apps.yazi;

  edit = myLib.editor.mkEditCommands {file = "%s";} config.apps.using.editor;
in {
  options.apps.yazi.enable =
    lib.mkEnableOption "yazi";

  config = lib.mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "yazi";
    context = {editFile = edit.file;};
  });
}
