#!/usr/bin/env bash
set -euo pipefail

MSG="${1:-chore: switch}"
TARGET_INPUT="${2:-""}"

HOSTNAME=$(hostname)
USER_NAME=$(whoami)

# --- detect target ---
if [[ -n "$TARGET_INPUT" ]]; then
  TARGET="$TARGET_INPUT"
elif [[ -d /etc/nixos ]]; then
  TARGET="nixos"
elif [[ "$(uname)" == "Darwin" ]]; then
  TARGET="darwin"
elif [[ -d /data/data/com.termux.nix ]]; then
  TARGET="droid"
else
  TARGET="home"
fi

echo "→ Target: $TARGET"
echo "→ Host: $HOSTNAME"
echo "→ User: $USER_NAME"

# --- branch enforcement ---
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" != dev* ]]; then
  NEW_BRANCH="dev-$HOSTNAME"
  echo "→ Switching to $NEW_BRANCH"
  git checkout -B "$NEW_BRANCH"
fi

# --- commit ---
git add -A
git commit -m "$MSG" || echo "→ nothing to commit"

# --- resolve attr path ---
case "$TARGET" in
  nixos)
    ATTR_PATH="nixosConfigurations.${HOSTNAME}.config.system.build.toplevel"
    SWITCH_CMD=(sudo nixos-rebuild switch --flake ".#${HOSTNAME}")
    ;;
  darwin)
    ATTR_PATH="darwinConfigurations.${HOSTNAME}.system"
    SWITCH_CMD=(darwin-rebuild switch --flake ".#${HOSTNAME}")
    ;;
  droid)
    ATTR_PATH="nixOnDroidConfigurations.${HOSTNAME}.config.system.build.toplevel"
    SWITCH_CMD=(nix-on-droid switch --flake ".#${HOSTNAME}")
    ;;
  home)
    ATTR="${USER_NAME}@${HOSTNAME}"
    ATTR_PATH="homeConfigurations.\"${ATTR}\".activationPackage"
    SWITCH_CMD=(home-manager switch --flake ".#${ATTR}")
    ;;
  *)
    echo "Unknown target: $TARGET"
    exit 1
    ;;
esac

echo "→ Checking flake attr: $ATTR_PATH"

if ! nix eval ".#${ATTR_PATH}" >/dev/null 2>&1; then
  echo "Missing flake output:"
  echo "   .#${ATTR_PATH}"
  echo ""
  echo "→ Try:"
  echo "   task switch TARGET=<nixos|darwin|droid|home>"
  exit 1
fi

echo "→ Running switch"
"${SWITCH_CMD[@]}"
