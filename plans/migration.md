# Migration: src/ layout, filesystem-as-registry, auto-loading modules, lib, hosts & users

Status: **in progress** — steps 1–2 done; step 3 next.
Date: 2026-10-16

## Problem

Module discovery is hand-maintained in five registries that duplicate (and
drift from) the filesystem:

- `home-modules/default.nix` — hand-written `{common, linux, darwin}` lists
  (~28 entries in `common` alone).
- `system-modules/default.nix` — same shape; its `common` list is empty and
  the four `common*.nix` files are imported by **explicit path** from
  `lib/flake/_resolveHostSet.nix:54-68` instead.
- `lib/default.nix` — hand-written attrset mirroring the `lib/` directory
  tree, with naming shims (`scanPkgs`, `validate`, `serv`).
- `flake.nix` — the `nixosHosts` / `darwinHosts` attrsets declare hosts (and
  per-host args) by hand, then map them through `mk*Host`; the host modules
  themselves live in `hosts/<name>/` with no filesystem link to the
  registry. (`isoConfigurations.installer` is a third, separate mapping.)
- `users/default.nix` — hand-written `{root, peon, wisp, kg, peasant}`
  attrset, each entry imported with `inputs`; (was drifted with an unlisted
  `users/pocuser.nix`, but that file was removed 2026-10-18 — see Current
  state).

Consequences: adding a module, host or user means editing a registry by
hand;
modules that are not in a registry are invisible (two orphans existed — one
is merged away during this migration, the other becomes auto-loaded; see
below); the lib attrset must be kept in sync with the directory tree by
hand; and `_resolveHostSet.nix` carries a dangling `import (root +
"/services")` that only survives because nothing forces the specialArg.

## Decision

- **Everything Nix moves under `src/`**; `flake.nix` / `flake.lock` stay at
  the repo root (flake constraint). `secrets/`, `keys/`, `sops.yml`,
  `secrets.yml`, `plans/`, `changes/`, `docker-services/` and all tooling
  (`.lefthook.yml`, `taskfile.yml`, `.dev/`) stay at the root.
- **One new public function**, `myLib.fs.readModules`, with **two modes**:
  `mode = "set"` (attrset mirroring the top level of the filesystem) and
  `mode = "array"` (flat list of paths), plus `stopOnDefault ? true`
  (stop descending at directories containing `default.nix`).
  *Decision one-vs-two functions:* one function with a mode argument, not
  two — the modes are presentation variants of the same walk; an
  options-attrset entrypoint matches the established `myLib.program.mk`
  style; a second public function would either duplicate the walker or
  leak internals. Rejected alternative: `readModulesList` +
  `readModulesSet` sharing a private walker.
- **The filesystem becomes the registry**: `home-modules/` →
  `src/modules/home/`, `system-modules/` → `src/modules/system/`, and the
  `{common, linux, darwin}` groups become **real directories**:
  `src/modules/{home,system}/{common,linux,darwin}`. Both registry
  `default.nix` files are deleted; the module lists are derived at eval
  time by `readModules`.
- **`gui` is not a filesystem tier** (it is a host flag, not a platform):
  system GUI modules live in `src/modules/system/gui/`, which is scanned in
  array mode and appended by the `mk*Host` functions only when
  `gui && os == "linux"`.
- **The lib is autoloaded** the same way: `src/lib/default.nix` becomes a
  `readModules`-based autoloader; every direct child of `src/lib` is
  normalized to a function of `args`; `scan-pkgs.nix` → `scanPkgs.nix` so
  the attr name matches the filename.
- **`mk*Host` functions** (`mkLinuxHost`, `mkDarwinHost`, `mkIsoHost`, and
  shared `_resolveHostSet`) are updated to: new `root` defaults, `src/`
  path strings, `readModules` instead of registry imports, gui-tier
  wiring, removal of the dangling `services` import; `mkIsoHost` is
  deduplicated by routing through `_resolveHostSet` (see below).
- **Hosts are auto-loaded from the filesystem**, with the same
  disambiguation discipline as the module tiers: `src/hosts/linux/` =
  NixOS systems (`mkLinuxHost` → `nixosConfigurations`), `src/hosts/darwin/`
  = macOS systems (`mkDarwinHost` → `darwinConfigurations`). The flake's
  hand-written `nixosHosts` / `darwinHosts` attrsets are deleted. The ISO
  is a linux system (`src/hosts/linux/installer/`) selected by
  `iso = true` in its `host.nix` → `mkIsoHost` → `isoConfigurations`
  (decision: keep the ISO inside the `linux/` tier — filesystem
  disambiguation is exactly linux-vs-darwin; the ISO-specific behavior is
  host data, not a third platform).
- **Per-host args live next to the host module**: an optional
  `<host>/host.nix` = `{inputs}: { gui ? false; users ? null;
  extraModules ? []; iso ? false; }` (absent = `mk*Host` defaults). The
  existing flake-level data moves there: kkbook/kktab `gui = true`,
  kktab's nixos-hardware `extraModules`, kg-continabook's
  `users`, installer's `users` + `iso = true`. Enumeration is done by a
  new unapplied lib member `readHosts` (`src/lib/flake/readHosts.nix`);
  a hosts-tier directory without a `default.nix` is a hard error — no
  silently dropped hosts.
- **Users are auto-loaded the same way**: `src/users/` is scanned by a new
  unapplied lib member `readUsers` (`src/lib/flake/readUsers.nix`); the
  hand-written `users/default.nix` registry (root/peon/wisp/kg/peasant) is
  deleted. A user is a `*.nix` file returning `{system, home}` module
  functions, imported with `inputs`; per-host selection is unchanged
  (`users = [...]` in `host.nix`; `mkLinuxHost` defaults gui→`["peon"]`,
  else `["wisp"]`).
