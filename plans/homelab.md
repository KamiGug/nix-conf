# Homelab services: autoloaded `mkService`, config/image derivation, sops, multi-env

Status: **blocked on plans/migration.md** — that plan must land first (it
introduces the `src/` layout, the `readModules` autoloader and the
`myLib.services` namespace this plan builds on). This plan never re-states the
migration plan's decisions; where they overlap (layout, autoloading, attr
names, `apps` folded under `services`), the details in `plans/migration.md`
win.
Date: 2026-10-16

## Problem

The live service stack lives in `docker-services/` as Jinja2-templated
compose files rendered by `task generate` into `result/`, with credentials in
a git-ignored `environment.yml` / `.env`. Every service definition (image,
ports, volumes, env, healthcheck, proxy vhost) is embedded in Jinja
conditionals over one 214-line YAML blob; there is no per-service
`nixos-rebuild`, no declarative network/volume handling, no sops integration,
and no way to run the same service twice on one host (names, ports, data
dirs and network would collide).

Meanwhile the Nix-native builders (`lib/services/`: `mkContainerService`,
`mkVolume`, `mkNetwork`, `mkSecret`, `mkHealthcheck`, `ensureNetwork`, plus
the `apps/` presets) are dark code — all call sites are commented out in
`hosts/kkbook/default.nix` — and they cannot express what docker-services
can: no config templating, no image builds (Dockerfile), no secrets, no
reverse-proxy wiring, and their naming conventions don't line up
(`mkNetwork` prefixes `app-service-`, `ensureNetwork` doesn't; the authentik
preset's `parentServiceName` uses `EnsureDirExists-` while
`ensureDirExists.nix` emits `EnsureDir-`).

## Decision

- **This plan supersedes `lib/services/` entirely.** After step 0 below,
  `mkContainerService`, `mkSecret` and the old `mk*`-style `apps/`
  presets are **deleted**, not kept as aliases — their option vocabulary
  and the oci-containers/podman target are absorbed into
  `myLib.services.mk` / `container.nix`, and every naming inconsistency
  listed in the Problem is fixed in the process. `mkVolume`, `mkNetwork`,
  `mkHealthcheck` and `ensureNetwork` **survive** (fixed: one network
  prefix convention) and stay exported. The only surviving public names
  are `myLib.services.{mk,mkEnv,render,presets}` + the
  volume/network/healthcheck helpers.
- **One new public entry point**, `myLib.services.mk` (options-attrset
  entrypoint, matching the `myLib.program.mk` style — see migration.md's
  rationale for one-vs-many functions). Given a **service directory** it
  autoloads:
  - `Dockerfile` (optional) → image derivation, **with secret `ENV`s
    stripped/overridden** (see Secrets),
  - `templates/` (optional, **arbitrary number of files**, each a config
    template) → **one derivation per config file** (`pkgs.runCommand`), so
    each rendered file can be bind-mounted individually (a store path per
    file; no packaging step, no directory indirection),
  - `compose.yml` (+ its eval-time `compose.json` mirror, see below) →
    defaults for ports/volumes/depends_on/environment,
  and returns a **set**:
  ```nix
  {
    name = "<name><postfix>";
    module = { ... };   # NixOS module attrset: oci container (→ systemd
                        # service), EnsureDir oneshots, sops.secrets,
                        # optional build-/init- oneshots
    config = { "<relpath>" = <drv>; ... };  # ONE drv per template file,
                        # keyed by its path under templates/ — e.g.
                        # { "nginx.conf" = <drv>; "conf.d/vhost.conf" = <drv>; }
                        # each drv contains exactly one file at $out/<basename>
    image  = <drv|null>; # built from Dockerfile, or null when image is a ref
    networks = [ ... ];  # resolved network names (prefixed)
  }
  ```
  Mounting a rendered file is then literally
  `"${cfg.config."nginx.conf"}/nginx.conf:/etc/nginx/nginx.conf:ro"` —
  `mk` itself wires the default mounts (`configMount` directory), but the
  caller gets independent drvs for anything extra (tests, `environment.etc`,
  ad-hoc binds). The `module` attrset is mergeable with
  `lib.recursiveUpdate` / `//` the same way `mkContainerService` output is
  today.
- **`postfix` argument, appended at the end** (the "prefix, but at the end"
  the user asked for): every generated name — container name, podman
  systemd unit, network name, `EnsureDir-`/`GenerateRandomSecret-` unit,
  data directory, sops secret name — gets `postfix` appended. Two instances
  of the same service on one machine are just two `mk` calls with
  `postfix = "-prod"` and `postfix = "-test"`.
- **`mkEnv`** (higher level, also a function, no state module): takes one
  environment's settings (domain, volume root, networks, per-service
  options, one shared `sopsFile`) and returns the folded module set for that
  environment. Calling it twice with different postfixes runs two
  environments on one machine — functions, not modules, per the user's
  requirement.
- **Presets** under `myLib.services.presets.*` — the eight docker-services
  services (`postgres`, `forgejo`, `nextcloud`, `authentik`, `wiki`,
  `nginx`, `netbird`, `euroOffice`) expressed as `mk` calls with the
  defaults currently living in their Jinja templates. The old `apps/`
  wrappers (nextcloud/authentik/dbs.postgres, with their `nameSuffix`)
  are deleted in step 0 below and replaced by these presets (`nameSuffix`
  → `postfix`).
