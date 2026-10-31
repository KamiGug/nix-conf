# Homelab services migration

Status: **in progress** (2026-10-31). The first implementation was reverted;
this revision uses Jinja rendered by Nix and one mandatory Dockerfile per
service. Review-hardened for secret handling, image builds, and network naming.
Update this line and `plans/README.md` as steps land.

## Invariants

- Nix is the only data source. Every config is a Jinja template rendered in a
  derivation with vars supplied by Nix. Do not parse YAML at eval time, do not
  add `compose.json`, and do not run `podman-compose` as the runtime.
- Every service has a `Dockerfile`. It wraps the upstream image with the shared
  secret-file entrypoint. Services with several containers get one Dockerfile
  each.
- Secrets are files, never values in the Nix store, image layers, or a declared
  `environment`/`environmentFiles`/`templateVars`/`buildArgs`/`extraOptions`.
  sops decrypts to the tree-preserving host path `/run/secrets/<sopsName>` (e.g.
  `/run/secrets/services/forgejo/DB_PASSWORD`); `mk` bind-mounts that same path
  read-only; the image entrypoint exports each file's basename before exec.
  Runtime env is the only place a secret value may appear.
- `postfix` is appended to every generated name/path: container/unit,
  network, data dir, sops path, build/init units.
- Secrets use tree-preserving sops names (`services/<fullName>/<key>`), not a
  synthetic container-local name.
- Network names are `app-service-<name><postfix>` everywhere. `mkNetwork`
  returns the full name; `ensureNetwork` accepts the logical name and applies
  the prefix exactly once. Never pass an `mkNetwork` result to `ensureNetwork`.
- Backend is podman. `mk`/`mkEnv` only pass `backend` to `ensureNetwork`.
- Every image is built by an activation-time `podman build` oneshot from the
  generated context, and the container unit is ordered after it. Nix never runs
  a container build in the sandbox.
- `docker-services/` stays until step 7 is explicitly unblocked.

## Target files

```
src/lib/services/
  default.nix          # re-exports the surface below
  mk.nix               # myLib.services.mk
  mkEnv.nix            # myLib.services.mkEnv
  container.nix        # oci-container core (absorbed mkContainerService)
  buildImage.nix       # Dockerfile + shared wrapper -> build context
  secret-entrypoint.sh # /run/secrets/** -> env -> exec upstream
  render.nix           # one Jinja file -> one single-file drv
  mkVolume.nix mkNetwork.nix mkHealthcheck.nix ensureNetwork.nix
  presets/
    default.nix proxy/default.nix
    postgres.nix forgejo.nix nextcloud.nix authentik.nix
    wiki.nix nginx.nix netbird.nix euroOffice.nix
```

Delete `mkContainerService.nix`, `mkSecret.nix`, and `apps/` in step 0.

```
src/services/<name>/
  Dockerfile           # required
  service.nix          # optional Nix-only extras
  compose.yml.jinja    # optional, render-only output
  templates/           # optional Jinja templates, one drv per file
```

## `mk` contract

```nix
{pkgs, ...}: {
  name, postfix ? "", dir,
  templates ? null, templatesRecursive ? false,
  composeTemplate ? "auto",       # auto -> dir/compose.yml.jinja, null disables
  baseImage ? null, buildArgs ? {},
  backend ? "podman",
  networks ? [], ports ? [], volumes ? [], environment ? {},
  environmentFiles ? [], secrets ? {}, command ? [],
  entrypoint ? null,   # container override
  dependsOn ? [],
  healthcheck ? null, shmSize ? null, privileged ? false, gpu ? false,
  hostname ? null, serviceUser ? "root", containerUser ? null,
  labels ? {}, extraOptions ? [], templateVars ? {},
  imageEntrypoint ? null,   # upstream entrypoint the wrapper execs
  fileEnvSupport ? false,   # image understands <VAR>_FILE
  domain ? null, protocol ? null, root ? null,
  sopsFile ? null, configMount ? null,
}: { ... }
```

Returns `{ name, module, config, image, compose, networks }`:

- `config`: one drv per template file, each holding one file at
  `$out/<basename>`. `mk` bind-mounts them under `configMount`.
- `image`: always `localhost/<fullName>:latest`. `module` also carries a
  `build-<fullName>` oneshot that runs `podman build` against the generated
  context and is ordered before the container unit; the build is keyed by the
  context derivation hash so it is idempotent.
