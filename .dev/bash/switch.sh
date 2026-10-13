#!/usr/bin/env bash
set -euo pipefail

MSG="${1:-chore: build step}"
TARGET_INPUT="${2:-""}"

HOSTNAME=${HOSTNAME:-$(hostname)}
USER_NAME=${USER:-$(whoami)}
TRACE=${TRACE:-"true"}
ADD_ALL=${ADD_ALL:-"true"}

if [[ -n "${HELP:-}" ]]; then
  cat <<'EOF'
Usage: switch.sh [MESSAGE] [TARGET]

Rebuild and switch the current NixOS/Darwin/nix-on-droid/home-manager config.

Arguments:
  MESSAGE   Commit message (default: "chore: build step")
  TARGET    One of: nixos | darwin | droid | home
            (default: auto-detected)

Environment variables:
  TRACE         Set to "true" to run the dry-run with --show-trace (default: true)
  ADD_ALL       Set to "false" to skip staging everything (git add . / git add -A)
  ALLOW_BROKEN  Set to "1" to skip rolling back when the niri config fails to validate
  HELP          Set to any non-empty value to print this help and exit

Examples:
  switch.sh "feat: add thing" nixos
  ADD_ALL=false switch.sh
EOF
  exit 0
fi

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
      DRY_RUN_CMD=(darwin-rebuild check --show-trace --flake ".#${HOSTNAME}")
    else
      DRY_RUN_CMD=(darwin-rebuild check --flake ".#${HOSTNAME}")
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

if [[ "$ADD_ALL" == 'true' ]]; then
  git add .
fi
if ! "${DRY_RUN_CMD[@]}"; then
  echo "→ Failed to evaluate the configuration"
  exit 1
fi

echo "→ Checking flake attr: $ATTR_PATH"

if ! nix eval ".#${ATTR_PATH}" >/dev/null 2>&1; then
  echo "Missing flake output:"
  echo "   .#${ATTR_PATH}"
  echo ""
  echo "→ Try:"
  echo "   task build:switch TARGET=<nixos|darwin|droid|home>"
  exit 1
fi

echo "→ Running switch"
"${SWITCH_CMD[@]}"