- **Rules that fall out of `stopOnDefault`:**
  - a directory with a `default.nix` is one module and is never descended
    into (this is exactly the program-dir pattern: `default.nix` +
    `config/` + `templates/` + `nix/`);
  - a plain `.nix` file is always a module;
  - a directory that must expose **both** a module **and** child modules
    must not use `default.nix` — name the module `base.nix` instead.
    Today exactly one module hits this: `console/terminal` (registered
    alongside `terminal/kitty` and `terminal/wezterm`) → its module is
    renamed `terminal/default.nix` → `terminal/base.nix`.
- **Orphan `sshd.nix`:** `system-modules/sshd.nix` (fully gated behind
  `my.sshd.enable`, default false) moves to
  `src/modules/system/linux/sshd.nix` and becomes auto-loaded (inert until
  enabled).
- **Rust CLI wrapper merged, not deleted:** the orphaned
  `home-modules/scripts/` (option `homeModules.rustCrates`) is merged into
  the bash-scripts module `home-modules/console/scripts/`. The merged
  module keeps `apps.my.scripts.{enable}` (decision: the separate
  `apps.my.scripts.rust.enable` toggle was **dropped** — rust rides the
  same `enable` as the bash scripts; opt out by disabling
  `apps.my.scripts`): every crate directory
  under `console/scripts/rust/` that contains a `Cargo.toml` is built with
  `pkgs.rustPlatform.buildRustPackage` (repo precedent:
  `pkgs/hxr/default.nix`) against its checked-in `Cargo.lock`, and lands
  on PATH via `home.packages`. The orphan's broken pieces are gone:
  nonexistent `./rust` dir, nonexistent `pkgs.cargoBuild.tryImport`,
  nonexistent `home.bin` option. A seed crate
  `rust/hello-world-rs/` (`Cargo.toml` + `Cargo.lock` + `src/main.rs`,
  edition 2021, zero dependencies) demonstrates the pipeline.
  `bash/` and `rust/` are data dirs next to the module's `default.nix` —
  invisible to `readModules` because the scanner never descends past a
  `default.nix`.
- **Not autoloaded (kept hand-written):** `src/helpers/` (deliberate
  explicit list of the two cross-cutting modules `secrets.nix` +
  `using.nix`). Possible future work, out of scope here.

## Current state (facts verified 2026-10-16; updated 2026-10-20)

> **Update 2026-10-20 (pre-step-2 baseline re-verified):** the TEMP `pocvm`
> host and `users/pocuser.nix` were **already removed** (commit `4f5ad3a`,
> 2026-10-18) — `flake.nix` no longer lists pocvm and neither
> `hosts/pocvm/` nor `users/pocuser.nix` exists. So the target is **7
> configurations**, not 8: 5 nixos (kkbook, kktab, kkserv, kknas, kkworker)
> + 1 iso (installer) + 1 darwin (kg-continabook). Everything in this plan
> that says "8 configurations" or "6 nixos" should be read as 7/5. The
> pocvm/pocuser cleanup steps (step 5, open question 1) are therefore
> already done — skip them.
>
> **Pre-existing host breakage (NOT caused by the migration; present at
> HEAD `3bb807f`):** `kkserv`, `kknas` and `kkworker` do not evaluate.
> `kkserv` defines `services.my.ai.*` (`hosts/kkserv/default.nix:23`) but no
> module declares `options.my.ai` — eval error (`Did you mean services.mpd?`).
> `kknas`/`kkworker` reference a `hardware-configuration.nix` that was never
> committed (gitignored). These are out of scope for the migration; steps
> that say "eval every configuration" apply to the hosts that evaluated
> before the move (kkbook, kktab, installer, kg-continabook).

- `flake.nix:48` — `flakeLib = import ./lib/flake;`. Hosts declared as
  data attrsets in flake.nix and mapped through `flakeLib.mkLinuxHost` /
  `mkDarwinHost` / `mkIsoHost`: `nixosHosts` = kkbook `{gui}`,
  kktab `{gui, extraModules = [nixos-hardware surface]}`, kkserv, kknas,
  kkworker; `darwinHosts` = kg-continabook `{users = ["kg"]}`;
  `isoConfigurations.installer` via `mkIsoHost {users = ["peasant"];}`.
  Total: **7 configurations (5 nixos + 1 iso + 1 darwin)** — pocvm already
  removed (see update above).
- `lib/flake/{mkLinuxHost,mkDarwinHost,mkIsoHost}.nix` — `root ? ../..`
  (3 occurrences; becomes `../../..` after the move).
