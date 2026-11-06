{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.usbLuksKey;

  # Empty means "all devices managed by the sops-backed luksKey module".
  devices =
    if cfg.devices != []
    then cfg.devices
    else lib.attrNames config.luksKey.devices;

  testDevice =
    if devices == []
    then ""
    else config.boot.initrd.luks.devices.${builtins.head devices}.device or "";
in {
  options.usbLuksKey = {
    enable = lib.mkEnableOption "USB LUKS key fallback";

    label = lib.mkOption {
      type = lib.types.str;
      default = "LUKS-KEY";
      description = "Filesystem label of the USB drive containing the key";
    };

    keyPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Subdirectory on USB drive (empty = root)";
    };

    targetPath = lib.mkOption {
      type = lib.types.path;
      default = "/run/keys/usb-luks-key";
      description = "Where to write the key in initrd";
    };

    devices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        LUKS device names from boot.initrd.luks.devices to unlock with the USB
        key. Empty means all devices from luksKey.devices.
      '';
    };

    timeout = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Seconds to wait for USB device to appear";
    };

    keyFileTimeout = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = ''
        Seconds passed to systemd-cryptsetup as keyfile-timeout. This also marks
        the key file as optional, so a missing key does not fail the unit.
      '';
    };

    fallbackToPassword = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Allow an interactive passphrase prompt when the USB key is missing or
        does not unlock the device. Only used by the scripted (non-systemd)
        stage 1; systemd stage 1 always falls back to a passphrase.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.kernelModules = ["xhci_pci" "usb_storage" "sd_mod" "vfat" "ext4" "f2fs" "exfat"];

    fileSystems = lib.mkIf (config.networking.hostName == "kknas") {
      "/mnt/nas".options = lib.mkForce ["defaults" "nofail"];
    };

    # The actual script is referenced by name from the service below. Nix does
    # not track that textual reference, so add the package to the initrd
    # explicitly. Without this the service fails with "not found" and the USB
    # key is never read.
    boot.initrd.systemd.storePaths = [pkgs.usb-luks-key-script pkgs.cryptsetup];

    boot.initrd.systemd.services.usb-luks-key = {
      description = "Load LUKS key from USB";
      wantedBy = ["initrd.target"];
      after = ["systemd-udevd.service" "systemd-modules-load.service"];
      before = map (name: "systemd-cryptsetup@${name}.service") devices;
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      environment = {
        USB_LUKS_LABEL = cfg.label;
        USB_LUKS_KEY_SUBDIR = cfg.keyPath;
        USB_LUKS_OUTPUT = cfg.targetPath;
        USB_LUKS_TIMEOUT = toString cfg.timeout;
        USB_LUKS_HOSTNAME = config.networking.hostName;
        USB_LUKS_TEST_DEVICE = testDevice;
      };
      script = "${pkgs.usb-luks-key-script}/bin/usb-luks-key";
    };

    boot.initrd.luks.devices = lib.genAttrs devices (_name:
      {
        keyFile = lib.mkForce cfg.targetPath;
      }
      // lib.optionalAttrs config.boot.initrd.systemd.enable {
        inherit (cfg) keyFileTimeout;
      }
      // lib.optionalAttrs (!config.boot.initrd.systemd.enable) {
        inherit (cfg) fallbackToPassword;
      });
  };
}
