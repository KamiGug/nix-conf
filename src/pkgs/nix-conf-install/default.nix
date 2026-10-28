{
  writeShellApplication,
  coreutils,
  nixos-install-tools,
  nix-conf-clone,
  disko,
}:
writeShellApplication {
  name = "nix-conf-install";

  runtimeInputs = [
    coreutils
    nixos-install-tools
    nix-conf-clone
    disko
  ];

  text = ''
    HOST=""
    MOUNT="/mnt/disko-install-root"
    EXISTING=false
    GUI=true
    WRITE_EFI=false
    DISK_ARGS=()

    usage() {
      cat <<'EOF'
    Usage: nix-conf-install <hostname> [OPTIONS]

    Clones nix-conf, creates src/hosts/linux/<hostname>/, generates a
    hardware-configuration.nix without fileSystems, and installs the host with
    disko-install.

    Options:
      --disk NAME DEVICE          Map a disko disk name to a block device.
                                  Repeat for every disk. Examples:
                                    --disk main /dev/nvme0n1
                                    --disk tank_0 /dev/sda --disk tank_1 /dev/sdb
      --mount-point PATH          Mount point used by disko-install.
                                  Default: /mnt/disko-install-root
      --mount PATH                Alias for --mount-point.
      --write-efi-boot-entries    Write EFI boot entries to NVRAM.
      --existing-host             Do not create default.nix/host.nix; the host
                                  must already exist in the cloned repo.
      --no-gui                    Create the host with gui = false.
      -h, --help                  Show this help.
    EOF
    }

    die() {
      echo "nix-conf-install: $*" >&2
      exit 1
    }

    while [ $# -gt 0 ]; do
      case "$1" in
        --disk)
          [ $# -ge 3 ] || die "--disk requires NAME and DEVICE"
          DISK_ARGS+=(--disk "$2" "$3")
          shift 3
          ;;
        --mount-point|--mount)
          [ $# -ge 2 ] || die "$1 requires a path"
          MOUNT="$2"
          shift 2
          ;;
        --write-efi-boot-entries)
          WRITE_EFI=true
          shift
          ;;
        --existing-host)
          EXISTING=true
          shift
          ;;
        --no-gui)
          GUI=false
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        -*)
          usage >&2
          die "unknown option $1"
          ;;
        *)
          [ -z "$HOST" ] || die "only one hostname may be given"
          HOST="$1"
          shift
          ;;
      esac
    done

    [ -n "$HOST" ] || {
      usage >&2
      die "hostname is required"
    }

    [ "$EUID" -eq 0 ] || die "must be run as root"

    WORK="$(mktemp -d)"
    STAGE="$WORK/nix-conf"
    HW="$WORK/hw"
    trap 'rm -rf "$WORK"' EXIT

    echo "nix-conf-install: generating hardware configuration"
    nixos-generate-config --dir "$HW" --no-filesystems >/dev/null

    echo "nix-conf-install: cloning nix-conf into $STAGE"
    nix-conf-clone "$STAGE"

    [ -d "$STAGE/src/hosts/linux" ] \
      || die "cloned repo has no src/hosts/linux directory"

    HOSTDIR="$STAGE/src/hosts/linux/$HOST"

    if [ "$EXISTING" = true ]; then
      [ -f "$HOSTDIR/default.nix" ] \
        || die "--existing-host given but $HOST does not exist in the repo"
    else
      mkdir -p "$HOSTDIR"

      if [ ! -f "$HOSTDIR/default.nix" ]; then
        echo "nix-conf-install: creating hosts/linux/$HOST/default.nix"
        cat > "$HOSTDIR/default.nix" <<EOF
    {
      lib,
      ...
    }: {
      imports = [ ./hardware-configuration.nix ];

      networking.hostName = "$HOST";

      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      nixpkgs.config.allowUnfree = true;
      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    }
    EOF
      fi

      if [ ! -f "$HOSTDIR/host.nix" ]; then
        echo "nix-conf-install: creating hosts/linux/$HOST/host.nix"
        cat > "$HOSTDIR/host.nix" <<EOF
    {...}: {
      gui = $GUI;
    }
    EOF
      fi
    fi

    install -m 644 "$HW/hardware-configuration.nix" \
      "$HOSTDIR/hardware-configuration.nix"

    echo "nix-conf-install: installing $HOST with disko-install"
    args=(
      --flake "path:$STAGE#$HOST"
      --mount-point "$MOUNT"
      --extra-files "$STAGE" /etc/nixos
    )

    if [ "$WRITE_EFI" = true ]; then
      args+=(--write-efi-boot-entries)
    fi

    args+=("''${DISK_ARGS[@]}")
    disko-install "''${args[@]}"

    echo "nix-conf-install: $HOST installed"
    echo "nix-conf-install: remove the installer media and reboot"
  '';
}
