{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.zed;

  selected =
    if config.apps.lsp != null
    then config.apps.lsp
    else myLib.lsp.mkServers {};
in {
  options.apps.zed = {
    enable = lib.mkEnableOption "Zed Editor (LSP + Vim motions + Typos)";

    defaultEditor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to set zeditor as the default editor: $EDITOR/$VISUAL,
        apps.using.editor and the XDG text/plain handler.
      '';
    };
  };

  config = lib.mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "zed";
    context = myLib.editor.mkContext {
      editor = "zed";
      inherit selected;
    };
    args = {inherit config lib pkgs myLib selected;};
  });
}
