{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.nvim;
in {
  options.apps.nvim = {
    enable = lib.mkEnableOption "Neovim setup (FHS sandboxed)";

    defaultEditor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to set nvim-fhs as the default editor: $EDITOR/$VISUAL,
        apps.using.editor and the XDG text/plain handler.
      '';
    };
  };

  config = lib.mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "nvim-fhs";
    args = {inherit config lib pkgs myLib;};
  });
}