- `users/default.nix` — `{...} @ inputs: { root, peon, wisp, kg, peasant =
  import ./<name>.nix inputs; }`: the hand-written user registry
  (`users/pocuser.nix` was already removed 2026-10-18, so the registry is no
  longer drifted — the five entries match the directory). Consumed in `_resolveHostSet.nix:37,44-53` (`myUsers` →
  `userSystemModules` = `.system` per host-selected user;
  `homeManagerUsers` = `.home` under `home-manager.users.<name>`) and
  duplicated in `mkIsoHost.nix:15,22,27` (dies with mkIsoHost's dedup).
  User files are functions returning
  `{system = {...}: {...}; home = {...}: {...};}` — each half is a module
  function taking `pkgs`/`config`. `mkLinuxHost.nix:16-24`: `users ? null`
  defaults gui→`["peon"]`, else `["wisp"]`.
- `lib/flake/_resolveHostSet.nix` — imports registries by path
  (`system-modules`, `home-modules`, `users`, `helpers`, `lib`) and the
  four `common*.nix` files by explicit path; line 41 has the dangling
  `import (lib.path.append root "services")` (directory deleted in
  `a05833e`; harmless only via laziness).
- No module anywhere consumes the `systemModules`, `homeModules` or
  `services` specialArgs (grep over `hosts/ users/ home-modules/
  system-modules/ helpers/`: zero declarations; the only hits were
  commented-out args in `users/{kg,peon,peasant,wisp}.nix` and the
  unrelated option namespace `homeModules.rustCrates` in the now-merged
  `home-modules/scripts/`). Dropping/reshaping specialArgs is therefore
  safe.
- `myLib` member usage outside `lib/`: `program` ×24, `editor` ×10,
  `serv` ×8, `lsp` ×8, `file` ×3, `apps` ×3, `ensureDirExists` ×1.
  All `serv`/`apps` uses are in `hosts/kkbook/default.nix`.
  `myLib.validate` and `myLib.scanPkgs` have **zero** consumers.
- Correction to an earlier draft of this plan (verified 2026-10-16, caught
  by plans/homelab.md): `lib/services/mkContainerService.nix:178` calls
  `myLib.ensureDirExists`, and that **resolves today** — the file binds
  `myLib = import ../file {inherit pkgs;};` locally at line 25. It becomes
  a real bug only if that binding is dropped during autoload
  normalization: rewrite the call to `myLib.file.ensureDirExists` in the
  same commit that touches the file.
- Relative cross-references that must be updated on move (complete list):
  - `flake.nix:48` (`./lib/flake`), `flake.nix:107` (`./overlays`);
  - `hosts/installer/default.nix:7-8` (`../../pkgs/{nix-conf-clone,nix-conf-install}`),
    `:13-14` (`../../system-modules/{common,common-linux}.nix`);
  - `home-modules/ide/helix/nix/hxr.nix:2` (`../../../../pkgs/hxr`);
  - path strings inside `lib/flake/{_resolveHostSet,mkIsoHost}.nix`
    (`"/users"`, `"/system-modules"`, `"/home-modules"`, `"/helpers"`,
    `"/lib"`, `"hosts/${name}"` — the latter becomes
    `hosts/<os>/${name}` with the hosts-tier disambiguation).
- `helpers/secrets.nix` — **readable via directory-scoped grep**
  (`rg -n "" helpers/`; direct path access is blocked by the `*secrets*`
  rule, directory scans are not). Verified contents (2026-10-16):
  `secretsFile = ../secrets.yml;` (relative — **breaks** when helpers
  moves to `src/helpers/`, must become `../../secrets.yml` or absolute);
  `sops.age.keyFile = lib.mkDefault "/etc/sops/age.key"` (already set for
  every host — helpers is appended everywhere); three
  live test `sops.secrets` entries (`peon-password`, `nixos-secret-test`,
  `hm-secret-test`). `secrets.yml` contents remain user-only.
- `console/terminal/` is the only directory registered both as itself and
  via separately-registered children (`kitty/`, `wezterm/`); its
  `default.nix` is a real module (options + assertion + config). All other
  registered directories are leaves (program dirs) or childless group dirs.
- `.lefthook.yml` / `taskfile.yml` / `.dev/` contain **no** references to
  the moved paths (grep verified).
- Scripts module (post-merge state, verified 2026-10-16):
  `home-modules/console/scripts/default.nix` deploys `bash/` recursively
  to `~/.local/share/scripts` under `apps.my.scripts.enable`, which is
  turned on by the fish, zsh and elvish shell modules — i.e. every user of
  those shells gets scripts (and now the rust crates) enabled.
  The merged rust half builds each `rust/*/` crate dir (matched by
  `Cargo.toml` presence) via `rustPlatform.buildRustPackage` with
  `cargoLock.lockFile` (no hash needed for local, dependency-free crates);
  seed crate `rust/hello-world-rs/` (edition 2021, lock format v4,
  zero dependencies).

## Target layout

```
flake.nix                     # unchanged role; updated imports
flake.lock
secrets/ keys/ sops.yml secrets.yml   # stay at root (sops paths)
src/
  lib/                        # mk*Host lives in lib/flake/
    default.nix               # NEW: readModules-based autoloader
    fs.nix                    # NEW: readModules
    scanPkgs.nix              # renamed from scan-pkgs.nix
    program.nix editor.nix lsp.nix
    flake/                    # default.nix becomes args-ignoring fn
    file/ services/ validators/
  modules/
    home/
      common/                 # was home-modules/ common list
        console/ creative/ ide/ kando.nix ...
        console/scripts/      # merged module: bash/ + rust/
          bash/               # existing shell scripts (deployed as-is)
          rust/
            hello-world-rs/   # seed crate: Cargo.toml Cargo.lock src/main.rs
      linux/                  # was de/ waybar/ gaming/
      darwin/                 # was mac/
    system/
      common/base.nix         # was system-modules/common.nix
      linux/                  # base.nix (= common-linux.nix) +
                              # gaming avahi autologin printing luks-key
                              # usb-luks-key sshd(.nix)
      darwin/base.nix         # was common-darwin.nix
      gui/base.nix            # was common-gui-linux.nix; NOT auto-included
  hosts/
    linux/                    # NixOS systems + the ISO
      kkbook/ kktab/ kkserv/ kknas/ kkworker/
      installer/              # ISO: host.nix carries iso = true
      # each host dir: default.nix (module) [+ hardware-configuration.nix]
      #                [+ optional host.nix = {inputs}: {gui, users,
      #                   extraModules, iso} — absent = mk*Host defaults]
    darwin/
      kg-continabook/         # host.nix = {inputs}: {users = ["kg"];}
  users/                      # pure move; default.nix deleted (scan-derived)
  helpers/ overlays/ pkgs/    # pure moves
plans/ changes/ docker-services/ ...       # stay at root
```

## `readModules` specification

New file `src/lib/fs.nix`, exported as `myLib.fs.readModules`:

```nix
# src/lib/fs.nix
{lib, ...}: {
  readModules = {
    dir,                    # path to scan
    mode ? "set",           # "set" | "array"
    stopOnDefault ? true,   # stop at dirs containing default.nix
  }:
    assert builtins.isPath dir || throw "dir must be a path";
    assert builtins.elem mode ["set" "array"]
      || throw "mode must be one of \"set\", \"array\"";
    let
      walk = d: let
        entries = builtins.readDir d;   # sorted by name
      in
        if stopOnDefault && entries ? "default.nix"
        then [d]                         # the dir itself is the module
        else lib.concatMap
              (name: let
                 p = d + "/${name}";
                 kind = entries.${name};
               in
                 if kind == "directory"
                 then walk p
                 else lib.optional (kind == "regular" && lib.hasSuffix ".nix" name) p)
              (builtins.attrNames entries);

      leavesOf = name: kind: let
        p = dir + "/${name}";
      in
        if kind == "directory"
        then walk p
        else lib.optional (kind == "regular" && lib.hasSuffix ".nix" name) p;

      top = builtins.readDir dir;
    in
      if mode == "array"
      then walk dir
      else lib.genAttrs (builtins.attrNames top) (name: leavesOf name top.${name});
}
```

Semantics:

- `mode = "array"` — flat, depth-first, `readDir`-ordered list of module
  paths: leaf `.nix` files, and directories that contain a `default.nix`
  (returned as the directory path — the module system resolves
  dir-with-default.nix). Non-`.nix` regular files, symlinks and other
  kinds are skipped.
- `mode = "set"` — attrset keyed by the **immediate children** of `dir`;
  each value is the array-mode scan of that child. Callers get
  `{ common = [...]; linux = [...]; darwin = [...]; }` from
  `src/modules/home` with zero hand-written lists. Only one grouping
  level — enough to replace the registries; deeper nesting would
  complicate the API for no consumer.
- `stopOnDefault = true` (default) — a `default.nix` makes the directory a
  single opaque module. `stopOnDefault = false` is available for trees
  where every file must be collected, but must **not** be used on the
  module trees (it would pick up program-dir `nix/*.nix` fragments).
- Order changes: registries were hand-ordered; the scan yields
  alphabetical order. The module system is order-independent except for
  equal-priority conflicting definitions — verification step below.

Worked examples:

```nix
readModules { dir = ./src/modules/home;    mode = "set"; }
# -> { common = [ ... ]; linux = [ ... ]; darwin = [ ... ]; }

readModules { dir = ./src/modules/system/gui; mode = "array"; }
# -> [ ./src/modules/system/gui/base.nix ]

readModules { dir = ./src/lib; mode = "set"; }
# -> { editor = [ ./editor.nix ]; file = [ ./file ]; flake = [ ./flake ];
#      fs = [ ./fs.nix ]; lsp = [ ./lsp.nix ]; program = [ ./program.nix ];
#      scanPkgs = [ ./scanPkgs.nix ]; services = [ ./services ];
#      validators = [ ./validators ]; }
```

### Lib autoloader

Every direct child of `src/lib` must be a **function of `args`** so args
can be threaded uniformly (most already are; normalize
`validators/default.nix` and `flake/default.nix` from plain attrsets to
`args: { ... }` — `flake/default.nix` must re-export the `mk*Host`
functions **unapplied**). Then:

```nix
# src/lib/default.nix
args: let
  parsedArgs = args // {lib = args.pkgs.lib;};
  fs = import ./fs.nix parsedArgs;
  tree = fs.readModules {dir = ./.; mode = "set";};
  resolve = paths:
    if builtins.length paths == 1
    then import (builtins.head paths) parsedArgs
    else throw "src/lib entry must resolve to exactly one module";
in
  builtins.mapAttrs (_: resolve) tree
```

Attr-name fallout (all cheap, grep-verified):

- `scan-pkgs.nix` → `scanPkgs.nix` (zero consumers; attr stays `scanPkgs`).
- `validate` → `validators` (zero consumers).
- `serv` → `services` and top-level `apps` → `services.apps` (nested under
  `services/`, no longer a top-level child): 9 call sites, all in
  `hosts/kkbook/default.nix` — mechanical rename.
- `ensureDirExists` stays under `myLib.file`; the one call in
  `mkContainerService.nix:178` resolves today via that file's local
  `myLib = import ../file` binding — rewrite it to
  `myLib.file.ensureDirExists` when the file is touched (see Current
  state).
- `flake/` becomes `myLib.flake` — but `flake.nix` keeps its own direct
  import: `flakeLib = import ./src/lib/flake {};` (called with empty args,
  which the normalized `flake/default.nix` ignores). The normalized
  `flake/default.nix` additionally exports `readHosts` **unapplied**
  (like the `mk*Host` functions): `readHosts = import ./readHosts.nix;`.

### `readHosts` — filesystem host enumeration

New file `src/lib/flake/readHosts.nix`, exported as
`flakeLib.readHosts` (unapplied; takes `inputs` at call time because
`host.nix` files may need them; needs no `pkgs`):

```nix
# src/lib/flake/readHosts.nix
{inputs}: {
  dir,   # e.g. ./src/hosts/linux
}: let
  entries = builtins.readDir dir;             # sorted by name
  dirs = builtins.filter (n: entries.${n} == "directory")
    (builtins.attrNames entries);
  isHost = n: builtins.pathExists (dir + "/${n}/default.nix");
  hostDirs = builtins.filter isHost dirs;
  strays = builtins.filter (n: !isHost n) dirs;
in
  assert builtins.isPath dir || throw "dir must be a path";
  assert strays == [] || throw
    "readHosts ${toString dir}: directories without default.nix: ${toString strays}";
  builtins.listToAttrs (map (name: {
      inherit name;
      value = {
        path = dir + "/${name}";
        args =
          if builtins.pathExists (dir + "/${name}/host.nix")
          then import (dir + "/${name}/host.nix") {inherit inputs;}
          else {};
      };
    })
    hostDirs)
```

- Returns `{ <dirname> = { path; args; }; }` — name = directory name =
  flake attr name = `networking.hostName` (unchanged convention).
- `args` is the raw `host.nix` result; `flake.nix` consumes `gui`,
  `users`, `extraModules` and strips `iso` before calling `mk*Host`
  (whose parameter lists are closed — an unexpected attr is an eval
  error, which is what we want).
- Stray host-looking directories (no `default.nix`) throw instead of
  being silently dropped; regular files (READMEs, `.gitignore`) are
  ignored.
- Host enumeration is per tier — call it twice (`linux/`, `darwin/`);
  cross-tier drift (a `kk*` dir landing in `darwin/`) is visible as a
  missing `nixosConfigurations` attr, same as any misnamed dir today.
- `readHosts` is deliberately **not** `readModules`: hosts are
  one-dir-per-entity with per-host args, not module lists. It shares the
  "filesystem is the registry" discipline, not the walker.

### `readUsers` — filesystem user enumeration

New file `src/lib/flake/readUsers.nix`, exported as
`flakeLib.readUsers` (unapplied; `{inputs}: {dir}:` — takes `inputs`
because user files are functions of it; needs no `pkgs`):

```nix
# src/lib/flake/readUsers.nix
{inputs}: {
  dir,                    # e.g. ./src/users
}: let
  entries = builtins.readDir dir;             # sorted by name
  names = builtins.attrNames entries;
  isUserFile =
    n: n != "default.nix"
    && entries.${n} == "regular"
    && builtins.hasSuffix ".nix" n;
in
  assert builtins.isPath dir || throw "dir must be a path";
  assert ! builtins.elem "default.nix" names
    || throw "readUsers ${toString dir}: users/default.nix registry still present — delete it (users are scanned now)";
  assert (builtins.all (n: entries.${n} == "regular") names)
    || throw "readUsers ${toString dir}: only regular .nix files allowed (directories are not users): ${toString (builtins.filter (n: entries.${n} != "regular") names)}";
  builtins.listToAttrs
    (map
      (file:
        let
          name = builtins.baseNameOf file;
          user = import (dir + "/${file}") {inherit inputs;};
        in
          assert user ? system && user ? home
            || throw "readUsers ${toString dir}/${file}: user must provide {system, home}";
          {inherit name; value = user;})
      (builtins.filter isUserFile names))
```

- Returns `{ <name> = {system, home}; }` — name = filename stem = user
  name = the `users.users.<name>` / `home-manager.users.<name>` key
  (unchanged convention; matches today's filenames: `peon.nix` → `peon`).
- Users are **imported results, not paths** — the file bodies are
  functions of `inputs` (exactly what the registry did per entry), so
  `readUsers` imports each with `inputs`. This is why it is a sibling of
  `readHosts`, not a mode of `readModules`.
- Hard errors, same discipline as `readHosts`: leftover `default.nix`
  registry, any subdirectory, or a user missing the `{system, home}` shape
  throw at eval instead of failing silently. Non-`.nix` regular files
  (README, `.gitignore`) are ignored, as in `readHosts`. Directories are
  rejected (not skipped) so a future dir-based user layout
  (`users/<name>/default.nix` + args, host-style) is a deliberate
  follow-up, not an accident.
- Per-host **selection is unchanged**: hosts pick users by name
  (`users = [...]` in `host.nix`; `mkLinuxHost` defaults gui→`["peon"]`,
  else `["wisp"]`). Autoloading removes the registry, not the selection.

## mk*Host / flake wiring changes

- `lib/flake/mkLinuxHost.nix`, `mkDarwinHost.nix`, `mkIsoHost.nix`:
  `root ? ../..` → `root ? ../../..`; path strings
  `"/system-modules"` → `"/src/modules/system"`, `"/home-modules"` →
  `"/src/modules/home"`, `"/users"` → `"/src/users"`, `"/helpers"` →
  `"/src/helpers"`, `"/lib"` → `"/src/lib"`, host module
  `"hosts/${name}"` → `"hosts/<os>/${name}"` (see below — the tier is
  the disambiguation directory).
- `lib/flake/_resolveHostSet.nix`:
  - load the scanner directly (before `myLib` exists):
    `fs = import (lib.path.append root "src/lib/fs.nix") {lib = inputs.nixpkgs.lib;}`;
  - `systemModules = fs.readModules { dir = root + "/src/modules/system"; mode = "set"; }`
    and same for `homeModules` / `home`;
  - delete the whole `commonModules` block (the four explicit
    `common*.nix` paths) — `base.nix` files now live inside the tiers and
    arrive via the scan;
  - delete the dangling `services` import (line 41) and drop `services`
    from `specialArgs` (zero consumers); keep
    `specialArgs = { inputs, systemModules, homeModules, myLib; }` —
    same `{common, linux, darwin}` shape as before;
  - gui wiring:
    `++ lib.optionals (gui && os == "linux") (fs.readModules { dir = lib.path.append root "src/modules/system/gui"; mode = "array"; })`;
  - host module path becomes
    `(lib.path.append root "hosts/${os}/${name}")` — `_resolveHostSet`
    already receives `os` ("linux"/"darwin"), so the filesystem
    disambiguation and the wiring use the same two names;
  - `myLib = import (lib.path.append root "src/lib") {inherit pkgs;};`
    (same call shape — `src/lib/default.nix` is now the autoloader);
  - users: `myUsers` moves **below** the `myLib` binding (it currently
    sits at the top of the `let`, before `myLib` exists) and becomes
    `myUsers = myLib.flake.readUsers {inherit inputs; dir = lib.path.append root "src/users";};`
    — `userSystemModules` / `homeManagerUsers` are untouched (the
    `{name = {system, home};}` shape is the contract);
  - `home-manager.sharedModules` logic unchanged
    (`homeModules.common ++ homeModules.${os}` + noctalia when gui).
- `mkIsoHost.nix` — **decision:** route through `_resolveHostSet.nix`
  (`os = "linux"`, `arch = "x86"`, `gui = false`; `users` comes from the
  installer's `host.nix`, defaulting to `["peasant"]` as today) and
  delete its duplicated wiring; its host module path becomes
  `hosts/linux/${name}`; delete
  `hosts/installer/default.nix`'s manual imports of
  `system-modules/{common,common-linux}.nix` (the linux tier already
  contains `base.nix`). Cost: the installer gains the full linux system
  and home tiers as option-defined-but-disabled modules (eval weight only
  — gated by `mkIf`; must be confirmed in verification). Fallback if that
  proves unacceptable: keep `mkIsoHost` separate, just switch its two
  registry imports to `readModules` array mode on the `common` + `linux`
  `base.nix` files.
- `flake.nix` — replace the hand-written host attrsets with
  `readHosts`-driven enumeration (host args now come from the filesystem):

  ```nix
  flakeLib = import ./src/lib/flake {};
  linuxHosts = flakeLib.readHosts {inherit inputs; dir = ./src/hosts/linux;};
  darwinHosts = flakeLib.readHosts {inherit inputs; dir = ./src/hosts/darwin;};

  isoHosts = lib.filterAttrs (_: h: h.args.iso or false) linuxHosts;
  nixosHosts = lib.filterAttrs (_: h: !(h.args.iso or false)) linuxHosts;

  nixosConfigurations = builtins.mapAttrs (name: host:
    flakeLib.mkLinuxHost (host.args // {inherit inputs name;}))
    nixosHosts;
  isoConfigurations = builtins.mapAttrs (name: host:
    flakeLib.mkIsoHost (builtins.removeAttrs host.args ["iso"]
      // {inherit inputs name;}))
    isoHosts;
  darwinConfigurations = builtins.mapAttrs (name: host:
    flakeLib.mkDarwinHost (host.args // {inherit inputs name;}))
    darwinHosts;
  ```

  (`lib` here is `nixpkgs.lib`; `host.args // {inherit inputs name;}` —
  inputs/name win over anything a `host.nix` might set, same as today's
  `hostArgs // {inherit inputs name;}`.) Also
  `import ./overlays` → `import ./src/overlays`.
- `hosts/installer/default.nix`: `../../pkgs/...` → `../../../src/pkgs/...`;
  `home-modules/ide/helix/nix/hxr.nix`: `../../../../pkgs/hxr` →
  `../../../../../../src/pkgs/hxr` (adjust depth: file ends up at
  `src/modules/home/common/ide/helix/nix/hxr.nix`, so `pkgs` is
  `../../../../../src/pkgs/hxr` — recompute exactly during the move).

## Migration steps

Ordered so every step is independently eval-able; commit per step.

1. **Merge the rust CLI wrapper into the scripts module.** ✅ **DONE**
   (2026-10-20 — verified: crate in peon's `home.packages`, builds, runs).
   (Already
   applied in the working tree on 2026-10-16 at the old paths; keep as its
   own commit.) Rewrite
   `home-modules/console/scripts/default.nix`: keep the `bash/` deployment
   under `apps.my.scripts.enable` and build every `rust/*/` directory
   containing a `Cargo.toml` via `pkgs.rustPlatform.buildRustPackage`
   (`cargoLock.lockFile`, `lib.cleanSource`, `meta.mainProgram = name`)
   under the **same** `apps.my.scripts.enable` (the separate
   `rust.enable` toggle was dropped by decision).
   Add the seed crate `rust/hello-world-rs/`
   (`Cargo.toml` edition 2021, hand-written dependency-free `Cargo.lock`
   v4, `src/main.rs`, plus `rust/.gitignore` containing `target/`).
   Delete `home-modules/scripts/` (fully merged away). Verify: eval
   kkbook and confirm `hello-world-rs` shows up in peon's `home.path`
   (`nix eval .#nixosConfigurations.kkbook.config.home-manager.users.peon.home.path`)
   or in the built toplevel closure.
2. **Relocate (pure move, no semantics).** ✅ **DONE** (2026-10-20).
   `git mv lib hosts users helpers
   overlays pkgs home-modules system-modules src/` (created `src/` first).
   Updated: `flake.nix` (`./lib/flake` → `./src/lib/flake`, `./overlays` →
   `./src/overlays`), `mk*Host` root defaults (`../..` → `../../..`) and all
   `root + "/<dir>"` path strings → `"/src/<dir>"`,
   `_resolveHostSet`/`mkIsoHost` host path → `src/hosts/${name}`,
   `hosts/installer/default.nix` relative imports → `../../../src/...`.
   Also fixed `src/helpers/secrets.nix:6` (`../secrets.yml` →
   `../../secrets.yml`). **Verified:** kkbook, kktab, installer and
   kg-continabook all eval to drvPaths; `nix flake show` lists 7
   configurations (kkserv/kknas/kkworker fail on pre-existing errors — see
   Current state update).
   *Note (2026-10-20):* the move exposed that `overlays/default.nix` uses
   `../lib/scan-pkgs.nix` and `../pkgs` — both resolve because `overlays/`
   and `lib/`/`pkgs/` move together under `src/`; no edit needed.
3. **Add the scanner.** Create `src/lib/fs.nix`; temporarily add
   `fs = import ./fs.nix parsedArgs;` to the old `src/lib/default.nix`.
   Verify with `nix eval` that set mode on `src/modules`… (still old dirs
   at this point — smoke-test on `src/lib` instead) returns the expected
   shape.
4. **Autoload the lib.** Normalize `validators/default.nix` and
   `flake/default.nix` to `args:` functions (the latter re-exports
    `mkLinuxHost`/`mkDarwinHost`/`mkIsoHost`/`readHosts`/`readUsers`
    **unapplied**); create `src/lib/flake/{readHosts,readUsers}.nix` per
    the specs; `git mv scan-pkgs.nix scanPkgs.nix`; replace
    `src/lib/default.nix` with the
   autoloader; rename in `hosts/kkbook/default.nix`: `myLib.serv.*` →
   `myLib.services.*`, `myLib.apps.*` → `myLib.services.apps.*`; rewrite
   `mkContainerService.nix:178`'s `myLib.ensureDirExists` →
   `myLib.file.ensureDirExists` (resolves today only via the file's
   local binding — see Current state). Verify:
   rebuild `kkbook` (the only host exercising `serv`/`apps`).
5. **Auto-load the hosts (filesystem disambiguation).**
   - Move each host into its platform tier:
     `git mv src/hosts/kkbook src/hosts/linux/kkbook` (same for kktab,
     kkserv, kknas, kkworker, installer);
     `git mv src/hosts/kg-continabook src/hosts/darwin/kg-continabook`
     (create the tier dirs first). (pocvm already gone — skip.)
   - Write the `host.nix` files carrying today's flake-level data:
     `linux/kkbook` `{inputs}: {gui = true;}`; `linux/kktab`
     `{inputs}: {gui = true; extraModules = [inputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel];}`;
     `linux/installer` `{inputs}: {iso = true; users = ["peasant"];}`;
     `darwin/kg-continabook` `{inputs}: {users = ["kg"];}`;
     kkserv/kknas/kkworker get no `host.nix` (defaults).
   - Update `_resolveHostSet.nix` host path to
     `hosts/${os}/${name}` and `mkIsoHost.nix` to `hosts/linux/${name}`
     (step 4's root/path updates otherwise unchanged).
    - Rewrite `flake.nix` enumeration per the `readHosts` sketch above;
      delete the `nixosHosts`/`darwinHosts` attrsets.
     - Delete the `users/default.nix` registry and rewire
       `_resolveHostSet.nix`: `myUsers = myLib.flake.readUsers {inherit inputs;
       dir = lib.path.append root "src/users";};` (below the `myLib`
       binding; downstream selection unchanged).
    - Verify: `nix flake show` (7 configurations, same names as before);
      eval every configuration that evaluated before the move (kkbook,
      kktab, installer, kg-continabook; kkserv/kknas/kkworker fail on
      pre-existing errors — see Current state update); smoke-test `readHosts`
      — `kktab.args.extraModules` non-empty, `installer.args.iso == true`,
      installer absent from `nixosConfigurations`, and a
       throwaway dir without `default.nix` under `src/hosts/linux/` makes
       `readHosts` throw. Smoke-test `readUsers` too: the scanned set is
       `{root, peon, wisp, kg, peasant}` (pocuser already removed), each
       value has `system` + `home`, and a leftover `src/users/default.nix`
       makes eval throw.
6. **Filesystem-as-registry for modules.**
   - `git mv src/home-modules src/modules/home` (rename to
     `src/modules/home` in one step); same
     `src/system-modules` → `src/modules/system`.
   - Carve the tiers: move the common-list entries (whole `console/`,
     `creative/`, `ide/`, `kando.nix`, …) under `home/common/`; linux-list
     (`de/`, `waybar/`, `gaming/`) under `home/linux/`; darwin-list
     (`mac/`) under `home/darwin/`. Structure inside each tier is
     preserved (the scan finds the same leaves the registries listed);
     `console/scripts/{bash,rust}` travels with its `default.nix`
     untouched (opaque to the scanner).
   - `git mv terminal/default.nix terminal/base.nix` (the
     parent-plus-children rule).
   - System side: `common.nix` → `system/common/base.nix`,
     `common-linux.nix` → `system/linux/base.nix`,
     `common-darwin.nix` → `system/darwin/base.nix`,
     `common-gui-linux.nix` → `system/gui/base.nix`; move the linux
     registry files (`gaming avahi autologin printing luks-key
     usb-luks-key`) into `system/linux/`; `sshd.nix` → `system/linux/sshd.nix`.
   - Delete `src/modules/home/default.nix` and
     `src/modules/system/default.nix`.
   - Rewire `_resolveHostSet.nix` and `mkIsoHost.nix` as specified above;
     delete installer's manual imports.
   - Verify: eval **all** configurations (step 2/5 lists) and additionally
     compare resolved module lists before/after for one host
     (`nix eval .#nixosConfigurations.kkbook.options.home-manager.sharedModules`-style
     diff, or `nixos-option`-free: diff the
     `config.system.build.toplevel.drvPath` closure counts) to catch a
     silently dropped module.
7. **Cleanup & lint.** Grep for stale paths
   (`home-modules|system-modules|myLib\.serv\b|myLib\.apps\b|scan-pkgs`);
   run `alejandra .`, `statix check`, `deadnix`; `lefthook run pre-commit`
   (commitlint/`todos` hooks).

On the real machines afterwards: `nixos-rebuild dry-activate --flake .#kkbook`
(and the other linux hosts), `darwin-rebuild check --flake .#kg-continabook`,
build the ISO.

## Risks

- **Module order becomes alphabetical** (was hand-ordered in the
  registries). Equal-priority conflicting definitions that previously
  "won" by order will now error loudly. Full-host rebuilds in step 6 are
  the detector; fix by adjusting priorities, not by re-adding lists.
- **`src/helpers/secrets.nix` relative path** (verified 2026-10-16 via
  `rg -n "" helpers/` — directory grep bypasses the `*secrets*` access
  rule): line 6 `secretsFile = ../secrets.yml;` resolves to the repo-root
  `secrets.yml` today and silently breaks when `helpers/` moves to
  `src/helpers/` in step 2 — rewrite it to `../../secrets.yml` (or an
  absolute path) **in the same commit as the move**. The file already
  sets `sops.age.keyFile = lib.mkDefault "/etc/sops/age.key"` and three
  live test `sops.secrets`; `secrets.yml` contents remain user-only and
  must be reviewed by the user.
- **ISO scope creep**: routing `mkIsoHost` through `_resolveHostSet` gives
  the installer the full linux tiers + `homeModules.linux`. All gated
  modules must be confirmed `mkIf`-gated with default-false enables;
  anything unconditional leaks into the ISO (and into eval time).
- **Dropped-module risk in step 6** is highest for
  `console/terminal` (+kitty +wezterm) — mitigated by the `base.nix`
  rename and the before/after module-list comparison.
- **Host tiers**: a host dir misplaced in the wrong tier
  (`kk*` under `darwin/`, `kg-*` under `linux/`) is not auto-corrected —
  it shows up as the host missing from the expected flake output (or
  failing eval on the wrong platform). `readHosts` throws on directories
  lacking `default.nix`, so the failure mode is loud; the tier choice
  itself is by-convention, like the module tiers.
- **Users scan is file-shape-strict**: `readUsers` throws on a leftover
  `users/default.nix`, on any subdirectory, and on a user file not
  returning `{system, home}` — a half-migrated user fails eval loudly, but
  the `default.nix` assert means deleting the registry must land **in the
  same commit** that switches the import (same discipline as
  `src/helpers/secrets.nix` in step 2).
- **Rust seed crate is live everywhere scripts are** (fish/zsh/elvish
  enable `apps.my.scripts`): `hello-world-rs` will build and land on PATH
  for those users. Intentional; opt out by disabling `apps.my.scripts`
  (there is no separate `rust.enable` — dropped by decision). Keep each crate's `Cargo.lock` in sync with its
  `Cargo.toml` — `buildRustPackage` fails on mismatch (a new dependency
  needs a regenerated lock via `cargo update`).
- **Darwin**: `homeModules.darwin` and `systemModules.darwin` are small;
  aarch64-darwin eval must be part of every verification round (no darwin
  machine needed — `nix eval` of `darwinConfigurations` suffices).
- Historical `changes/` patches reference pre-migration paths and will no
  longer apply cleanly — expected, do not "fix".

## Verification

- `nix flake show` lists all 7 configurations — 5 nixos (kkbook, kktab,
  kkserv, kknas, kkworker) + 1 iso (installer) + 1 darwin
  (kg-continabook) — plus devShells/formatter; the same names as before
  the migration, just derived from `src/hosts/{linux,darwin}/`. (kkserv,
  kknas, kkworker fail to eval on pre-existing errors — see Current state.)
- `nix eval` of `config.system.build.toplevel.drvPath` for every linux
  host that evaluated before the move (kkbook, kktab) + iso; `nix eval` of
  `darwinConfigurations.kg-continabook.system` drvPath.
- `nix eval --impure --expr` smoke tests of `readModules` (array + set
  mode, `stopOnDefault` on a program dir like `src/modules/home/common/console/git`
  returns the dir, not its `nix/` children) and of `readHosts` (attrs =
  tier dir names; `installer` only in `isoHosts`; `kktab.args.extraModules`
  non-empty; stray dir without `default.nix` throws) and of `readUsers`
  (scanned set = filename stems `{root, peon, wisp, kg, peasant}`; each
  value has `system` +
  `home`; leftover `default.nix` or a `home`-less user throws).
- Before/after module-list diff for `kkbook` (the host using the most
  feature paths: gui, serv/apps, extraModules).
- Scripts/rust merge: `nix eval` that the crate set is
  `[ "hello-world-rs" ]`;
  `nix build` the `hello-world-rs` derivation and run the resulting
  binary; confirm `hello-world-rs` is in a shell user's `home.path`.
- `alejandra .`, `statix check`, `deadnix` clean.
- Grep: no hits for `home-modules|system-modules|myLib\.serv\b|myLib\.apps\b|scan-pkgs`
  outside `plans/` and `changes/`.
- On-machine: dry-activate kkbook; `darwin-rebuild check` for
  kg-continabook; build the installer ISO once.

## Open questions

- ~~Remove the TEMP `pocvm` host (and `users/pocuser.nix`) before or after
  this migration?~~ **Resolved 2026-10-20:** already removed in commit
  `4f5ad3a` (2026-10-18).
- `enableHm` in `_resolveHostSet.nix` is asserted but unused
  (`# TODO: handle enableHm == false`) — implement while touching the
  file, or leave?
- Should `src/modules/system/gui/` ever get a linux-only counterpart for
  home (e.g. a `home/linux-gui/` for noctalia-adjacent modules), or is
  the input-wired noctalia module enough?
