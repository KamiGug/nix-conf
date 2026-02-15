{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.terminal;
in {
  options.apps.terminal = {
    enable = lib.mkEnableOption "Kitty config";
  };

  config = lib.mkIf cfg.enable {
    home.sessionVariables.TERMINAL = "kitty";

    apps.using.terminal = "kitty";
    apps.using.terminalFont = "GeistMono Nerd Font";

    programs.kitty = {
      enable = true;

      font = {
        name = config.apps.using.terminalFont;
        size = 11;
      };

      settings = {
        enable_audio_bell = false;
        visual_bell_duration = 0.12;
        # visual_bell_color = "E0285D0";
      };
    };
    xdg.mimeApps = {
      enable = true;

      defaultApplications = {
        "x-scheme-handler/terminal" = "kitty.desktop";
        "application/x-terminal-emulator" = "kitty.desktop";
      };
    };

    home.packages = with pkgs; [
      wl-clipboard
      nerd-fonts.geist-mono
    ];
  };
}
