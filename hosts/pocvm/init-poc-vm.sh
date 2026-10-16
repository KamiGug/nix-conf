#!/usr/bin/env bash
set -euo pipefail

# Initialise the `pocvm` sops POC (see hosts/pocvm/default.nix). It re-executes
# itself inside `nix develop .`, so sops, age-keygen, openssl and task are all
# guaranteed to be on PATH.

HOST=pocvm
SECRET_NAME=pocuser-password
SECRET_FILE=hosts/pocvm/passwords.yml
AGE_KEY=/etc/sops/age.key
STAGE=(
  flake.nix
  users/default.nix
  users/pocuser.nix
  hosts/pocvm/default.nix
  hosts/pocvm/init-poc-vm.sh
  .dev/taskfiles/taskfile.build.yml
)

usage() {
  cat <<'EOF'
Initialise the `pocvm` sops POC (see hosts/pocvm/default.nix):

  1. create hosts/pocvm/passwords.yml holding the encrypted password for
     `pocuser` (skipped when the file already exists unless --force is given)
  2. stage the POC files so the flake (`git+file://`) can actually see them
  3. build the VM and print the command to run it

The script re-executes itself inside `nix develop .`.

Usage:
  hosts/pocvm/init-poc-vm.sh [--force] [--no-build]

Options:
  --force      re-encrypt passwords.yml even if it already exists
  --no-build   stop after staging/encrypting (skip `task build:vm:pocvm`)
  -h, --help   show this help

Environment:
  POC_PASSWORD    password for pocuser (prompted for twice when unset)
  POCVM_NO_SHELL  set to 1 to skip entering the dev shell
EOF
}

FORCE=false
BUILD=true
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --no-build) BUILD=false ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

SCRIPT=$(readlink -f -- "$0")
REPO_ROOT=$(cd -- "$(dirname -- "$SCRIPT")/../.." && pwd)
cd "$REPO_ROOT"

# --- run inside the flake dev shell -----------------------------------------
if [[ -z "${POCVM_IN_SHELL:-}" && "${POCVM_NO_SHELL:-}" != 1 ]]; then
  if ! command -v nix >/dev/null 2>&1; then
    echo "error: 'nix' not found in PATH (set POCVM_NO_SHELL=1 to skip the dev shell)" >&2
    exit 1
  fi
  export POCVM_IN_SHELL=1
  echo "→ entering 'nix develop .' (set POCVM_NO_SHELL=1 to skip)"
  exec nix develop . --command "$SCRIPT" "$@"
fi

if [[ ! -f flake.nix ]]; then
  echo "error: flake.nix not found in $REPO_ROOT" >&2
  exit 1
fi

if [[ ! -f "$AGE_KEY" ]]; then
  echo "error: age key not found: $AGE_KEY" >&2
  exit 1
fi

# --- 1. encrypt the password ------------------------------------------------
SKIP_ENCRYPT=false
if [[ -f "$SECRET_FILE" ]]; then
  if [[ "$FORCE" == true ]]; then
    echo "→ $SECRET_FILE exists, re-encrypting (--force)"
  else
    echo "→ $SECRET_FILE already exists, keeping it (pass --force to re-encrypt)"
    SKIP_ENCRYPT=true
  fi
fi

if [[ "$SKIP_ENCRYPT" != true ]]; then
  for tool in sops age-keygen openssl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "error: '$tool' not found in PATH" >&2
      exit 1
    fi
  done

  PASSWORD="${POC_PASSWORD:-}"
  if [[ -z "$PASSWORD" ]]; then
    IFS= read -rs -p 'pocuser password: ' PASSWORD || true
    echo
    IFS= read -rs -p 'confirm password: ' CONFIRM || true
    echo
    if [[ "$PASSWORD" != "$CONFIRM" ]]; then
      echo "error: passwords do not match" >&2
      exit 1
    fi
  fi
  if [[ -z "$PASSWORD" ]]; then
    echo "error: empty password" >&2
    exit 1
  fi

  HASH=$(openssl passwd -6 "$PASSWORD")
  unset PASSWORD CONFIRM

  RECIPIENT=$(age-keygen -y "$AGE_KEY")

  TMP_PLAIN=$(mktemp)
  TMP_ENC=$(mktemp)
  trap 'rm -f "$TMP_PLAIN" "$TMP_ENC"' EXIT

  umask 077
  printf "%s: '%s'\n" "$SECRET_NAME" "$HASH" >"$TMP_PLAIN"
  unset HASH

  sops --encrypt --age "$RECIPIENT" --input-type yaml --output-type yaml \
    "$TMP_PLAIN" >"$TMP_ENC"
  mv -- "$TMP_ENC" "$SECRET_FILE"
  echo "→ wrote $SECRET_FILE"
fi

# --- 2. stage the files -----------------------------------------------------
STAGE+=("$SECRET_FILE")
stage() {
  if git add -- "${STAGE[@]}" 2>/dev/null; then
    return 0
  fi
  echo "→ git add failed, retrying with sudo (the git index here is root-owned)"
  sudo git add -- "${STAGE[@]}"
}

if ! stage; then
  echo "error: could not stage the POC files; stage them manually and re-run:" >&2
  printf '  sudo git add -- %s\n' "${STAGE[*]}" >&2
  exit 1
fi
echo "→ staged ${#STAGE[@]} paths"

# --- 3. build ---------------------------------------------------------------
if [[ "$BUILD" == true ]]; then
  if ! command -v task >/dev/null 2>&1; then
    echo "error: 'task' not found in PATH" >&2
    exit 1
  fi

  task "build:vm:$HOST"

  RUN=$(find -L "result-vm-$HOST/bin" -name 'run-*-vm' -print -quit)
  echo
  echo "→ run the VM with:"
  echo "  $RUN"
  echo "→ log in as user: pocuser"
else
  echo
  echo "→ next: task build:vm:$HOST"
fi
