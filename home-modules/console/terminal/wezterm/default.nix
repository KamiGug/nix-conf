{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.terminal.wezterm;
in {
  options.apps.terminal.wezterm = {
    enable = lib.mkEnableOption "WezTerm config";

    default = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether wezterm is the default terminal: $TERMINAL,
        apps.using.terminal and the XDG terminal handler.
      '';
    };
  };

  config = lib.mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "wezterm";
    context = {font = config.apps.using.terminalFont;};
    args = {inherit config lib pkgs myLib;};
  });
}
