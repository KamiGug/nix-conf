{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.my.sshd;

  keyNames = cfg.authorizedKeys // optionalAttrs cfg.allowRoot {root = cfg.publicKeys;};
in {
  options.my.sshd = {
    enable = mkEnableOption "Hardened SSH daemon";

    port = mkOption {
      type = types.port;
      default = 2122;
      description = "SSH listen port";
    };

    publicKeys = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of sops secret names containing public SSH keys authorized for root.";
    };

    authorizedKeys = mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = {};
      description = "Map of system user to sops secret names containing authorized public SSH keys.";
    };

    allowRoot = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;
      authorizedKeysFiles = ["/run/secrets/rendered/sshd-authorized-keys/%u"];
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

    sops.templates = mapAttrs' (user: keys:
      nameValuePair "sshd-authorized-keys-${user}" {
        path = "/run/secrets/rendered/sshd-authorized-keys/${user}";
        content = concatMapStringsSep "\n" (key: config.sops.placeholder.${key}) keys + "\n";
        mode = "0444";
        restartUnits = ["sshd.service"];
      })
    (filterAttrs (_: keys: keys != []) keyNames);

    services.fail2ban = {
      enable = true;
      maxretry = 5;
      bantime = "1h";
    };
  };
}
