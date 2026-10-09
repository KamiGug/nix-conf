{
  config,
  lib,
  myLib,
  ...
}: let
  cfg = config.apps.terminal.kitty;
in {
  options.apps.terminal.kitty = {
    enable = lib.mkEnableOption "Kitty config";

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
  });
}
