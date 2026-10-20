{
  lib,
  config,
  ...
}: {
  options.luksKey = {
    enable = lib.mkEnableOption "LUKS key management via sops";

    devices = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          device = lib.mkOption {
            type = lib.types.path;
            description = "Block device path (e.g., /dev/disk/by-uuid/...)";
          };
          keyName = lib.mkOption {
            type = lib.types.str;
            description = "Name of the sops secret containing the key";
          };
          fallbackToPassword = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Allow password fallback if key fails";
          };
        };
      });
      default = {};
      description = "Map of LUKS device name -> config. Each entry requires a matching sops.secrets.<keyName> with initrd = true.";
    };
  };

  config = lib.mkIf config.luksKey.enable {
    # Validate that each device has a corresponding sops secret
    assertions =
      lib.mapAttrsToList (
        name: cfg:
          lib.mkAssert (builtins.hasAttr "path" (config.sops.secrets.${cfg.keyName} or {}))
          "luksKey.devices.${name}: sops.secrets.${cfg.keyName} must be defined with initrd = true"
      )
      config.luksKey.devices;

    # Configure each LUKS device
    boot.initrd.luks.devices =
      lib.mapAttrs (_name: cfg: {
        inherit (cfg) device;
        keyFile = "/run/keys/${cfg.keyName}";
        inherit (cfg) fallbackToPassword;
      })
      config.luksKey.devices;

    # Ensure sops secrets are placed in initrd at /run/keys/
    # This is handled by sops.secrets.<name>.initrd = true and path = "/run/keys/<name>"
    # The host config must set these correctly
  };
}
