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

    kittyMod = lib.mkOption {
      type = lib.types.str;
      default = "ctrl+shift";
      description = "Kitty modifier key.";
    };
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
        kitty_mod = cfg.kittyMod;
        # visual_bell_color = "E0285D0";
      };
      keybindings = {
        "${cfg.kittyMod}+'" = "launch --cwd=current";

        "${cfg.kittyMod}+t" = "launch --type=tab --cwd=current";

        "${cfg.kittyMod}+z" = "toggle_layout stack";

        "${cfg.kittyMod}+e" = "detach_window ask";
        "${cfg.kittyMod}+r" = "detach_tab ask";

        "${cfg.kittyMod}+left" = "neighboring_window left";
        "${cfg.kittyMod}+right" = "neighboring_window right";
        "${cfg.kittyMod}+up" = "neighboring_window up";
        "${cfg.kittyMod}+down" = "neighboring_window down";

        "${cfg.kittyMod}+alt+left" = "resize_window narrower 1";
        "${cfg.kittyMod}+alt+right" = "resize_window wider 1";
        "${cfg.kittyMod}+alt+up" = "resize_window taller 1";
        "${cfg.kittyMod}+alt+down" = "resize_window shorter 1";

        "${cfg.kittyMod}+[" = "previous_tab";
        "${cfg.kittyMod}+]" = "next_tab";

        "${cfg.kittyMod}+space" = "next_layout";
        "${cfg.kittyMod}+f5" = "load_config_file";
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
