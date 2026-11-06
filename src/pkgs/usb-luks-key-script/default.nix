{
  writeScriptBin,
  cryptsetup,
}:
writeScriptBin "usb-luks-key" ''
  #!/bin/sh
  set -u

  LABEL="''${USB_LUKS_LABEL:-LUKS-KEY}"
  KEY_SUBDIR="''${USB_LUKS_KEY_SUBDIR-}"
  OUTPUT="''${USB_LUKS_OUTPUT:-/run/keys/usb-luks-key}"
  TIMEOUT="''${USB_LUKS_TIMEOUT:-30}"
  HOSTNAME="''${USB_LUKS_HOSTNAME:-$(cat /etc/hostname 2>/dev/null || hostname 2>/dev/null || echo unknown)}"
  TEST_DEVICE="''${USB_LUKS_TEST_DEVICE:-}"

  log() {
    echo "usb-luks-key: ''$*" >&2
  }

  # A missing or unusable USB key is not fatal: systemd-cryptsetup will fall
  # back to an interactive passphrase prompt. Exiting successfully keeps early
  # boot moving instead of failing the whole initrd.
  fallback() {
    log "''$*"
    log "no USB key loaded; falling back to passphrase prompt"
    exit 0
  }

  wait_for() {
    _path="''$1"
    _i=0
    while [ "''${_i}" -lt "''${TIMEOUT}" ]; do
      if [ -e "''${_path}" ]; then
        return 0
      fi
      sleep 1
      _i=''$((_i + 1))
    done
    [ -e "''${_path}" ]
  }

  DEV="/dev/disk/by-label/''${LABEL}"
  if ! wait_for "''${DEV}"; then
    fallback "no USB device labelled 'LUKS-KEY' detected; falling back to passphrase prompt"
  fi

  MOUNT="$(mktemp -d)"
  cleanup() {
    umount "''${MOUNT}" 2>/dev/null || true
    rmdir "''${MOUNT}" 2>/dev/null || true
  }
  trap cleanup EXIT INT TERM

  if ! mount -o ro "''${DEV}" "''${MOUNT}"; then
    fallback "could not mount ''${DEV}"
  fi

  SEARCH_DIR="''${MOUNT}"
  if [ -n "''${KEY_SUBDIR}" ]; then
    SEARCH_DIR="''${MOUNT}/''${KEY_SUBDIR}"
  fi

  KEY_FILE=""
  for candidate in "''${HOSTNAME}.key" "key"; do
    if [ -f "''${SEARCH_DIR}/''${candidate}" ]; then
      KEY_FILE="''${SEARCH_DIR}/''${candidate}"
      break
    fi
  done

  if [ -z "''${KEY_FILE}" ]; then
    fallback "no key file (''${HOSTNAME}.key or key) found in ''${SEARCH_DIR}"
  fi

  if [ -n "''${TEST_DEVICE}" ]; then
    if ! wait_for "''${TEST_DEVICE}"; then
      log "LUKS device ''${TEST_DEVICE} did not appear; using key without validation"
    elif ! ${cryptsetup}/bin/cryptsetup open --test-passphrase --batch-mode --key-file="''${KEY_FILE}" "''${TEST_DEVICE}" </dev/null 2>/dev/null; then
      fallback "key ''${KEY_FILE} does not unlock ''${TEST_DEVICE}"
    fi
  fi

  OUTDIR="''${OUTPUT%/*}"
  if [ -n "''${OUTDIR}" ]; then
    mkdir -p "''${OUTDIR}"
  fi
  cp "''${KEY_FILE}" "''${OUTPUT}"
  chmod 0400 "''${OUTPUT}"
  log "loaded LUKS key from ''${KEY_FILE}"
''
