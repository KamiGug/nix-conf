{
  config,
  lib,
  myLib,
  ...
}: let
  inherit (lib) mkOption mkEnableOption types;

  cfg = config.apps.git;
in {
  options.apps.git = {
    enable = mkEnableOption "Git configuration with per-host includes";

    user = {
      name = mkOption {
        type = types.str;
        default = "Kamil Gugala";
      };

      email = mkOption {
        type = types.str;
        default = "gug.kamil@gmail.com";
      };
    };
    hosts = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          name = mkOption {type = types.str;};
          email = mkOption {type = types.str;};
        };
      });

      default = {};
      description = "Per-host git identity overrides";
    };
  };

  config = lib.mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = "git";
    args = {inherit config lib myLib;};
  });
}
