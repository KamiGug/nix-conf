{ lib, pkgs, config, ... }:
let
  # Create a udev rules package for the initrd
  usbLuksKeyUdevRules = pkgs.runCommand "usb-luks-key-udev-rules" { } ''
    mkdir -p $out/lib/udev/rules.d
    cat > $out/lib/udev/rules.d/99-usb-luks-key.rules <<'EOF'
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_LABEL}=="${config.usbLuksKey.label}", RUN+="/run/initrd/bin/usb-luks-key"
EOF
  '';

  # Create a wrapper script that sets environment variables
  usbLuksKeyScript = pkgs.writeScriptBin "usb-luks-key-wrapper" ''
    #!/bin/sh
    export USB_LUKS_LABEL="${config.usbLuksKey.label}"
    export USB_LUKS_KEY_SUBDIR="${config.usbLuksKey.keyPath}"
    export USB_LUKS_OUTPUT="${config.usbLuksKey.targetPath}"
    export USB_LUKS_TIMEOUT="${toString config.usbLuksKey.timeout}"
    exec ${pkgs.usb-luks-key-script}/bin/usb-luks-key
  '';
in
{
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
      default = [ ];
      description = "LUKS device names (keys in luksKey.devices) to apply USB key to. Empty = all devices from luksKey.devices.";
    };

    timeout = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Seconds to wait for USB device to appear";
    };
  };

  config = lib.mkIf config.usbLuksKey.enable {
    # Add required kernel modules for USB storage and filesystems
    boot.initrd.kernelModules = lib.mkMerge [
      (config.boot.initrd.kernelModules or [ ])
      [ "usb_storage" "sd_mod" "vfat" "ext4" "f2fs" ]
    ];

    # Install the script and udev rules into systemd initrd
    boot.initrd.systemd.extraBin.usb-luks-key = usbLuksKeyScript;
    boot.initrd.services.udev.packages = lib.mkMerge [
      (config.boot.initrd.services.udev.packages or [ ])
      [ usbLuksKeyUdevRules ]
    ];

    # Add USB key as additional keyFile for selected devices
    boot.initrd.luks.devices = lib.mapAttrs (name: cfg: {
      keyFile = (if lib.hasElement name (if config.usbLuksKey.devices != [ ] then config.usbLuksKey.devices else lib.attrNames config.luksKey.devices) then [ cfg.keyFile ] ++ [ config.usbLuksKey.targetPath ] else [ cfg.keyFile ]);
      device = cfg.device;
      fallbackToPassword = cfg.fallbackToPassword;
    }) (config.boot.initrd.luks.devices or { });
  };
}