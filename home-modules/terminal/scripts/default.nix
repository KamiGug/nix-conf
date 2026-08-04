{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.apps.my.scripts;
in {
  options.apps.my.scripts = {
    enable = lib.mkEnableOption "Enable home scripts";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home.sessionPath = [
        "$HOME/.local/share/scripts"
      ];

      # home.packages = with pkgs; [
      #   bash
      # ];

      home.file = {
        ".local/share/scripts" = {
          source = ./bash;
          recursive = true;
        };
      };
    }
    {}
  ]);
}
