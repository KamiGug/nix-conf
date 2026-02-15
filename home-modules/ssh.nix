{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.apps.ssh;

  # Expect sops secrets like:
  # sops.secrets."ssh/id_ed25519".path
  keyPath = name: config.sops.secrets.${name}.path;

  renderedHosts = concatStringsSep "\n" (mapAttrsToList (_: h: ''
      Host ${h.host}
      HostName ${h.hostname}
      User ${h.user}
      ${optionalString (h.port != null) "Port ${toString h.port}"}
      IdentityFile ${h.identityFile}
      IdentitiesOnly yes
    '')
    cfg.hosts);

  sshConfigText = ''
    Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ForwardAgent no
    AddKeysToAgent no


    ${renderedHosts}
  '';
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
          identityFile = mkOption {type = types.path;};
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

  config = mkIf cfg.enable {
    programs.ssh.enable = true;

    home.file.".ssh/config" = {
      text = sshConfigText;
      # fileMode = "600";
    };

    home.activation.installPrivateKeys = lib.hm.dag.entryAfter ["writeBoundary"] ''
      mkdir -p ~/.ssh
      chmod 700 ~/.ssh
      ${concatStringsSep "\n" (map (k: ''
          install -m 600 ${keyPath k} ~/.ssh/${baseNameOf k}
        '')
        cfg.privateKeys)}
    '';

    home.packages = mkIf cfg.sshfs.enable [pkgs.sshfs];

    # sshfs is used manually. Example:
    # mkdir -p ~/mnt/myhost
    # sshfs myhost:/remote/path ~/mnt/myhost
    # fusermount -u ~/mnt/myhost
  };
}
