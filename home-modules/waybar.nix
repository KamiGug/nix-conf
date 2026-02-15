{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.apps.waybar;
in
{
  options.apps.waybar = {
    enable = mkEnableOption "User-level Waybar configuration";

    configText = mkOption {
      type = types.lines;
      default = "";
    };

    styleText = mkOption {
      type = types.lines;
      default = "";
    };
  };

  config = mkIf cfg.enable {

    programs.waybar = {
      enable = true;

      settings = [
        (builtins.fromJSON cfg.configText)
      ];

      style = cfg.styleText;
    };

    home.packages = with pkgs; [
      nerd-fonts.geist-mono
      font-awesome
      networkmanagerapplet
      blueman
      pavucontrol
    ];
  };
}
