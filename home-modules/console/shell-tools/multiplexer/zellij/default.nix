{
  config,
  lib,
  pkgs,
  myLib,
  ...
}: let
  cfg = config.apps.zellij;
in {
  options.apps.zellij = {
    enable = lib.mkEnableOption "zellij";

    cleanup = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Periodically delete exited zellij sessions.";
      };

      maxAgeDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 7;
        example = 30;
        description = "Delete exited zellij sessions older than this many days.";
      };
    };
  };

  config = lib.mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "zellij";
    args = {inherit config lib pkgs myLib;};
  });
}
