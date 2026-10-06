#!/usr/bin/env bash
# Validates the docker-services environment and the generated output.
# Called by `task validate`; expects environment.yml to already be rendered
# into result/ and uses only tools that are already required by the Taskfile.
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$SELF_DIR/environment.yml"
RESULT_DIR="$SELF_DIR/result"
SERVICES_DIR="$RESULT_DIR/services"

FAIL=0
WARN=0

fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
warn() { printf '  \033[33mWARN\033[0m %s\n' "$1"; WARN=$((WARN + 1)); }
ok() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
head1() { printf '\n\033[1m%s\033[0m\n' "$1"; }

for BIN in yq jinja2 python3; do
  command -v "$BIN" > /dev/null 2>&1 || { echo "missing required tool: $BIN" >&2; exit 1; }
done

CONTAINER_BIN=""
for BIN in podman docker; do
  if command -v "$BIN" > /dev/null 2>&1; then CONTAINER_BIN="$BIN"; break; fi
done

head1 "environment.yml"
yq -e '.' "$ENV_FILE" > /dev/null || fail "environment.yml is not valid YAML"

# Duplicate keys silently take the last value, so they are always a mistake.
python3 - "$ENV_FILE" <<'PY'
import sys, yaml
class Strict(yaml.SafeLoader):
    pass
def nodup(loader, node, deep=False):
    seen = []
    for key, _ in node.value:
        name = loader.construct_object(key, deep=deep)
        if name in seen:
            print(f"DUPLICATE\t{name}\tline {key.start_mark.line + 1}")
        seen.append(name)
    return yaml.SafeLoader.construct_mapping(loader, node, deep)
Strict.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, nodup)
try:
    yaml.load(open(sys.argv[1]), Loader=Strict)
except yaml.YAMLError as exc:
    print(f"PARSE\t{exc}")
PY

# Version numbers must stay strings: an unquoted 18 is an int (breaks
# postgres.yml.jinja) and an unquoted 1.30 renders as 1.3.
for svc in $(yq -r '.services | keys | .[]' "$ENV_FILE" 2>/dev/null || true); do
  TAG_TYPE="$(yq -r ".services.$svc.tag | type" "$ENV_FILE" 2>/dev/null || echo "null")"
  if [ "$TAG_TYPE" = "object" ]; then
    for part in $(yq -r ".services.$svc.tag | keys | .[]" "$ENV_FILE"); do
      yq -e ".services.$svc.tag.$part | type == \"string\"" "$ENV_FILE" > /dev/null ||
        fail "$svc.tag.$part must be a quoted string"
    done
    continue
  fi
  TAG="$(yq -r ".services.$svc.tag" "$ENV_FILE")"
  case "$TAG_TYPE" in
    string)
      ;;
    number)
      # 16 renders as 16, but 1.30 renders as 1.3 and pulls the wrong image.
      if [ "$(yq -r ".services.$svc.tag | floor == ." "$ENV_FILE")" = "true" ]; then
        warn "$svc.tag should be a quoted string (got $TAG)"
      else
        fail "$svc.tag is an unquoted decimal ($TAG): it would render truncated, e.g. 1.30 -> 1.3. Quote it."
      fi
      ;;
    *)
      if [ "$svc" = "postgres" ]; then
        fail "$svc.tag must be a quoted string, postgres.yml.jinja calls .split() on it"
      else
        warn "$svc.tag should be a quoted string (got $TAG)"
      fi
      ;;
  esac
done
ok "tags checked"

# The wiki image is built from a generated Dockerfile that layers the pgsql
# extension, composer and the entrypoint onto services.wiki.image, and derives
# the extension branch REL<major>_<minor> from services.wiki.tag. A leftover
# image:/tag from a previous wiki engine therefore does not render wrong, it
# renders a Dockerfile that cannot build at all, and only fails once
# `podman compose up` tries. Catch it here instead.
if yq -e '.services.wiki.enable == true' "$ENV_FILE" > /dev/null 2>&1; then
  WIKI_IMAGE="$(yq -r '.services.wiki.image // ""' "$ENV_FILE")"
  WIKI_TAG="$(yq -r '.services.wiki.tag // ""' "$ENV_FILE")"
  case "$WIKI_IMAGE" in
    "" | */mediawiki | *mediawiki:*)
      ok "wiki base image is a MediaWiki image ($WIKI_IMAGE)"
      ;;
    *)
      fail "services.wiki.image is '$WIKI_IMAGE': the wiki image is built on top of a MediaWiki base image, e.g. docker.io/library/mediawiki"
      ;;
  esac
  # Also gates the REL<major>_<minor> branch derivation, which needs two parts.
  case "$WIKI_TAG" in
    [0-9]*.[0-9]*) ok "wiki tag is a <major>.<minor> release ($WIKI_TAG)" ;;
    *) fail "services.wiki.tag must be a MediaWiki release like '1.43' (got '$WIKI_TAG'): the extension branch REL<major>_<minor> is derived from it" ;;
  esac
