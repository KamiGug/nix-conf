{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.kakoune;

  selected =
    if config.apps.lsp != null
    then config.apps.lsp
    else myLib.lsp.mkServers {};
in {
  options.apps.kakoune = {
    enable = lib.mkEnableOption "Kakoune editor";

    defaultEditor = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to set kak as the default editor: $EDITOR/$VISUAL,
        apps.using.editor and the XDG text/plain handler.
      '';
    };
  };

  config = lib.mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "kak";
    context = myLib.editor.mkContext {
      editor = "kakoune";
      inherit selected;
    };
    args = {inherit config lib pkgs myLib selected;};
  });
}