- **Compose files stay the human-edited source per service** but are parsed
  at eval time through a **checked-in JSON mirror** (`compose.json`),
  regenerated by a taskfile task from `compose.yml`. Decision
  one-vs-alternatives: YAML cannot be parsed in Nix without IFD (flakes ban
  it by default; `yq`/`dasel` in a derivation would make eval depend on a
  build), hand-translating each compose into Nix loses the familiar editing
  surface and drifts, and keeping `podman-compose` at runtime bypasses the
  Nix store, declarative rebuilds and sops-nix. Rejected.
- **Secrets go through sops-nix** (input already wired into every host in
  `_resolveHostSet.nix`, but sops itself is **not set up yet** — see
  Prerequisites). The user's instinct is correct: **containers must read
  secrets from file paths, not plaintext env vars.** The mechanics:
  sops-nix decrypts each secret to a host path
  (`config.sops.secrets.X.path`, mode 0400) → `mk` bind-mounts it
  read-only into the container at `/run/secrets/<VAR>` → the image
  surfaces it as an env var from that file. Runtime support, in order of
  portability:
  - plain `docker run` has **no** `--secret` at all (swarm-only), and
    podman's `--secret …,type=env` (which does the file→env conversion for
    you) needs podman >= 5.1 — so neither runtime's secret mechanism is
    relied on; the **read-only bind mount of the sops path is the lowest
    common denominator** and works everywhere;
  - images with native file support get `VAR_FILE=/run/secrets/VAR`
    (postgres has `POSTGRES_PASSWORD_FILE`; others per-preset);
  - images without it get a generated **entrypoint override** (see
    Secrets) that exports each `VAR` from its file before exec'ing the
    original entrypoint.
  Secrets never appear as plaintext `ENV` in a Dockerfile, in a compose
  file, or in the Nix store — including in built images (Dockerfiles are
  overridden, see below).
- **Dockerfiles are inputs, not opaque artifacts**: `mk` post-processes a
  Dockerfile before building — any `ENV` whose value is listed in
  `secrets` is rewritten to the `*_FILE` form (or removed when the
  entrypoint wrapper handles it), so a leaked plaintext secret in a
  Dockerfile cannot be baked into an image layer. The wiki's
  `Dockerfile.jinja` currently relies on its entrypoint for exactly this
  and migrates cleanly.
- **Absorption caveat** (see the supersession bullet): while folding
  `mkContainerService` into `container.nix`, note that migration.md's
  earlier latent-bug claim about `mkContainerService.nix:178` (calling
  `myLib.ensureDirExists`) was **corrected after verification** — the
  file binds `myLib = import ../file` locally at line 25, so the call
  resolves as the file stands. It becomes real only if that binding is
  dropped during autoload normalization: change the call to
  `myLib.file.ensureDirExists` in the same commit that touches the file.

## Prerequisites

1. **`plans/migration.md` fully executed.** Concretely this plan assumes:
   - `src/lib/default.nix` is the `readModules` autoloader and every direct
     child of `src/lib` is a function of `args`;
   - `src/lib/services/default.nix` already merges `serv` + `apps`
     (`mkContainerService` → `myLib.services.*`, presets under
     `myLib.services.apps.*` per migration.md's `serv` → `services` /
     `apps` → `services.apps` renames);
   - `ensureNetwork`, `mkNetwork`, `mkSecret`, `mkVolume`, `mkHealthcheck`
     live under `src/lib/services/`;
   - hosts are wired through `_resolveHostSet` with
     `specialArgs = { inputs, systemModules, homeModules, myLib; }`.
2. **sops-nix set up on the machines** (partially done):
   - `helpers/secrets.nix` **already provides the base wiring for every
     host** (helpers is appended to all system and HM module lists):
     `sops.age.keyFile = lib.mkDefault "/etc/sops/age.key"` (line 30) and
     three live test `sops.secrets` (`peon-password`, `nixos-secret-test`,
     `hm-secret-test`) against `../secrets.yml`. The file is readable via
     directory-scoped grep (`rg -n "" helpers/` — direct path access is
     blocked by the `*secrets*` rule, directory scans are not); its shape
     is known (verified 2026-10-16), so this plan builds on it instead of
     inventing a second convention. Only pocvm overrides the keyFile
     (inside its VM config).
   - Still missing: the age **key material** at `/etc/sops/age.key` on
     each host, and real (non-test) secrets in `sops.yml` — both
     user-executed steps; `sops.yml` / `secrets.yml` contents remain
     agent-unreadable.
   - a per-host or shared `sopsFile` whose keys are known in advance — the
     naming scheme below reserves `"<name><postfix>-<VAR>"` and
     `"<name><postfix>-shared"` keys.
   - migration.md already flags that moving `helpers/` → `src/helpers/`
     breaks `secrets.nix`'s relative `../secrets.yml` path (step 2 there
     fixes it to `../../secrets.yml`). Any additional `sopsFile` paths
     introduced here must follow the same root-relative discipline.

## Current state (facts verified 2026-10-16)

- `docker-services/` — 8 services (`postgres nginx forgejo nextcloud
  authentik wiki netbird euroOffice`) rendered from
  `templates/services/service/*.yml.jinja` + `compose.yml.jinja` includes,
  driven by `environment.yml` (git-ignored, live secrets) vs
  `environment.sample.yml` (tracked schema); output in git-ignored
  `result/`; `task generate|run|up|check|validate`.
