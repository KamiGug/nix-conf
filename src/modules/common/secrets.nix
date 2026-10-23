{
  lib,
  myLib,
  config,
  ...
}: let
  cfg = config.sopsSecrets;
in {
  options.sopsSecrets = {
    enable = lib.mkEnableOption "SOPS secrets management";

    options = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = {};
      description = "Per-secret sops options (merged over discovered defaults). Keys are flat '/'-joined names like 'users/peon/password_hash'.";
    };

    keyPath = lib.mkOption {
      type = lib.types.str;
      default = "/etc/sops/age.key";
      description = "Path to the age key file used for sops decryption.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.age.keyFile = lib.mkDefault cfg.keyPath;
    sops.secrets = myLib.sops.buildSecrets {
      root = ../../../secrets;
      inherit (cfg) options;
    };
  };
}