- `compose`: the rendered `compose.yml`, or `null`. It is a reference artifact
  only: the runtime spec comes from the Nix args, and verification diffs the two.

Render vars are `templateVars // { name, postfix, fullName, domain, protocol,
root }`. Files under `templates/` are all Jinja, regardless of extension.
`templateVars`, `buildArgs`, `environment`, `environmentFiles`, and
`extraOptions` must never contain secret values; templates that need a secret
emit a placeholder and read it at runtime (see postgres/netbird).

`secrets` is `VAR -> { sopsName, path?, sopsFile?, key?, optional?, random? }`.
`VAR` is the env var name the entrypoint exports (the key basename). `sopsName`
is the tree-preserving name (e.g. `services/forgejo/DB_PASSWORD`), so the
sops-nix default path is `/run/secrets/<sopsName>` (i.e.
`/run/secrets/services/<fullName>/<key>`). `mk` creates/merges
`sops.secrets."<sopsName>"` using that same name (never a synthetic
`<fullName>-<VAR>` name), mounts `secret.path or "/run/secrets/<sopsName>"` at
the same path read-only, and may add `<VAR>_FILE=<same path>` for images with
native support. `sopsFile`/`key` are passed through when set; otherwise the
secret must already be declared by `buildSecrets`, and `mk` only adds the mount
and any `*_FILE` entry. A `path?` override is passed through to `sops.secrets`
and used for both mounts. For `optional = true`, a missing file omits both the
mount and the `*_FILE` entry.

Dockerfile contract:

- `ARG BASE_IMAGE` then `FROM ${BASE_IMAGE}`; the preset supplies the tag as a
  build arg. `buildArgs` are never secret.
- `COPY secret-entrypoint.sh` (injected into the context by `buildImage.nix`)
  and set `ENTRYPOINT ["/usr/local/bin/secret-entrypoint.sh", "<upstream
  entrypoint>"]` plus `CMD ["<upstream cmd>"]` in exec form. The wrapper walks
  every file under `/run/secrets/**`, exports its basename, then `exec "$@"`
  (which is the recorded upstream entrypoint+cmd).
- No secret values at build time. `buildImage.nix` copies the service dir,
  injects the wrapper, applies `stripSecretEnvs` to `ENV <secret>` lines, and
  must not include any secret file in the context. Never `COPY` a secret.

`mkEnv` takes `{postfix, domain, root, backend, sopsFile, networks, services,
templateVars}` and folds each enabled preset's module plus the network
oneshots. `networks` are logical names; `ensureNetwork` is the only place that
adds `app-service-<name><postfix>`, so `mkNetwork` results must not be passed
back into it. `mkEnv` asserts at eval that no two enabled services claim the
same host port. Presets return `{name, module, config, image, compose, networks,
ports, proxySnippet}`.

## Steps

### 0. Foundation

- Create the library files above.
- Implement `render.nix` with `pkgs.jinja2-cli --strict --format=json <template>
  <vars.json>` (template first, then the JSON data file).
- Implement `buildImage.nix`: copy the service dir, inject the shared
  `secret-entrypoint.sh`, apply `stripSecretEnvs`, expose `context`/`dockerfile`.
  The context must never contain a secret file.
- Fix `ensureNetwork` to accept the logical name and produce
  `app-service-<name><postfix>`.
- Delete `mkContainerService.nix`, `mkSecret.nix`, and `apps/`, and rewrite
  `default.nix` to re-export only the new surface.
- Verify `myLib.services.mk` on a throwaway `/tmp` service with a Dockerfile,
  one template, and one `compose.yml.jinja`; build that Dockerfile once.

### 1. postgres

- Move `docker-services/templates/services/service/postgres.yml.jinja` to
  `src/services/postgres/compose.yml.jinja`.
- Move `docker-services/templates/sql/postgres.sql.jinja` to
  `src/services/postgres/templates/init.sql.jinja` and rewrite it so it no
  longer interpolates `service.postgres.pass` (currently
  `docker-services/templates/sql/postgres.sql.jinja:18,26,28`). Use psql
  variables (`:'app_pass'`) and pass them at runtime with `psql -v`, or read
  them from `/run/secrets/...`; a secret value must never be rendered into the
  derivation.