fi

# Secrets must not be left at the placeholder.
if grep -q '<<INSERT SECRET HERE>>' "$ENV_FILE"; then
  fail "environment.yml still contains <<INSERT SECRET HERE>> placeholders"
fi

# The sample documents the supported schema, so it has to keep rendering.
head1 "environment.sample.yml"
if [ -f "$SELF_DIR/environment.sample.yml" ]; then
  for template in $(find "$SELF_DIR/templates" -type f -name '*.jinja' | sort); do
    name="$(basename "$template")"
    if out="$(jinja2 --strict "$template" "$SELF_DIR/environment.sample.yml" 2>&1 > /dev/null)"; then
      ok "$name renders"
    else
      fail "$name does not render against the sample:"
      printf '%s\n' "$out" | tail -3 | sed 's/^/        /'
    fi
  done
  if out="$(yq -e '.' "$SELF_DIR/environment.sample.yml" > /dev/null 2>&1)"; then
    ok "sample is valid YAML"
  else
    fail "sample is not valid YAML"
  fi
else
  warn "no environment.sample.yml"
fi

head1 "generated files"
if [ -z "$(ls -A "$RESULT_DIR/services" 2>/dev/null)" ]; then
  fail "no generated output in $RESULT_DIR, run 'task generate'"
else
  for f in "$SERVICES_DIR/compose.yml" "$SERVICES_DIR/.env" "$RESULT_DIR/nginx/nginx.conf" "$RESULT_DIR/sql/postgres.sql"; do
    [ -s "$f" ] && ok "$(basename "$f") rendered" || fail "missing or empty: $f"
  done

  python3 - "$RESULT_DIR" <<'PY'
import sys, pathlib, yaml
root = pathlib.Path(sys.argv[1])
class Strict(yaml.SafeLoader):
    pass
def nodup(loader, node, deep=False):
    seen = []
    for key, _ in node.value:
        name = loader.construct_object(key, deep=deep)
        if name in seen:
            print(f"DUP\t{name}")
        seen.append(name)
    return yaml.SafeLoader.construct_mapping(loader, node, deep)
Strict.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, nodup)
for path in sorted(root.rglob("*.yml")) + sorted(root.rglob("*.yaml")):
    # Templates that render nothing (disabled services) leave a newline behind.
    if not path.read_text().strip():
        continue
    try:
        yaml.load(path.read_text(), Loader=Strict)
        print(f"YAML\t{path.relative_to(root)}")
    except yaml.YAMLError as exc:
        print(f"YAMLERR\t{path.relative_to(root)}\t{str(exc)[:120]}")
PY
fi

head1 "compose / nginx consistency"
if [ -f "$SERVICES_DIR/compose.yml" ]; then
  # Every proxy_pass target has to be a compose service name or alias,
  # otherwise nginx refuses to start with "host not found in upstream".
  if [ -z "$CONTAINER_BIN" ]; then
    warn "no container runtime, skipped compose checks"
  else
    cd "$SERVICES_DIR"
    # podman-compose colorizes even when stdout is not a tty, and writes a
    # "Executing external compose provider" banner to stderr.
    COMPOSE_ERR="$(mktemp)"
    if COMPOSE_YAML="$($CONTAINER_BIN compose --env-file=.env config 2>"$COMPOSE_ERR" | sed $'s/\x1b\\[[0-9;]*m//g')"; then
      if printf '%s' "$COMPOSE_YAML" | yq -e '.services' > /dev/null 2>&1; then
        ok "compose config parses"
      else
        fail "compose config is not valid YAML"
      fi
    else
      fail "compose config does not parse:"
      sed 's/^/        /' "$COMPOSE_ERR" | tail -5
    fi
    rm -f "$COMPOSE_ERR"

    NAMES="$(printf '%s' "$COMPOSE_YAML" | python3 -c "
import sys, yaml
c = yaml.safe_load(sys.stdin) or {}
for name, svc in (c.get('services') or {}).items():
    print(name)
    for net in (svc.get('networks') or {}).values():
        for alias in ((net or {}).get('aliases') or []):
            print(alias)
" | sort -u)"

    # Container ports a service declares with `expose`, as "<name> <port>...".
    # A service that lists them is stating what it actually serves on, so nginx
    # has to use one of them. Services without `expose` keep the name-only check:
    # a published port maps a host port to a container port and is no proof of
    # which one the service listens on.
    EXPOSE_PORTS="$(printf '%s' "$COMPOSE_YAML" | python3 -c "
import sys, yaml
c = yaml.safe_load(sys.stdin) or {}
for name, svc in (c.get('services') or {}).items():
    ports = sorted({str(p).rsplit('/', 1)[0] for p in (svc.get('expose') or [])})
    if not ports:
        continue
    # nginx may address the service by its container_name too.
    for key in (name, svc.get('container_name')):
        if key:
            print(key + ' ' + ' '.join(ports))
