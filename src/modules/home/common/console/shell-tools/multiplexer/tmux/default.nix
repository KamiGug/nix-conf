{
  config,
  lib,
  myLib,
  ...
}: let
  cfg = config.apps.tmux;
in {
  options.apps.tmux = {
    enable = lib.mkEnableOption "tmux";

    leader = lib.mkOption {
      type = lib.types.str;
      default = "C-a";
      example = "C-Space";
      description = ''
        tmux prefix (leader) key.
        This replaces the default C-b.
      '';
    };
  };

  config = lib.mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "tmux";
    force = true;
    context = {inherit (cfg) leader;};
  });
}