- Add `src/services/postgres/Dockerfile` and the `postgres` preset.
- Add the state-guarded `psql` init oneshot for `databases`; it runs as the
  postgres user with `PGPASSWORD`/`-v` sourced from the secret files and is
  ordered after `sops-install-secrets.service`.
- Verify: `dry-activate`; build the image; start with a dummy secret and
  confirm the password came from `/run/secrets/services/<fullName>/...`; run
  `nix path-info` on the rendered `init.sql` drv and confirm it holds
  placeholders, not the password.

### 2. forgejo, nextcloud

- Add per-service Dockerfile, `compose.yml.jinja`, templates, and presets.
- Move `${VAR}` secrets into the `secrets` attrset using tree-preserving
  `sopsName`s; move data dirs under `${root}/<fullName>/`.
- Verify each with a `-test` postfix, then both postfixes together. `mkEnv`'s
  eval-time port assertion must reject the second env before any unit starts.

### 3. authentik

- Add separate server and worker Dockerfiles plus one preset returning both.
- Wire the shared secret, `dependsOn`, and the network.
- Verify server and worker start with secrets loaded from files.

### 4. wiki

- Move `docker-services/templates/services/mediawiki/` to `src/services/wiki/`
  with `Dockerfile`, `templates/setup.sh.jinja`, and
  `templates/LocalSettings.php.jinja`. There is no `secrets.php.jinja`: the
  entrypoint generates `secrets.php` at runtime, keep it that way.
- Keep `setup.sh` as a template; do not rewrite it in Nix.
- Verify the image builds and `Special:Version` loads.

### 5. nginx

- Move `docker-services/templates/nginx/nginx.conf.jinja` to
  `src/services/nginx/templates/`.
- Add the nginx Dockerfile and preset.
- Feed all preset `proxySnippet`s into `templateVars.vhosts`.
- Keep TLS at `/etc/nginx/tls`; drop the docker-services ACME path.
- Verify the rendered config passes `nginx -t`.

### 6. netbird, euroOffice

- Park until the image refs (euroOffice) and combined-server shape (netbird)
  are confirmed.
- When unblocked: Dockerfile, templates, preset, same secret contract. Netbird's
  `config.yaml.jinja` currently interpolates `auth_secret`,
  `store_encryption_key`, and the owner password
  (`docker-services/templates/services/netbird/config.yaml.jinja:29,43,50`);
  render non-secret values only and inject those three at container start from
  `/run/secrets/...` (NetBird `NB_*` env overrides where they exist, otherwise
  an entrypoint-materialized config). Never put them in `templateVars`.

### 7. Retire docker-services

- Blocked until every live `environment.yml` secret is transcribed into
  `secrets/` and the user confirms the diff.
- After parity on kkbook/kkserv: `git rm -r docker-services`.

## Verification

- `nix eval` each host's `config.system.build.toplevel.drvPath` after every
  step.
- Throwaway smoke test: postfix appears in container, unit, network, data,
  secret, and build names; `config` has one file per template; `compose`
  renders the same values as the Nix args.
- Secret check: mount is read-only at `/run/secrets/<sopsName>` in both host
  and container, the entrypoint exports the basename, and no secret value is in
  `environment`, `environmentFiles`, `templateVars`, `buildArgs`,
  `extraOptions`, the build context, or the Nix store (`nix path-info` on each
  rendered config drv). An `optional` secret with no file produces no mount and
  no `*_FILE`.
- Build each image once through the `build-<fullName>` oneshot, confirm the
  container unit is ordered after it, and confirm the wrapper execs the
  upstream entrypoint+cmd.
- Two-env test: postgres with two postfixes has distinct units, networks,
  data dirs, and secrets; the eval-time port assert rejects a clash; the
  network name has exactly one `app-service-` prefix.
- `nixos-rebuild dry-activate` for kkbook and kkserv, then the on-machine
  service checks (forgejo API, nextcloud status, wiki, authentik, postgres).
- `alejandra .`, `statix check`, `deadnix`, and a grep for `${VAR}` in tracked
  templates (placeholders only, never values).

## User-blocked

- Provision `/etc/sops/age.key` on each host.
- Transcribe live service secrets into `secrets/`.
- Confirm the netbird/euroOffice image refs.
- Approve host wiring and the on-machine rebuild.
