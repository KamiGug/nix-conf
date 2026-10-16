{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.terminal.wezterm;
in
  lib.mkMerge [
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
  ]
