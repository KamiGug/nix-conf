{
  writeShellApplication,
  coreutils,
  gnused,
  gnugrep,
  nixos-install-tools,
  nix-conf-clone,
}:
writeShellApplication {
  name = "nix-conf-install";

  runtimeInputs = [
    coreutils
    gnused
    gnugrep
    nixos-install-tools
    nix-conf-clone
  ];

  text = ''
    HOST=""
    MOUNT="/mnt"
    EXISTING=false
    GUI=true

    usage() {
      cat <<'EOF'
    Usage: nix-conf-install <hostname> [--mount /mnt] [--existing-host] [--no-gui]

    Generates a fresh hardware-configuration.nix for the target mounted at
    <mount>, clones the nix-conf repo into <mount>/etc/nixos, injects the
    generated hardware config into hosts/<hostname>/, and runs nixos-install.
    EOF
    }

    while [ $# -gt 0 ]; do
      case "$1" in
        --mount)
          MOUNT="$2"
          shift 2
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
          echo "nix-conf-install: unknown option $1" >&2
          usage >&2
          exit 1
          ;;
        *)
          HOST="$1"
          shift
          ;;
      esac
    done

    if [ -z "$HOST" ]; then
      echo "nix-conf-install: hostname is required" >&2
      usage >&2
      exit 1
    fi

    if [ ! -d "$MOUNT/etc" ]; then
      echo "nix-conf-install: $MOUNT does not look like a mounted root" >&2
      exit 1
    fi

    echo "nix-conf-install: generating hardware configuration for $MOUNT"
    nixos-generate-config --root "$MOUNT"

    HW=$(mktemp)
    cp "$MOUNT/etc/nixos/hardware-configuration.nix" "$HW"

    # Drop the placeholder configuration.nix so the clone target is empty.
    rm -rf "$MOUNT/etc/nixos"

    echo "nix-conf-install: cloning repo into $MOUNT/etc/nixos"
    nix-conf-clone "$MOUNT/etc/nixos"

    HOSTDIR="$MOUNT/etc/nixos/hosts/$HOST"
    mkdir -p "$HOSTDIR"
    install -m 644 "$HW" "$HOSTDIR/hardware-configuration.nix"

    if [ ! -f "$HOSTDIR/default.nix" ]; then
      echo "nix-conf-install: creating hosts/$HOST/default.nix"
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

    if [ "$EXISTING" = false ]; then
      if grep -qE "(^|[[:space:]])$HOST[[:space:]]*=" "$MOUNT/etc/nixos/flake.nix"; then
        echo "nix-conf-install: $HOST already present in flake.nix"
      else
        echo "nix-conf-install: adding $HOST to flake.nix nixosHosts"
        sed -i "s/^\([[:space:]]*\)nixosHosts = {/\1nixosHosts = {\n\1  $HOST = {gui = $GUI;};/" "$MOUNT/etc/nixos/flake.nix"
      fi
    fi

    echo "nix-conf-install: installing $HOST"
    nixos-install --root "$MOUNT" --flake "path:$MOUNT/etc/nixos#$HOST"
  '';
}