- All traffic is one compose default network; custom networks exist in the
  schema but no template consumes `service.networks` today.
- Secrets are `${VAR}` placeholders resolved from generated
  `result/services/.env` (from `.env.jinja`, unreadable to agents); var
  names: `POSTGRES_PASSWORD FORGEJO_DB_PASSWORD NEXTCLOUD_DB_PASSWORD
  AUTHENTIK_DB_PASSWORD AUTHENTIK_SECRET_KEY WIKI_DB_PASSWORD
  WIKI_ADMIN_PASSWORD WIKI_OIDC_CLIENT_SECRET EURO_OFFICE_JWT_SECRET
  NETBIRD_DB_PASSWORD`; authentik and wiki deliberately avoid `env_file` so
  one service's secrets do not leak into another.
- `lib/services/mkContainerService.nix` — 21 options, hard-codes
  `virtualisation.oci-containers.backend = "podman"`, `sdnotify =
  conmon|healthy`, volumes as `host:container[:ro]`, `--network=` per
  network, gpu/secret/privileged/hostname/user/health/shm extraOptions,
  `create = true` volumes merged with `ensureDirExists` oneshots.
- Naming inconsistencies to fix while absorbing the lib:
  `mkNetwork` returns `"app-service-" + name` but `ensureNetwork` takes
  the raw name; `mkSecret` returns `mountPath/mode/owner/group` which nothing
  consumes; `apps/authentik/default.nix:68` passes
  `parentServiceName = "EnsureDirExists-@etc@authentik"` while
  `ensureDirExists.nix` emits `EnsureDir-@etc@authentik`; the `mariadb`
  preset is an empty stub (`{}: {}`); the onlyoffice "preset" does not
  exist at all — only commented remnants inside
  `apps/nextcloud/default.nix` referencing a nonexistent `./onlyoffice.nix`;
  `mkImmutableFile.nix` is dead (not exported by any `default.nix`).
- sops-nix is a flake input and is added to nixos/darwin/home-manager
  modules; `helpers/secrets.nix` (appended to **every** host and HM) already
  declares three **live** test `sops.secrets` (`peon-password`,
  `nixos-secret-test`, `hm-secret-test`) plus the `mkDefault` age keyFile;
  no *service* secret is live yet (only commented code in users/ and
  system-modules). Root artifacts `sops.yml`, `secrets.yml`,
  `secrets/homelab.yml`, `keys/age.key` exist but their contents are
  agent-unreadable (`*sops*`/`*secrets*`/`*.key` permission rules) — only
  `sops.yml:7` (`sops_key: /etc/sops/age.key`) and `secrets.yml:6`
  (`sops:`) are known from grep. Key **material** at `/etc/sops/age.key`
  is not provisioned on the machines yet.
- `hosts/kkbook` is the only host with podman + the (commented) service
  call sites; it already pre-seeds `*.lab.hm` in `networking.hosts`.

## Target library layout (post-migration.md)

```
src/lib/services/
  default.nix          # autoloaded; re-exports:
  mk.nix               # myLib.services.mk          — the new entry point
  mkEnv.nix            # myLib.services.mkEnv       — multi-service envs
  container.nix        # shared mkContainerService core (absorbed internals)
  buildImage.nix       # Dockerfile -> image drv (+ stripSecretEnvs)
  mkVolume.nix mkNetwork.nix mkHealthcheck.nix   # survive, fixed
  ensureNetwork.nix    # fixed: same "app-service-" prefix as mkNetwork
  render.nix           # myLib.services.render      — renders ONE template
                       # file to ONE single-file derivation
  presets/             # myLib.services.presets.*
    postgres.nix forgejo.nix nextcloud.nix authentik.nix
    wiki.nix nginx.nix netbird.nix euroOffice.nix
    proxy/default.nix  # proxy-snippet registry consumed by nginx preset
  # mkSecret.nix and apps/ are deleted in step 0 (superseded by mk's
  # secrets handling and presets/)
```

