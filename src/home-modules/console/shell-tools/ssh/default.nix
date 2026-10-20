{
  config,
  lib,
  pkgs,
  myLib,
  ...
}:
with lib; let
  cfg = config.apps.ssh;
in {
  options.apps.ssh = {
    enable = mkEnableOption "User SSH setup";

    privateKeys = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of sops secret names containing private SSH keys.";
    };

    hosts = mkOption {
      type = types.attrsOf (types.submodule ({...}: {
        options = {
          host = mkOption {type = types.str;};
          hostname = mkOption {type = types.str;};
          user = mkOption {
            type = types.str;
            default = "root";
          };
          port = mkOption {
            type = types.nullOr types.port;
            default = null;
          };
          identityFile = mkOption {type = types.str;};
        };
      }));
      default = {};
    };

    sshfs = {
      enable = mkEnableOption "sshfs helpers";

      mounts = mkOption {
        type = types.attrsOf (types.submodule ({...}: {
          options = {
            host = mkOption {type = types.str;};
            remotePath = mkOption {type = types.str;};
            localPath = mkOption {type = types.path;};
            user = mkOption {
              type = types.str;
              default = "root";
            };
          };
        }));
        default = {};
      };
    };
  };

  config = mkIf cfg.enable (myLib.program.mk {
    dir = ./.;
    target = ".ssh";
    name = "ssh";
    homeFile = true;
    force = true;
    args = {inherit config lib pkgs myLib;};
    context = {inherit (cfg) hosts;};
  });
}
