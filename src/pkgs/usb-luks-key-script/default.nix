{writeScriptBin}:
writeScriptBin "usb-luks-key" ''
  #!/bin/sh
  set -eu

  LABEL="''${USB_LUKS_LABEL:-LUKS-KEY}"
  KEY_SUBDIR="''${USB_LUKS_KEY_SUBDIR-}"
  OUTPUT="''${USB_LUKS_OUTPUT:-/run/keys/usb-luks-key}"
  TIMEOUT="''${USB_LUKS_TIMEOUT:-30}"

  # Get hostname from /etc/hostname or fallback
  HOSTNAME=$(cat /etc/hostname 2>/dev/null || hostname 2>/dev/null || echo "unknown")

  # Wait for device to appear
  for i in $(seq 1 "''${TIMEOUT}"); do
    if [ -b "/dev/disk/by-label/''${LABEL}" ]; then
      break
    fi
    sleep 1
  done

  DEV="/dev/disk/by-label/''${LABEL}"
  if [ ! -b "''${DEV}" ]; then
    echo "USB device with label ''${LABEL} not found after ''${TIMEOUT}s" >&2
    exit 1
  fi

  MOUNT=$(mktemp -d)
  mount -o ro "''${DEV}" "''${MOUNT}"

  # If KEY_SUBDIR is set, look there
  SEARCH_DIR="''${MOUNT}"
  [ -n "''${KEY_SUBDIR}" ] && SEARCH_DIR="''${MOUNT}/''${KEY_SUBDIR}"

  # Try host-specific key first, then generic
  KEY_FILE=""
  for f in "''${HOSTNAME}.key" "key"; do
    if [ -f "''${SEARCH_DIR}/''${f}" ]; then
      KEY_FILE="''${SEARCH_DIR}/''${f}"
      break
    fi
  done

  if [ -z "''${KEY_FILE}" ]; then
    echo "No key file found on USB (looked for ''${HOSTNAME}.key and key in ''${SEARCH_DIR})" >&2
    umount "''${MOUNT}"
    rmdir "''${MOUNT}"
    exit 1
  fi

  # Copy key (max 512 bytes for LUKS)
  dd if="''${KEY_FILE}" of="''${OUTPUT}" bs=1 count=512 2>/dev/null
  umount "''${MOUNT}"
  rmdir "''${MOUNT}"

  chmod 400 "''${OUTPUT}"
  echo "USB LUKS key (from ''${KEY_FILE}) written to ''${OUTPUT}"
''