Every file is a function of `args` (migration.md's autoload rule); a
directory with `default.nix` is one opaque module — so `presets/` and
`presets/proxy/` keep their `default.nix` and are never descended into.

## Service source directory layout (the autoloaded input)

```
src/services/<name>/
  service.nix          # optional Nix-only extras (asserts, init hooks);
                       # NOT a module — imported by mk if present
  Dockerfile           # optional: mk builds an image from it
  compose.yml          # optional: human-edited source (migrated from
                       # docker-services templates, env values already
                       # hoisted to ${VAR} / sops keys)
  compose.json         # optional: eval-time mirror, task-generated
  templates/           # optional: arbitrary number of config templates,
    *.conf / *.jinja / *.yml ...   # each rendered to its own derivation
```

Autoload rules inside `mk` (plain `builtins.pathExists` + `readDir`, no
module system involved):

- `compose ? "auto"` → `dir/compose.json` if present, else no compose
  defaults; `compose = <path>` or `compose = null` to override/disable.
- `templates ? null` (auto) → every regular file under `dir/templates/`
  (non-recursive by default; `templatesRecursive ? false` for trees like a
  full nginx conf.d); `templates = []` disables; a list of paths overrides
  selection.
- `buildImage ? null` (auto) → true iff `dir/Dockerfile` exists.

## `mk` specification

```nix
# src/lib/services/mk.nix
{pkgs, ...}: {
  # --- identity -----------------------------------------------------------
  name,                     # logical name, e.g. "forgejo"
  postfix ? "",             # appended to EVERY generated name (see below)
  # --- source dir ---------------------------------------------------------
  dir,                      # path; autoloads Dockerfile/templates/compose
  compose ? "auto",
  templates ? null,
  templatesRecursive ? false,
  buildImage ? null,
  # --- runtime ------------------------------------------------------------
  image ? null,             # image ref; required unless Dockerfile builds one
  networks ? [],            # strings or mkNetwork results
  ports ? [],
  volumes ? [],             # mkVolume results
  environment ? {},
  environmentFiles ? [],    # e.g. [ config.sops.secrets.<n>.path ]
  secrets ? {},             # VAR -> sops secret opts (see Secrets)
  command ? [],
  entrypoint ? null,
  dependsOn ? [],           # other mk result names (postfix applied)
  healthcheck ? null,       # mkHealthcheck result
  shmSize ? null,
  privileged ? false,
  gpu ? false,
  hostname ? null,
  serviceUser ? "root",
  containerUser ? null,
  labels ? {},
  extraOptions ? [],
  # --- templates ----------------------------------------------------------
  templateVars ? {},        # merged over compose-derived + built-in vars
  # --- sops ---------------------------------------------------------------
  sopsFile ? null,          # default sops file for this service's secrets
  # --- mounts -------------------------------------------------------------
  configMount ? null,       # container DIRECTORY for rendered configs; each
                            # file drv is mounted individually at
                            # ${configMount}/<basename> (caller can also
                            # mount result.config.<f> by hand)
} @ args:
assert builtins.isString name && name != "" || throw "name must be a non-empty string";
assert builtins.isString postfix || throw "postfix must be a string";
assert builtins.isPath dir || throw "dir must be a path";
# ... (same assert style as mkContainerService for every option)
let
  fullName = name + postfix;                 # forgejo + "-test" -> forgejo-test
  inherit (pkgs) lib;
  fileLib = import ../file { inherit pkgs; };

  composeData =
    if compose == null then {}
    else if compose == "auto" && builtins.pathExists (dir + "/compose.json")
    then builtins.fromJSON (builtins.readFile (dir + "/compose.json"))
    else if builtins.isPath compose
    then builtins.fromJSON (builtins.readFile compose)
    else {};

  # compose.yml describes one service; its service block may be under
  # .services.<name> or .services.<host> — take the single entry.
  cService =
    if composeData ? services
    then lib.head (lib.attrValues composeData.services)
    else {};

  templateFiles = /* readDir walk of dir/templates per rules above */;

  # One derivation PER template file — independent store paths, each with
  # a single file at $out/<basename>, so every rendered config can be
  # bind-mounted (or referenced) on its own.
  configFiles =
    lib.genAttrs templateFiles (f: myLib.services.render {
      # render is curried ({pkgs, ...}: {name, file, vars}: drv); through
      # myLib the pkgs stage is already applied — a single attrset call
      # is the whole application.
      file = f;
      name = "${fullName}-${baseNameOf (toString f)}";
      vars = templateVars // composeVars // { inherit name postfix fullName; };
    });

  # Secrets as files in the container: VAR_FILE=/run/secrets/VAR (images
  # with native *_FILE support) + a generated entrypoint wrapper for the
  # rest (see Secrets). No runtime --secret/type=env dependence.
  secretFileMounts = lib.mapAttrsToList (var: _:
    lib.nameValuePair var {
      type = "bind"; readOnly = true; create = false;
      # sops-nix's default layout; `config` is not in scope in this plain
      # function — callers needing a custom path pass it via `volumes`
      # themselves (mkSecret's path-return is superseded).
      hostMount = "/run/secrets/${fullName}-${var}";
      containerMount = "/run/secrets/${var}";
      owner = null; group = null; mode = null;
    }) secrets;

  needsEntrypointWrap = secrets != {} && !(fileEnvSupport or false);
  # What the wrapper exec's after exporting secrets: the caller's
  # `entrypoint` override if given, else the image's original
  # ENTRYPOINT+CMD (parsed from the Dockerfile by buildImage.nix, which
  # exposes it as `imageEntrypoint`); fail loudly if neither exists.
  originalEntrypoint =
    if entrypoint != null then entrypoint
    else imageEntrypoint or (throw
      "${fullName}: entrypoint wrap needs `entrypoint` or a parseable Dockerfile ENTRYPOINT/CMD");
  wrappedEntrypoint = pkgs.writeScript "${fullName}-entrypoint.sh" ''
    #!/bin/sh
    set -eu
    ${lib.concatMapStrings (var: ''
      if [ -f /run/secrets/${var} ]; then
        export ${var}="$(cat /run/secrets/${var})"
      fi
    '') (builtins.attrNames secrets)}
    exec ${lib.escapeShellArgs originalEntrypoint} "$@"
  '';

  imageDrv =
    if buildImage == false then null
    else if buildImage == true || builtins.pathExists (dir + "/Dockerfile")
    then import ./buildImage.nix {
      inherit pkgs dir postfix;
      name = fullName;
      # Dockerfile is post-processed here: any ENV <VAR>=... whose <VAR> is
      # in `secrets` is rewritten to VAR_FILE=/run/secrets/<VAR> (or
      # dropped when the entrypoint wrapper handles the export), so no
      # secret is baked into an image layer.
      stripSecretEnvs = builtins.attrNames secrets;
    }
    else null;

  resolvedImage =
    if image != null then image
    else if imageDrv != null then "localhost/${fullName}:latest"
    else throw "mk ${fullName}: need image = \"...\" or dir/Dockerfile";

  secretUnits = /* sops.secrets entries + optional GenerateRandomSecret, below */;

  container = import ./container.nix ({
      name = fullName;
      image = resolvedImage;
      inherit (args) networks ports command privileged gpu hostname
        serviceUser containerUser labels extraOptions shmSize;
      entrypoint =
        if needsEntrypointWrap then [ (toString wrappedEntrypoint) ]
        else args.entrypoint or null;
      volumes = volumes
        # each rendered config file mounted individually
        ++ lib.optionals (configMount != null) (
          lib.mapAttrsToList (rel: drv: {
            type = "bind"; readOnly = true; create = false;
            hostMount = "${drv}/${baseNameOf rel}";
            containerMount = "${configMount}/${baseNameOf rel}";
            owner = null; group = null; mode = null;
          }) configFiles)
        # sops secrets: host store path -> /run/secrets/<VAR>, read-only
        ++ secretFileMounts;
      dependsOn = map (d: d + postfix) dependsOn;
      healthcheck = healthcheck;
      environment = environment
        # *_FILE pointers for every secret; the actual values never live in
        # the environment (nor in the Nix store, nor in image layers)
        // lib.mapAttrs' (var: _:
             lib.nameValuePair "${var}_FILE" "/run/secrets/${var}") secrets;
    } // secretUnits);
in {
  name = fullName;
  module = lib.foldl' lib.recursiveUpdate {} ([
      container
      # every volume with create = true -> fileLib.ensureDirExists with
      # path "${root}/${fullName}${...}" naming; parentServiceName =
      # "podman-${fullName}" (must match what oci-containers emits)
    ] ++ secretUnits.modules);
  config = configFiles;
  image = imageDrv;
  networks = map (n: if builtins.isString n then n else n.name) networks;
}
```

**Postfix semantics** (the user's "prefix, but at the end"), applied
uniformly by string concatenation on `fullName` and on derived paths:

| thing | without postfix | `postfix = "-test"` |
|---|---|---|
| container / podman unit | `forgejo` / `podman-forgejo.service` | `forgejo-test` / `podman-forgejo-test.service` |
| network (with `app-service-` prefix) | `app-service-nextcloud` | `app-service-nextcloud-test` |
| data dir | `${root}/forgejo/data` | `${root}/forgejo-test/data` |
| `EnsureDir` unit | `EnsureDir-@mnt@nas@forgejo@data` | `EnsureDir-@mnt@nas@forgejo-test@data` |
| sops secret (`<fullName>-<VAR>`) | `forgejo-FORGEJO_DB_PASSWORD` | `forgejo-test-FORGEJO_DB_PASSWORD` |
| build/init units | `build-forgejo` | `build-forgejo-test` |

Port collisions between two instances are the caller's job (compose-derived
ports are identical by default; `mkEnv` presets expose `ports` overrides —
see Risks).

### Sketch errata (verified 2026-10-16)

Corrections applied to the `mk`/render sketches above after checking them
against the real code and the migration plan:

- **`config` is not in scope** in `mk` (a plain function, not a module) —
  the secret bind mount uses sops-nix's default path
  `/run/secrets/<fullName>-<VAR>` instead of
  `config.sops.secrets.<n>.path`. Callers with a custom secret path pass
  their own `volumes` entry.
- **`originalEntrypoint` was undefined** in the entrypoint wrapper — now a
  let-binding: caller `entrypoint` override, else `imageEntrypoint`
  (parsed from the Dockerfile by `buildImage.nix`), else a loud throw.
- **`render.nix` is curried** (`{pkgs, ...}: {name, file, vars}: drv`) —
  the sketch's single `import ../render.nix {...}` application returned the
  inner function, not a derivation. The call goes through
  `myLib.services.render`, the already-partially-applied first stage.
- **`pkgs.jinja2` has no `bin/jinja2`** — `render.nix` uses
  `pkgs.jinja2-cli` (what the devShell and `lib/program.nix` already use).

## Networks & isolation

- `mkNetwork` / `ensureNetwork` keep one convention: every network created
  through the homelab lib is `"app-service-" + name + postfix`. Fix
  `ensureNetwork` to accept the *logical* name + postfix and apply the same
  prefix (today it takes the raw string, which is why it never matched).
- `mkEnv` creates `ensureNetwork` oneshots for all of the env's networks;
  services opt into networks by name, so two envs only share a network when
  the caller deliberately passes the same unprefixed name **and**
  `postfix = ""` on both — by default postfix isolates them.
- Networks already created on a live machine under the old unprefixed names
  (only relevant for the commented-out kkbook experiments; no live custom
  networks exist today because no template consumes them) — no migration
  needed; note the orphaned-`ensure-<name>-podman-network-exists` units on
  kkbook if any were ever activated, to be cleaned manually.

## Secrets (sops-nix — not set up yet)

`secrets` is an attrset of **environment-variable name → sops options**:

```nix
secrets = {
  FORGEJO_DB_PASSWORD = { };                       # key in sopsFile
  AUTHENTIK_SECRET_KEY = { sopsFile = ./auth.yml;  # per-secret override
                           key = "authentik/secret_key"; };
  WIKI_OIDC_CLIENT_SECRET = { optional = true; };  # may be absent
};
```

`mk` produces:

```nix
{
  sops.secrets."${fullName}-${VAR}" = {
    sopsFile = secret.sopsFile or sopsFile or throw "...";
    key     = secret.key or VAR;
  } // (removeAttrs secret [ "optional" ]);

  systemd.services."GenerateRandomSecret-${fullName}-${VAR}" =
    # only when secret.random = true; via fileLib.mkRandomSecret
    # path: /run/secrets/${fullName}-${VAR};   # sops-nix default layout

  # container wiring (the whole point — files, not env values):
  #   volumes ++ [{
  #     hostMount    = "/run/secrets/${fullName}-${VAR}";  # host, 0400
  #     containerMount = "/run/secrets/${VAR}"; readOnly = true;
  #   }]
  #   environment."${VAR}_FILE" = "/run/secrets/${VAR}";   # for images with
  #                                            # native *_FILE support
  #   entrypoint = generated wrapper (for images without it): reads each
  #     /run/secrets/${VAR} and exports ${VAR} before exec'ing the original
  #     entrypoint/CMD
}
```

- Secret names are name-scoped (`<fullName>-<VAR>`, with postfix part of
  `fullName`, e.g. `forgejo-test-FORGEJO_DB_PASSWORD`) so two envs on one
  machine can have different values from one `sops.yml`. `mkEnv` also
  accepts `sharedSecrets = [ "AUTHENTIK_SECRET_KEY" ]` which are
  registered once without the `<fullName>-` prefix — open question below.
- **Why not the runtimes' own secret mechanisms** (correction of an earlier
  draft of this plan that used a podman-secret-store bridge oneshot —
  rejected): plain `docker run` has no `--secret` at all (swarm-only), and
  podman's `--secret …,type=env` needs podman >= 5.1, so neither is
  portable across the docker/podman split the lib pretends to support
  (`ensureNetwork` already takes a `backend`). The sops-path bind mount +
  `*_FILE`/entrypoint-export works on any runtime with zero glue and zero
  version gates.
