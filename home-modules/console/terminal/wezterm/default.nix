{
  config,
  lib,
  myLib,
  ...
}: let
  cfg = config.apps.terminal.wezterm;
in {
  options.apps.terminal.wezterm = {
    enable = lib.mkEnableOption "WezTerm config";
  };

  config = lib.mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "wezterm";
    context = {font = config.apps.using.terminalFont;};
  });
}
