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

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (myLib.program.mk {
      dir = ./.;
      target = "wezterm";
      context = {font = config.apps.using.terminalFont;};
    })

    (lib.mkIf cfg.default {
      home.sessionVariables.TERMINAL = "wezterm start";

      apps.using.terminal = "wezterm start";
    })

    (lib.mkIf (cfg.default && pkgs.stdenv.hostPlatform.isLinux) {
      xdg.mimeApps = {
        enable = true;

        defaultApplications = {
          "x-scheme-handler/terminal" = "org.wezfurlong.wezterm.desktop";
          "application/x-terminal-emulator" = "org.wezfurlong.wezterm.desktop";
        };
      };
    })
  ]);
}
