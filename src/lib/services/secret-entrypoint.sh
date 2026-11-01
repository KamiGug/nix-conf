#!/usr/bin/env bash
# Export every file under /run/secrets as an environment variable named after
# the file's basename, then hand over to the upstream entrypoint and command.
#
# Secrets are mounted tree-preserving (e.g.
# /run/secrets/services/forgejo/DB_PASSWORD), so the basename is the variable
# name the image expects (DB_PASSWORD). Values never live in the Nix store or in
# the image: they are read here, at container start, from the read-only mount.
set -euo pipefail

if [ -d /run/secrets ]; then
  list="$(mktemp)"
  find /run/secrets -type f -print0 >"$list"
  while IFS= read -r -d '' file; do
    name="$(basename "$file")"
    [ -n "$name" ] || continue
    value="$(cat "$file")"
    export "${name}=${value}"
  done <"$list"
  rm -f "$list"
fi

exec "$@"