- Per-preset `fileEnvSupport` declares whether the image natively reads
  `*_FILE` (postgres: yes, `POSTGRES_PASSWORD_FILE`; forgejo: yes via
  `FORGEJO__database__PASSWD__FILE`-style; nextcloud/authentik/wiki: mostly
  no → entrypoint wrapper). The wiki's `setup.sh.jinja` already reads
  secrets from files and migrates as-is.
- Prerequisite: sops-nix setup per Prerequisites section; this plan cannot
  be validated against the real `sops.yml`/`secrets.yml` contents until the
  user (not an agent — permission rules) confirms their shape.

## `render` — one template file → one derivation

`myLib.services.render` renders a **single** template to a **single**
derivation, so every rendered config file is independently mountable:

```nix
# src/lib/services/render.nix
{pkgs, ...}: {
  name,           # drv name
  file,           # ONE template path
  vars,           # attrset; written to vars.json
}: let
  varsFile = pkgs.writeText "${name}-vars.json" (builtins.toJSON vars);
in pkgs.runCommand name {
  nativeBuildInputs = [ pkgs.jinja2-cli ];
} ''
  mkdir -p $out
  ${pkgs.jinja2-cli}/bin/jinja2 --strict --format=json \
    ${varsFile} ${file} > $out/${baseNameOf (toString file)}
''
```

