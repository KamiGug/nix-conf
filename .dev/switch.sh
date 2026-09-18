#!/usr/bin/env bash
set -euo pipefail

MSG="${1:-chore: build step}"
TARGET_INPUT="${2:-""}"

HOSTNAME=${HOSTNAME:-$(hostname)}
USER_NAME=${USER:-$(whoami)}
TRACE=${TRACE:-"true"}

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

HAS_CHANGES=false
if ! git diff --quiet || ! git diff --cached --quiet; then
  HAS_CHANGES=true
fi

case "$TARGET" in
  nixos)
    ATTR_PATH="nixosConfigurations.${HOSTNAME}.config.system.build.toplevel"
    SWITCH_CMD=(sudo nixos-rebuild switch --flake ".#${HOSTNAME}")
    LAST_GENERATION_NUMBER=$(nixos-rebuild list-generations | head -n2 | tail -n1 | cut -d ' ' -f1)
    if [[ "$TRACE" == 'true' ]]; then
        DRY_RUN_CMD=(nixos-rebuild dry-run --show-trace --flake ".#${HOSTNAME}")
    else
        DRY_RUN_CMD=(nixos-rebuild dry-run --flake ".#${HOSTNAME}")
    fi
    ;;
  darwin)
    ATTR_PATH="darwinConfigurations.${HOSTNAME}.system"
    SWITCH_CMD=(darwin-rebuild switch --flake ".#${HOSTNAME}")
    LAST_GENERATION_NUMBER=$(darwin-rebuild --list-generations | grep current | sed 's/^[[:space:]]*//' | cut -d ' ' -f 1)
    if [[ "$TRACE" == 'true' ]]; then
        DRY_RUN_CMD=(darwin-rebuild dry-run --show-trace --flake ".#${HOSTNAME}")
    else
        DRY_RUN_CMD=(darwin-rebuild dry-run --flake ".#${HOSTNAME}")
    fi
    ;;
  droid)
    ATTR_PATH="nixOnDroidConfigurations.${HOSTNAME}.config.system.build.toplevel"
    SWITCH_CMD=(nix-on-droid switch --flake ".#${HOSTNAME}")
    # NOTE: NOT CHECKED
    LAST_GENERATION_NUMBER=$(nix-on-droid generations | grep current | sed 's/^[[:space:]]*//' | cut -d ' ' -f1)
    if [[ "$TRACE" == 'true' ]]; then
        DRY_RUN_CMD=(nix-on-droid dry-run --show-trace --flake ".#${HOSTNAME}")
    else
        DRY_RUN_CMD=(nix-on-droid dry-run --flake ".#${HOSTNAME}")
    fi
    ;;
  home)
    ATTR="${USER_NAME}@${HOSTNAME}"
    ATTR_PATH="homeConfigurations.\"${ATTR}\".activationPackage"
    SWITCH_CMD=(home-manager switch --flake ".#${ATTR}")
    # NOTE: NOT CHECKED!
    LAST_GENERATION_NUMBER=$(home-manager generations | head -n1 | sed -E 's/.*id ([0-9]+).*/\1/')
    if [[ "$TRACE" == 'true' ]]; then
        DRY_RUN_CMD=(home-manager dry-run --show-trace --flake ".#${ATTR}")
    else
        DRY_RUN_CMD=(home-manager dry-run --flake ".#${ATTR}")
    fi
    ;;
  *)
    echo "Unknown target: $TARGET"
    exit 1
    ;;
esac

if ! "${DRY_RUN_CMD[@]}"; then
    echo  "→ Failed to evaluate the configuration"
    exit 1
fi

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
HAS_COMMIT=false
# TODO: move commiting here

# TODO: use to get generation number -
#
if [[ "$HAS_CHANGES" == true ]]; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  TARGET_BRANCH="dev-${HOSTNAME}"

  # if [[ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]]; then
  if [[ "$CURRENT_BRANCH" != dev-* ]]; then
    echo "→ Changes detected on non-dev branch: $CURRENT_BRANCH"

    # check if host exists in flake
    if nix eval ".#${ATTR_PATH}" >/dev/null 2>&1; then
      echo "→ Switching to $TARGET_BRANCH"
      git checkout -B "$TARGET_BRANCH"
    else
      echo "→ Host not defined in flake, staying on $CURRENT_BRANCH"
    fi
  fi

else
  if [[ $(git log --all --grep="${HOSTNAME}:${LAST_GENERATION_NUMBER}" --fixed-strings --quiet | grep -E '^commit' | wc -l) -gt 0 ]]; then
      HAS_COMMIT=true
  fi
fi



if [[ "$HAS_CHANGES" == true || "$HAS_COMMIT" == false ]]; then
  echo "→ Committing changes"
  git add -A
  git commit -m "${MSG}
  ${HOSTNAME}:${LAST_GENERATION_NUMBER}"
else
  echo "→ No changes to commit"
fi

echo "Starting one off services"

if [[ "$TARGET" == "nixos" ]]; then
    for SERVICE in $(systemctl list-unit-files | grep -E 'EnsureDir|GenerateRandomSecret' | cut -d ' ' -f1); do
        systemctl restart ${SERVICE}
    done
fi
