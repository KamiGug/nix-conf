{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.terminal;

  anyEnabled = cfg.kitty.enable || cfg.wezterm.enable;
  defaultEnabled = cfg.${cfg.default}.enable;

  commands = {
    kitty = "kitty";
    wezterm = "wezterm start";
  };

  desktopFiles = {
    kitty = "kitty.desktop";
    wezterm = "org.wezfurlong.wezterm.desktop";
  };
in {
  options.apps.terminal = {
    default = lib.mkOption {
      type = lib.types.enum ["kitty" "wezterm"];
      default = "wezterm";
      description = "Terminal used for the xdg default terminal handler, $TERMINAL and apps.using.terminal.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf anyEnabled {
      assertions = [
        {
          assertion = defaultEnabled;
          message = "apps.terminal.default is \"${cfg.default}\" but apps.terminal.${cfg.default}.enable is false";
        }
      ];

      home.packages = with pkgs; [
        nerd-fonts.geist-mono
        mcat
      ];
    })

    (lib.mkIf defaultEnabled {
      home.sessionVariables.TERMINAL = commands.${cfg.default};

      apps.using.terminal = commands.${cfg.default};
    })

    (lib.mkIf (defaultEnabled && pkgs.stdenv.hostPlatform.isLinux) {
      home.packages = with pkgs; [
        wl-clipboard
      ];

      xdg.mimeApps = {
        enable = true;

        defaultApplications = {
          "x-scheme-handler/terminal" = desktopFiles.${cfg.default};
          "application/x-terminal-emulator" = desktopFiles.${cfg.default};
        };
      };
    })
  ];
}