- "Config template pkgs" plural: `mk` maps this over the autoload walk and
  returns `config = { "<relpath>" = <drv>; … }` — each entry is one file at
  `<drv>/<basename>`. Mounting:
  `"${cfg.config."nginx.conf"}/nginx.conf:/etc/nginx/nginx.conf:ro"`, or
  let `mk` auto-mount the whole attrset under `configMount`, or
  `environment.etc."x".source = cfg.config."x"` — all per-file, no
  packaging indirection. A change to one template rebuilds only its drv
  (image drv and sibling configs unaffected).
- One renderer (jinja2-cli — the same attr and `jinja2` binary the devShell
  (flake.nix:97) and `lib/program.nix:50` already use; `pkgs.jinja2` has no
  `bin/jinja2`) keeps the migration mechanical: existing
  `templates/**/*.jinja` files move over nearly unchanged, with
  `environment.yml` fields becoming `templateVars`.
- Built-in vars always available: `name`, `fullName`, `postfix`, `domain`,
  `root`, plus the service's compose block.

## Image builds (Dockerfile)

Two modes, decided by `buildImage` / presence of `dir/Dockerfile`:

1. **Preferred: activation-time build oneshot.**
   `systemd.services."build-${fullName}"` runs
   `podman build -t localhost/${fullName}:latest` against a **generated
   build context** (a `pkgs.runCommand` holding the Dockerfile after
   `stripSecretEnvs` rewriting — secret `ENV`s never reach the image — plus
   any COPY sources), `wantedBy = []`, `requiredBy`/`before` the container
   unit. Works for the existing wiki Dockerfile (composer needs network at
   build); store path is immutable so the unit is idempotent (podman skips
   when the tag exists and the context hash is unchanged — cache it under
   `/var/lib/homelab/images/` keyed by drv hash to be safe). Impurity:
   network access during activation — acceptable on a homelab host, not on
   builders; open question below.
