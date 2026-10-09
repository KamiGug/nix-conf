{
  config,
  lib,
  ...
}: let
  cfg = config.apps.terminal.wezterm;
in {
  options.apps.terminal.wezterm = {
    enable = lib.mkEnableOption "WezTerm config";
  };

  config = lib.mkIf cfg.enable {
    programs.wezterm = {
      enable = true;

      settings = {
        font = lib.generators.mkLuaInline ''wezterm.font("${config.apps.using.terminalFont}")'';
        font_size = 12;
        hide_tab_bar_if_only_one_tab = true;
        keys = [
          {
            key = "Z";
            mods = "CTRL";
            action = "DisableDefaultAssignment";
          }
        ];
      };
    };
  };
}
