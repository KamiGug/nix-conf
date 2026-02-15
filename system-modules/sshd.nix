{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.my.sshd;

  authorizedKeys = concatStringsSep "\n" (map (k: builtins.readFile config.sops.secrets.${k}.path) cfg.publicKeys);
in {
  options.my.sshd = {
    enable = mkEnableOption "Hardened SSH daemon";

    port = mkOption {
      type = types.port;
      default = 22;
      description = "SSH listen port";
    };

    publicKeys = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of sops secret names containing public SSH keys.";
    };

    allowRoot = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;
      ports = [cfg.port];
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin =
          if cfg.allowRoot
          then "prohibit-password"
          else "no";
        X11Forwarding = false;
        AllowTcpForwarding = "no";
        UsePAM = true;
        AuthenticationMethods = "publickey";
      };
    };

    users.users.root.openssh.authorizedKeys.keyFiles = [];
    users.users.root.openssh.authorizedKeys.keys = mkIf cfg.allowRoot [authorizedKeys];

    security.fail2ban = {
      enable = true;
      maxretry = 5;
      bantime = "1h";
    };

    networking.firewall.allowedTCPPorts = [cfg.port];
  };
}
