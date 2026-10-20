{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.helix;

  selected =
    if config.apps.lsp != null
    then config.apps.lsp
    else myLib.lsp.mkServers {};
in {
  options.apps.helix = {
    enable = lib.mkEnableOption "Helix editor";

    defaultEditor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to set helix as the default editor: $EDITOR/$VISUAL (via hxr),
        apps.using.editor and the XDG text/plain handler.
      '';
    };
  };

  config = lib.mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "helix";
    context = myLib.editor.mkContext {
      editor = "helix";
      inherit selected;
    };
    args = {inherit config lib pkgs myLib selected;};
  });
}