2. **Rejected for now: `dockerTools.buildLayeredImage`** — requires
   translating each Dockerfile into Nix (composer installs, git clones of
   MediaWiki extensions) with no reuse of the file. Revisit only if
   offline/ISO builds need the image.

`image = "…"` refs (the seven non-wiki services) skip all of this.

## Higher level: presets and `mkEnv`

```nix
# src/lib/services/mkEnv.nix
{pkgs, ...}: {
  postfix ? "",           # whole-env postfix (e.g. "-prod" / "-test")
  domain ? "lab.hm",
  root ? "/mnt/nas",      # volume root
  backend ? "podman",     # open question: mkContainerService hard-codes podman
  sopsFile ? null,        # default for all services in the env
  networks ? [],          # logical network names for this env
  secrets ? {},           # env-wide secrets (postfix-scoped)
  services ? {},          # name -> preset args; each preset honors { enable }
}:
lib.foldl' lib.recursiveUpdate {} (
  map ensureNetwork networks
  ++ lib.mapAttrsToList (n: s: (presets.${n} (s // { inherit postfix domain root sopsFile; })).module)
                        (lib.filterAttrs (_: s: s.enable or true) services)
)
```

- One call = one environment = one merged module set. No state, no
  `services.my.homelab.*` option tree — **functions**, so several envs
  coexist on one machine by calling `mkEnv` twice:
  ```nix
  # hosts/kkserv/default.nix (illustrative)
  myLib.services.mkEnv {
    postfix = "-lab";
    services = { postgres = {}; forgejo = {}; wiki = {}; nginx = {}; };
  }
  // myLib.services.mkEnv {
    postfix = "-scratch";
    services = { postgres = {}; wiki = { ports = { http = 8081; }; }; };
  }
  ```
- Presets are thin: `presets/forgejo.nix` = `mk` with the image/tag,
  healthcheck, volumes, environment names, proxy snippet and `secrets`
  schema currently in `templates/services/service/forgejo.yml.jinja`, plus
  the compose block hoisted to `compose.yml`/`compose.json`. The old
  `myLib.services.apps.{nextcloud,authentik,dbs.postgres}` wrappers are
  deleted (step 0); callers use the presets instead (`nameSuffix` →
  `postfix`).
- **Proxy snippets**: every preset returns, alongside `module`, a
  `proxySnippet` string (the nginx vhost fragment it needs). `mkEnv`
  concatenates all snippets into the nginx preset's `templateVars` — this
  replaces the per-service `proxy:` Jinja blocks and keeps
  `nginx.conf.jinja`'s header/rate-limit/TLS logic in one place.

## docker-services migration

Ordered so every step is independently eval-able; commit per step. Assume
migration.md steps 1-6 are done and sops is set up.

0. **Tooling + supersession.** Add `task compose-json` (dasel-based
   `compose.yml` → `compose.json`) to the root `taskfile.yml`; add a
   lefthook/task check that the json is not stale. Create `src/services/`
   and `src/lib/services/{mk,render,buildImage,mkEnv,container}.nix`; fix
   `ensureNetwork`'s prefix; **delete** `mkContainerService.nix`,
   `mkSecret.nix` and the old `apps/` preset wrappers (superseded — see
   Decision), folding their option vocabulary into `mk`. No consumers
   exist today (all call sites commented), so this is eval-safe. Verify:
   `nix eval` of `myLib.services.mk` on a throwaway dir under `/tmp` (or
   an `--impure` expr) — not under `hosts/`, pocvm is a real TEMP host.
1. **postgres** (simplest; no proxy, no templates beyond init SQL).
   Move `templates/services/service/postgres.yml.jinja` →
   `src/services/postgres/compose.yml` (rendered once, Jinja conditionals
   resolved, `${POSTGRES_PASSWORD}` kept), generate `compose.json`, write
   the `postgres` preset (major-<18 data-path quirk becomes a
   `templateVars.postgresMajor`), move `templates/sql/postgres.sql.jinja` →
   the preset's `initSql` template + a `psql` oneshot
   (`requiredBy`/`after` postgres, runs `psql -f` rendered SQL once,
   state-guarded). Verify on kkbook: `dry-activate`, then `run` the
   container manually.
2. **forgejo, nextcloud** — pure compose-derived services; env vars with
   `${VAR}` become `secrets`; data dirs under `${root}/<fullName>/data`.
   Verify each with a `-test` postfix while a `-prod` (or unprefixed)
   instance is *not* running, then both postfixes at once (port clash must
   be resolved by overriding `ports` in the second env — confirm the
   failure mode is a loud eval/assert, not a runtime bind error).
3. **authentik** — two containers sharing a secret; exercises
   `dependsOn` + shared networks + `mkSecret` env wiring; drop the broken
   `parentServiceName` convention (fixed in step 0).
4. **wiki** — the only Dockerfile path: `src/services/wiki/{Dockerfile,
   templates/{LocalSettings.php.jinja,setup.sh.jinja,secrets.php.jinja}}`
   move nearly verbatim; `buildImage` oneshot; the 204-line `setup.sh`
   entrypoint stays as a template (do **not** rewrite it in Nix — risk
   note).
