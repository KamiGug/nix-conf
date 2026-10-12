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

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (myLib.program.mk {
      dir = ./.;
      target = "kitty";

      # programs.kitty always emits kitty.conf, force our rendered one over it.
      force = true;

      context = {
        font = config.apps.using.terminalFont;
        inherit (cfg) kittyMod;
      };
    })

    (lib.mkIf cfg.default {
      home.sessionVariables.TERMINAL = "kitty";

      apps.using.terminal = "kitty";
    })

    (lib.mkIf (cfg.default && pkgs.stdenv.hostPlatform.isLinux) {
      xdg.mimeApps = {
        enable = true;

        defaultApplications = {
          "x-scheme-handler/terminal" = "kitty.desktop";
          "application/x-terminal-emulator" = "kitty.desktop";
        };
      };
    })
  ]);
}
