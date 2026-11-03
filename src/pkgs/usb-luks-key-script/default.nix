{
  writeScriptBin,
  cryptsetup,
}:
writeScriptBin "usb-luks-key" ''
  #!/bin/sh
  set -eu

  LABEL="''${USB_LUKS_LABEL:-LUKS-KEY}"
  KEY_SUBDIR="''${USB_LUKS_KEY_SUBDIR-}"
  OUTPUT="''${USB_LUKS_OUTPUT:-/run/keys/usb-luks-key}"
  TIMEOUT="''${USB_LUKS_TIMEOUT:-30}"
  HOSTNAME="''${USB_LUKS_HOSTNAME:-$(cat /etc/hostname 2>/dev/null || hostname 2>/dev/null || echo unknown)}"
  TEST_DEVICE="''${USB_LUKS_TEST_DEVICE:-}"

  DEV="/dev/disk/by-label/''${LABEL}"
  for _ in $(seq 1 "''${TIMEOUT}"); do
    if [ -b "''${DEV}" ]; then
      break
    fi
    sleep 1
  done

  if [ ! -b "''${DEV}" ]; then
    echo "USB device with label ''${LABEL} not found after ''${TIMEOUT}s" >&2
    exit 1
  fi

  MOUNT=$(mktemp -d)
  cleanup() {
    umount "''${MOUNT}" 2>/dev/null || true
    rmdir "''${MOUNT}" 2>/dev/null || true
  }
  trap cleanup EXIT

  mount -o ro "''${DEV}" "''${MOUNT}"

  SEARCH_DIR="''${MOUNT}"
  if [ -n "''${KEY_SUBDIR}" ]; then
    SEARCH_DIR="''${MOUNT}/''${KEY_SUBDIR}"
  fi

  KEY_FILE=""
  for f in "''${HOSTNAME}.key" "key"; do
    if [ -f "''${SEARCH_DIR}/''${f}" ]; then
      KEY_FILE="''${SEARCH_DIR}/''${f}"
      break
    fi
  done

  if [ -z "''${KEY_FILE}" ]; then
    echo "No key file found on USB (looked for ''${HOSTNAME}.key and key in ''${SEARCH_DIR})" >&2
    exit 1
  fi

  if [ -n "''${TEST_DEVICE}" ]; then
    for _ in $(seq 1 "''${TIMEOUT}"); do
      if [ -e "''${TEST_DEVICE}" ]; then
        break
      fi
      sleep 1
    done
    if ! ${cryptsetup}/bin/cryptsetup open --test-passphrase --batch-mode --key-file="''${KEY_FILE}" "''${TEST_DEVICE}" </dev/null 2>/dev/null; then
      echo "USB key does not unlock ''${TEST_DEVICE}" >&2
      exit 1
    fi
  fi

  OUTDIR="''${OUTPUT%/*}"
  if [ -n "''${OUTDIR}" ]; then
    mkdir -p "''${OUTDIR}"
  fi
  cat "''${KEY_FILE}" > "''${OUTPUT}"
  chmod 400 "''${OUTPUT}"
  echo "USB LUKS key (from ''${KEY_FILE}) written to ''${OUTPUT}"
''