5. **nginx** — `nginx.conf.jinja` moves to
   `src/services/nginx/templates/`; proxy snippets from all presets feed
   `templateVars.vhosts`; TLS cert dir stays a host bind mount
   (`/etc/nginx/tls`); drop `docker-services`'s ACME story (certs are
   host-managed today anyway — `ocsp_stapling: false`, static
   `certificate_dir`).
6. **netbird, euroOffice** — both disabled in the live `environment.yml`
   (euroOffice: missing image ref in live env; netbird: live env uses the
   *client* image by mistake vs the server image in the sample — resolve
   with the user before migrating). Migrate last; parking them is
   acceptable.
7. **Retire `docker-services/`.** After parity on kkbook/kkserv:
   `git rm -r docker-services` (git history + `plans/` retain the design).
   `environment.yml`'s plaintext values must already have been transcribed
   into `sops.yml` by the user before deletion — block this step on a
   user-confirmed diff of every secret value.

## Risks

- **Blocked-by-readability**: `src/helpers/secrets.nix`, `sops.yml`,
  `secrets.yml`, `keys/age.key`, `docker-services/.env(.jinja)` are all
  agent-unreadable by permission rules. Every secret transcription in step
  7 and the sops Prerequisites is a user-executed step; the plan must not
  guess their contents.
- **compose.json drift** — mitigated by the task/lefthook staleness check;
  a stale json silently loses a port/volume. `mk` warns at eval when
  `compose.yml` is newer than `compose.json` (via `builtins.readFile` +
  `builtins.currentTime` is impossible — use the hook only).
- **Port/name collisions across postfixes** are caller-managed; presets
  expose `ports` but there is no automatic offset. Loud assert in `mkEnv`
  when two enabled services claim the same host port.
- **Activation-time `podman build`** (wiki) needs network and adds
  activation latency; failure leaves the unit failed but the rest of the
  env intact (`requiredBy`, not `wantedBy`, on the container).
- **Entrypoint wrapper is generated glue**: for images without native
  `*_FILE` support the wrapper must exec the image's original
  ENTRYPOINT/CMD correctly (`exec "$@"` semantics, args passed through);
  a wrong original-entrypoint capture breaks startup only at runtime.
  Mitigation: presets record the original entrypoint explicitly (read from
  the image metadata at migration time) rather than guessing.
- **`*_FILE` support gaps**: forgejo/authentik/nextcloud env var handling
  varies by version — verify each secret actually loads from the file path
  in the on-machine functional check, not just that the mount exists.
- **Ordering**: alphabetical autoload order (migration.md risk) applies to
  nothing here (mk is per-call, explicit), but preset defaults overriding
  compose defaults follow "explicit Nix arg > compose.json > preset
  default" — get the merge order wrong and a service silently loses a port.
- **Data path ownership**: docker-services ran everything as root;
  `mkVolume`/`ensureDirExists` default to explicit owner/mode — migrated
  volumes may need a one-time chown on `/mnt/nas` (dry-activate will not
  catch this).

## Verification

- `nix eval` of every host's `config.system.build.toplevel.drvPath` after
  each migration step (all 6 nixos incl. TEMP pocvm + iso + darwin, per
  migration.md).
- `nix eval --impure --expr` smoke tests: `mk` autoload on a dir with/without
  Dockerfile/templates/compose.json; postfix appears in container name,
  unit name, network name, EnsureDir name, secret name; `cfg.config` is an
  attrset with one drv per template file and each drv contains exactly one
  file at `$out/<basename>`.
- Per-secret wiring check: for one migrated service, eval the container's
  volumes and confirm each `sops.secrets.<n>.path` appears as a read-only
  bind at `/run/secrets/<VAR>` and no secret value exists in the Nix store
  (`nix path-info` on the rendered config drvs).
- Two-env test on one machine: `mkEnv` with postfixes `-a`/`-b` for
  postgres — both units up, networks distinct, data dirs distinct, secrets
  distinct.
- `task compose-json` staleness hook fires on a hand-edited compose.yml.
- `nixos-rebuild dry-activate --flake .#kkbook` then `.#kkserv`; on-machine
  functional check per migrated service (forgejo API health, nextcloud
  status, wiki Special:Version, authentik admin, postgres `psql`).
- `alejandra .`, `statix check`, `deadnix` clean; grep: no remaining
  `${VAR}` secret values in tracked files; `docker-services/` gone from the
  tree after step 7.

## Open questions

- Delete `docker-services/` outright (step 7) or keep a `docker-services/
  README` pointing at the new layout for one release?
- Shared (`postfix`-less) secrets: needed for things like
  `AUTHENTIK_SECRET_KEY` across envs, or is one secret per env fine?
- Backend: keep podman hard-coded (status quo of `mkContainerService`) or
  thread `backend ? "podman"` through `mk`/`mkEnv` now that
  `ensureNetwork` already accepts both?
- Do `presets` stay as one `.nix` file per service (current shape) or
  become data (JSON per service) + one generic preset renderer? Prefers
  files until a 10th service appears.
- TLS: keep host- `/etc/nginx/tls` bind mounts, or move cert material into
  sops and drop the host dependency?
- Netbird's combined (mgmt+signal+relay+STUN) container and its Dex
  config — migrate as one preset or split into several `mk` calls sharing
  a network? (Live env has it disabled; decide with the user in step 6.)
