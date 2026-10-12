{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.terminal;

  anyEnabled = cfg.kitty.enable || cfg.wezterm.enable;

  defaults =
    lib.filter
    (id: config.apps.terminal.${id}.enable && config.apps.terminal.${id}.default)
    ["kitty" "wezterm"];
in {
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = lib.length defaults <= 1;
          message = "Only one default terminal can be active, disable apps.terminal.kitty.default or apps.terminal.wezterm.default.";
        }
      ];
    }

    (lib.mkIf anyEnabled {
      home.packages = with pkgs;
        [
          nerd-fonts.geist-mono
          mcat
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [wl-clipboard];
    })
  ];
}