# --- validate niri config, roll back generations until it's valid ---
if command -v niri >/dev/null 2>&1; then
  RED_BOLD=$'\033[1;31m'
  RESET=$'\033[0m'

  current_generation() {
    case "$TARGET" in
      nixos) nixos-rebuild list-generations | awk '$NF == "True" {print $1, $2, $3; exit}' ;;
      darwin) darwin-rebuild --list-generations | grep -F current | sed 's/^[[:space:]]*//' ;;
      droid) nix-on-droid generations | grep -F current | sed 's/^[[:space:]]*//' || true ;;
      home) home-manager generations | head -n1 | sed -E 's/.*id ([0-9]+).*/\1/' || true ;;
    esac
  }

  rollback_generation() {
    case "$TARGET" in
      nixos) sudo nixos-rebuild switch --rollback ;;
      darwin) darwin-rebuild switch --rollback ;;
      droid) nix-on-droid switch --rollback ;;
      home) home-manager switch --rollback ;;
      *)
        echo "${RED_BOLD}!!! No rollback for target: $TARGET${RESET}" >&2
        return 1
        ;;
    esac
  }

  # Resolve the niri config that generation $1 SHIPS (from its store path),
  # not whatever is currently symlinked into $HOME (which activation may lag).
  config_for_generation() {
    local g="$1" sys hm hf
    case "$TARGET" in
      nixos)
        sys="/nix/var/nix/profiles/system-${g}-link"
        hm=$(grep -oE '/nix/store/[a-z0-9]+-home-manager-generation' "$sys"/etc/systemd/system/home-manager-*.service 2>/dev/null | head -1 | cut -d: -f2)
        [[ -n "$hm" ]] && hf=$(readlink -f "$hm/home-files" 2>/dev/null)
        [[ -n "$hf" ]] && echo "$hf/.config/niri/config.kdl"
        ;;
      home | darwin)
        hmgen="/nix/var/nix/profiles/per-user/${USER_NAME}/home-manager-generation-${g}-link"
        [[ -e "$hmgen" ]] && hf=$(readlink -f "$hmgen/home-files" 2>/dev/null)
        [[ -n "$hf" ]] && echo "$hf/.config/niri/config.kdl"
        ;;
    esac
  }

  if ! niri validate >/dev/null 2>&1; then
    if [[ "${ALLOW_BROKEN:-}" == "1" ]]; then
      echo "${RED_BOLD}!!! NIRI config is invalid, but ALLOW_BROKEN=1, continuing${RESET}"
    else
      echo "${RED_BOLD}!!! NIRI config did not validate, searching for the newest generation with a valid config${RESET}"
      CURRENT_GEN=$(current_generation | awk '{print $1}')
      ROLLBACK_TARGET=""
      RESOLVED_ANY=false
      CANDIDATE=$CURRENT_GEN
      while [[ "$CANDIDATE" -ge 0 && -z "$ROLLBACK_TARGET" ]]; do
        CFG=$(config_for_generation "$CANDIDATE")
        if [[ -n "$CFG" ]]; then
          RESOLVED_ANY=true
          if [[ -f "$CFG" ]] && niri validate -c "$CFG" >/dev/null 2>&1; then
            ROLLBACK_TARGET="$CANDIDATE"
          fi
        fi
        CANDIDATE=$((CANDIDATE - 1))
      done

      if [[ -z "$ROLLBACK_TARGET" ]]; then
        if [[ "$RESOLVED_ANY" != true ]]; then
          echo "${RED_BOLD}!!! Could not inspect prior generations for their niri config; doing stepwise rollback${RESET}"
          while ! niri validate >/dev/null 2>&1; do
            PREV=$(current_generation)
            echo "${RED_BOLD}!!! Rolling back from: ${PREV:-?}${RESET}"
            rollback_generation
            NEW=$(current_generation)
            echo "${RED_BOLD}!!! Rolled back to: ${NEW:-?}${RESET}"
            if [[ "$NEW" == "$PREV" ]]; then
              echo "${RED_BOLD}!!! No valid niri config found, abandoning switch${RESET}" >&2
              exit 1
            fi
          done
          LAST_GENERATION_NUMBER=$(current_generation | awk '{print $1}')
          echo "${RED_BOLD}!!! Rolled back to a valid niri config: ${LAST_GENERATION_NUMBER}${RESET}"
        else
          echo "${RED_BOLD}!!! No generation with a valid niri config found, abandoning switch${RESET}" >&2
          exit 1
        fi
      else
        echo "${RED_BOLD}!!! Rolling back to generation ${ROLLBACK_TARGET} (niri config is valid there)${RESET}"
        STEPS=$((CURRENT_GEN - ROLLBACK_TARGET))
        while [[ "$(current_generation | awk '{print $1}')" != "$ROLLBACK_TARGET" ]]; do
          if [[ "$STEPS" -le 0 ]]; then
            echo "${RED_BOLD}!!! Rollback did not reach generation ${ROLLBACK_TARGET}, abandoning switch${RESET}" >&2
            exit 1
          fi
          rollback_generation
          STEPS=$((STEPS - 1))
        done
        if command -v systemctl >/dev/null 2>&1; then
          HM_SERVICE=$(systemctl list-unit-files --no-legend 2>/dev/null | awk '/^home-manager-.*\.service/ {print $1}' | head -1)
          if [[ -n "$HM_SERVICE" ]]; then
            echo "${RED_BOLD}!!! Restarting $HM_SERVICE to apply the rolled-back home files${RESET}"
            sudo systemctl restart "$HM_SERVICE" || true
          fi
        fi
        LAST_GENERATION_NUMBER="$ROLLBACK_TARGET"
        echo "${RED_BOLD}!!! Rolled back to generation ${ROLLBACK_TARGET} with a valid niri config${RESET}"
      fi
    fi
  fi
fi

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
  if git log --oneline --all --grep="${HOSTNAME}:${LAST_GENERATION_NUMBER}" --fixed-strings | grep -q .; then
    HAS_COMMIT=true
  fi
fi

if [[ "$HAS_CHANGES" == true || "$HAS_COMMIT" == false ]]; then
  echo "→ Committing changes"
  if [[ "$ADD_ALL" == 'true' ]]; then
    git add -A
  fi
  git commit --allow-empty -m "${MSG}
  ${HOSTNAME}:${LAST_GENERATION_NUMBER}"
else
  echo "→ No changes to commit"
fi

echo "Starting one off services"

if [[ "$TARGET" == "nixos" ]]; then
  for SERVICE in $(systemctl list-unit-files | grep -E 'EnsureDir|GenerateRandomSecret' | cut -d ' ' -f1); do
    systemctl restart "${SERVICE}"
  done
fi
