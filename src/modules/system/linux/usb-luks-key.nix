{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.usbLuksKey;

  testDevice =
    if cfg.devices == []
    then ""
    else config.boot.initrd.luks.devices.${builtins.head cfg.devices}.device or "";

  usbLuksKeyScript = pkgs.writeScriptBin "usb-luks-key-wrapper" ''
    #!/bin/sh
    export USB_LUKS_LABEL="${cfg.label}"
    export USB_LUKS_KEY_SUBDIR="${cfg.keyPath}"
    export USB_LUKS_OUTPUT="${cfg.targetPath}"
    export USB_LUKS_TIMEOUT="${toString cfg.timeout}"
    export USB_LUKS_HOSTNAME="${config.networking.hostName}"
    export USB_LUKS_TEST_DEVICE="${testDevice}"
    exec ${pkgs.usb-luks-key-script}/bin/usb-luks-key
  '';
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
      description = "LUKS device names from boot.initrd.luks.devices to unlock with the USB key";
    };

    timeout = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Seconds to wait for USB device to appear";
    };

    keyFileTimeout = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Seconds for initrd to wait for the USB key file before prompting for a passphrase";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.kernelModules = ["usb_storage" "sd_mod" "vfat" "ext4" "f2fs" "exfat"];

    boot.initrd.systemd.extraBin.usb-luks-key = usbLuksKeyScript;

    boot.initrd.systemd.services.usb-luks-key = {
      description = "Load LUKS key from USB";
      wantedBy = ["initrd.target"];
      after = ["systemd-udevd.service" "systemd-modules-load.service"];
      before = map (name: "systemd-cryptsetup@${name}.service") cfg.devices;
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = "${usbLuksKeyScript}/bin/usb-luks-key-wrapper";
    };

    boot.initrd.luks.devices =
      lib.genAttrs cfg.devices (name: {
        keyFile = lib.mkForce cfg.targetPath;
      }
      // lib.optionalAttrs config.boot.initrd.systemd.enable {
        keyFileTimeout = cfg.keyFileTimeout;
      });
  };
}
