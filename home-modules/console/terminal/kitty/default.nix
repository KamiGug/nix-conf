{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.terminal.kitty;
in {
  options.apps.terminal.kitty = {
    enable = lib.mkEnableOption "Kitty config";

    default = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether kitty is the default terminal: $TERMINAL,
        apps.using.terminal and the XDG terminal handler.
      '';
    };

    kittyMod = lib.mkOption {
      type = lib.types.str;
      default = "ctrl+shift";
      description = "Kitty modifier key.";
    };
  };

  config = lib.mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "kitty";

    # programs.kitty always emits kitty.conf, force our rendered one over it.
    force = true;

    context = {
      font = config.apps.using.terminalFont;
      inherit (cfg) kittyMod;
    };

    args = {inherit config lib pkgs myLib;};
  });
}