" || true)"

    # Every proxy_pass target has to be a compose service name or alias,
    # otherwise nginx refuses to start with 'host not found in upstream'. The
    # port matters too: a proxy.port left over from a different wiki engine (or
    # any other service) resolves fine and then 502s on every request.
    #
    # The variable form (proxy_pass http://$upstream_x, used when dns_resolver
    # is set) has no literal target and is filtered out below.
    for target in $(grep -oE 'proxy_pass https?://[A-Za-z0-9_.:-]+' "$RESULT_DIR/nginx/nginx.conf" 2>/dev/null |
      sed -E 's|proxy_pass https?://||' | grep -E '[A-Za-z0-9]' | sort -u); do
      host="${target%%:*}"
      port=""
      case "$target" in *:*) port="${target##*:}" ;; esac

      if ! printf '%s\n' "$NAMES" | grep -qx "$host"; then
        fail "upstream $target: '$host' is not a compose service or alias"
        continue
      fi

      # sort -u: the map has one row per name, and a service whose name equals
      # its container_name would otherwise contribute its ports twice.
      allowed="$(printf '%s\n' "$EXPOSE_PORTS" | grep "^$host " | cut -d' ' -f2- | tr ' ' '\n' | grep -v '^$' | sort -u || true)"
      if [ -z "$allowed" ] || { [ -z "$port" ] || printf '%s\n' "$allowed" | grep -qx "$port"; }; then
        ok "upstream $target resolves"
      else
        fail "upstream $target: service '$host' serves port(s) [$(printf '%s' "$allowed" | tr '\n' ' ')], nginx uses $port. Fix proxy.port in environment.yml."
      fi
    done

    # depends_on targets must exist too.
    for dep in $(printf '%s' "$COMPOSE_YAML" | python3 -c "
import sys, yaml
c = yaml.safe_load(sys.stdin) or {}
for svc in (c.get('services') or {}).values():
    for dep in (svc.get('depends_on') or {}):
        print(dep)
" | sort -u); do
      printf '%s\n' "$NAMES" | grep -qx "$dep" ||
        fail "depends_on target '$dep' is not a compose service"
    done
    cd "$SELF_DIR"
  fi
fi

head1 "nginx config"
if [ -s "$RESULT_DIR/nginx/nginx.conf" ] && [ -n "$CONTAINER_BIN" ]; then
  IMAGE="$(yq -r '.services.nginx.image + ":" + (.services.nginx.tag | tostring)' "$ENV_FILE")"
  # Static upstreams are resolved when nginx starts, so a throwaway container
  # cannot resolve them unless it joins the running network. Stub them instead
  # to keep this check working with the stack down.
  HOST_ARGS=()
  for host in $(grep -oE 'proxy_pass https?://[A-Za-z0-9_.-]+' "$RESULT_DIR/nginx/nginx.conf" 2>/dev/null |
    sed -E 's|proxy_pass https?://||' | sort -u); do
    HOST_ARGS+=(--add-host "$host:127.0.0.1")
  done
  if $CONTAINER_BIN run --rm "${HOST_ARGS[@]}" \
    -v "$RESULT_DIR/nginx/nginx.conf:/etc/nginx/nginx.conf:ro" "$IMAGE" nginx -t > /tmp/nginx-t.$$ 2>&1; then
    ok "nginx -t passes"
  else
    fail "nginx -t failed:"
    sed 's/^/        /' /tmp/nginx-t.$$ | tail -5
  fi
  rm -f /tmp/nginx-t.$$
else
  warn "skipped nginx -t (no config or no container runtime)"
fi

head1 "optional hardening not enabled"
yq -e '.dns_resolver' "$ENV_FILE" > /dev/null 2>&1 ||
  warn "dns_resolver unset: nginx keeps resolving upstreams only at startup (see 'task resolver')"
if yq -e '.services.nextcloud.enable == true' "$ENV_FILE" > /dev/null 2>&1; then
  yq -e '.services.nextcloud.proxy.trusted_proxies' "$ENV_FILE" > /dev/null 2>&1 ||
    warn "nextcloud.proxy.trusted_proxies unset: client IPs are lost behind the proxy"
fi
PROTO="$(yq -r '.protocol' "$ENV_FILE")"
[ "$PROTO" = "https" ] || warn "protocol is '$PROTO': no TLS, HSTS or ACME challenge handling"

printf '\n'
if [ "$FAIL" -gt 0 ]; then
  printf '\033[31m%d failure(s), %d warning(s)\033[0m\n' "$FAIL" "$WARN"
  exit 1
fi
printf '\033[32mall checks passed\033[0m (%d warning(s))\n' "$WARN"