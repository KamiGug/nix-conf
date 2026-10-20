{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
with lib; let
  cfg = config.apps.hammerspoon;
in {
  options.apps.hammerspoon = {
    enable = mkEnableOption "Hammerspoon + PaperWM configuration";
  };

  config = mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "hammerspoon";
    context = {
      prefixMods = "cmd,ctrl,alt,shift";
      terminal = config.apps.using.terminal;
    };
    args = {inherit config lib pkgs myLib;};
  });
}
