{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
with lib; let
  cfg = config.apps.niri;
in {
  options.apps.niri = {
    enable = mkEnableOption "User-level Niri configuration";
  };

  config = mkIf cfg.enable (mkMerge [
    (myLib.program.mk {
      dir = ./niri;
      target = "niri";
      context = {terminal = config.apps.using.terminal;};
    })

    (myLib.program.mk {
      dir = ./noctalia;
      target = "noctalia";
    })

    {
      home.packages = [
        pkgs.xwayland-satellite #for legacy :D
        # pkgs.noctalia-shell
      ];
      programs.noctalia.enable = true;
    }
  ]);
}
