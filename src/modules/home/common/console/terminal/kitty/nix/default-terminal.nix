{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.terminal.kitty;
in
  lib.mkMerge [
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
  ]
