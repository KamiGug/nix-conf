{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.nvim;

  selected =
    if config.apps.lsp != null
    then config.apps.lsp
    else myLib.lsp.mkServers {};
in {
  options.apps.nvim = {
    enable = lib.mkEnableOption "Neovim editor";

    defaultEditor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to set nvim as the default editor: $EDITOR/$VISUAL,
        apps.using.editor and the XDG text/plain handler.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    myLib.program.mk {
      dir = ./.;
      target = "nvim";
      args = {inherit config lib pkgs myLib selected;};
    }
  );
}
