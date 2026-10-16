# Migration: src/ layout, filesystem-as-registry, auto-loading modules & lib

Status: **proposed** — not started.
Date: 2026-10-16

## Problem

Module discovery is hand-maintained in three registries that duplicate (and
drift from) the filesystem:

- `home-modules/default.nix` — hand-written `{common, linux, darwin}` lists
  (~28 entries in `common` alone).
- `system-modules/default.nix` — same shape; its `common` list is empty and
  the four `common*.nix` files are imported by **explicit path** from
  `lib/flake/_resolveHostSet.nix:54-68` instead.
- `lib/default.nix` — hand-written attrset mirroring the `lib/` directory
  tree, with naming shims (`scanPkgs`, `validate`, `serv`).

Consequences: adding a module means editing a registry by hand; modules that
are not in a registry are invisible (two orphans existed — one is merged
away during this migration, the other becomes auto-loaded; see below);
the lib attrset must be kept in sync with the directory tree by hand; and
`_resolveHostSet.nix` carries a dangling `import (root + "/services")` that
only survives because nothing forces the specialArg.

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
  module keeps `apps.my.scripts.{enable}` and gains
  `apps.my.scripts.rust.enable` (default `true`): every crate directory
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
  `using.nix`) and `src/users/` (name → `{system, home}` shape requires
  per-file import with `inputs`, not plain module paths). Possible future
  work, out of scope here.

## Current state (facts verified 2026-10-16)

- `flake.nix:48` — `flakeLib = import ./lib/flake;`. Hosts declared as data
  (`nixosHosts`, `darwinHosts`) and mapped through
  `flakeLib.mkLinuxHost` / `mkDarwinHost`; `isoConfigurations.installer`
  via `mkIsoHost`.
- `lib/flake/{mkLinuxHost,mkDarwinHost,mkIsoHost}.nix` — `root ? ../..`
  (3 occurrences; becomes `../../..` after the move).
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
- Latent bug: `lib/services/mkContainerService.nix:178` calls
  `myLib.ensureDirExists` — that attr does not exist (it is
  `myLib.file.ensureDirExists`); fires only for volumes with
  `create = true`. Drive-by fix during migration.
- Relative cross-references that must be updated on move (complete list):
  - `flake.nix:48` (`./lib/flake`), `flake.nix:107` (`./overlays`);
  - `hosts/installer/default.nix:7-8` (`../../pkgs/{nix-conf-clone,nix-conf-install}`),
    `:13-14` (`../../system-modules/{common,common-linux}.nix`);
  - `home-modules/ide/helix/nix/hxr.nix:2` (`../../../../pkgs/hxr`);
  - path strings inside `lib/flake/{_resolveHostSet,mkIsoHost}.nix`
    (`"/users"`, `"/system-modules"`, `"/home-modules"`, `"/helpers"`,
    `"/lib"`, `"hosts/${name}"`).
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
  hosts/ users/ helpers/ overlays/ pkgs/   # pure moves
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
- `ensureDirExists` stays under `myLib.file`; fix the one bad call in
  `mkContainerService.nix:178`.
- `flake/` becomes `myLib.flake` — but `flake.nix` keeps its own direct
  import: `flakeLib = import ./src/lib/flake {};` (called with empty args,
  which the normalized `flake/default.nix` ignores).

## mk*Host / flake wiring changes

- `lib/flake/mkLinuxHost.nix`, `mkDarwinHost.nix`, `mkIsoHost.nix`:
  `root ? ../..` → `root ? ../../..`; path strings
  `"/system-modules"` → `"/src/modules/system"`, `"/home-modules"` →
  `"/src/modules/home"`, `"/users"` → `"/src/users"`, `"/helpers"` →
  `"/src/helpers"`, `"/lib"` → `"/src/lib"`, `"hosts/${name}"` →
  `"src/hosts/${name}"`.
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
  - `myLib = import (lib.path.append root "src/lib") {inherit pkgs;};`
    (same call shape — `src/lib/default.nix` is now the autoloader);
  - `home-manager.sharedModules` logic unchanged
    (`homeModules.common ++ homeModules.${os}` + noctalia when gui).
- `mkIsoHost.nix` — **decision:** route through `_resolveHostSet.nix`
  (`os = "linux"`, `arch = "x86"`, `gui = false`, `users = ["peasant"]`)
  and delete its duplicated wiring; delete
  `hosts/installer/default.nix`'s manual imports of
  `system-modules/{common,common-linux}.nix` (the linux tier already
  contains `base.nix`). Cost: the installer gains the full linux system
  and home tiers as option-defined-but-disabled modules (eval weight only
  — gated by `mkIf`; must be confirmed in verification). Fallback if that
  proves unacceptable: keep `mkIsoHost` separate, just switch its two
  registry imports to `readModules` array mode on the `common` + `linux`
  `base.nix` files.
- `flake.nix`: `import ./lib/flake` → `import ./src/lib/flake {}`;
  `import ./overlays` → `import ./src/overlays`.
- `hosts/installer/default.nix`: `../../pkgs/...` → `../../../src/pkgs/...`;
  `home-modules/ide/helix/nix/hxr.nix`: `../../../../pkgs/hxr` →
  `../../../../../../src/pkgs/hxr` (adjust depth: file ends up at
  `src/modules/home/common/ide/helix/nix/hxr.nix`, so `pkgs` is
  `../../../../../src/pkgs/hxr` — recompute exactly during the move).

## Migration steps

Ordered so every step is independently eval-able; commit per step.

1. **Merge the rust CLI wrapper into the scripts module.** (Already
   applied in the working tree on 2026-10-16 at the old paths; keep as its
   own commit.) Rewrite
   `home-modules/console/scripts/default.nix`: keep the `bash/` deployment
   under `apps.my.scripts.enable`, add `apps.my.scripts.rust.enable`
   (default `true`) that builds every `rust/*/` directory containing a
   `Cargo.toml` via `pkgs.rustPlatform.buildRustPackage`
   (`cargoLock.lockFile`, `lib.cleanSource`, `meta.mainProgram = name`).
   Add the seed crate `rust/hello-world-rs/`
   (`Cargo.toml` edition 2021, hand-written dependency-free `Cargo.lock`
   v4, `src/main.rs`, plus `rust/.gitignore` containing `target/`).
   Delete `home-modules/scripts/` (fully merged away). Verify: eval
   kkbook and confirm `hello-world-rs` shows up in peon's `home.path`
   (`nix eval .#nixosConfigurations.kkbook.config.home-manager.users.peon.home.path`)
   or in the built toplevel closure.
2. **Relocate (pure move, no semantics).** `git mv lib hosts users helpers
   overlays pkgs home-modules system-modules src/` (create `src/` first).
   Update the path list under "Current state" (flake.nix, mk*Host root
   defaults + path strings, installer, hxr.nix). Verify:
   `nix eval .#nixosConfigurations.kkbook.config.system.build.toplevel.drvPath`
   and the same for `kktab kkserv kknas kkworker installer`,
   `darwinConfigurations.kg-continabook`, plus `nix flake show`.
3. **Add the scanner.** Create `src/lib/fs.nix`; temporarily add
   `fs = import ./fs.nix parsedArgs;` to the old `src/lib/default.nix`.
   Verify with `nix eval` that set mode on `src/modules`… (still old dirs
   at this point — smoke-test on `src/lib` instead) returns the expected
   shape.
4. **Autoload the lib.** Normalize `validators/default.nix` and
   `flake/default.nix` to `args:` functions; `git mv scan-pkgs.nix
   scanPkgs.nix`; replace `src/lib/default.nix` with the autoloader;
   rename in `hosts/kkbook/default.nix`: `myLib.serv.*` → `myLib.services.*`,
   `myLib.apps.*` → `myLib.services.apps.*`; fix
   `mkContainerService.nix:178` → `myLib.file.ensureDirExists`. Verify:
   rebuild `kkbook` (the only host exercising `serv`/`apps`).
5. **Filesystem-as-registry for modules.**
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
   - Verify: eval **all** configurations (step 2 list) and additionally
     compare resolved module lists before/after for one host
     (`nix eval .#nixosConfigurations.kkbook.options.home-manager.sharedModules`-style
     diff, or `nixos-option`-free: diff the
     `config.system.build.toplevel.drvPath` closure counts) to catch a
     silently dropped module.
6. **Cleanup & lint.** Grep for stale paths
   (`home-modules|system-modules|myLib\.serv\b|myLib\.apps\b|scan-pkgs`);
   run `alejandra .`, `statix check`, `deadnix`; `lefthook run pre-commit`
   (commitlint/`todos` hooks).

On the real machines afterwards: `nixos-rebuild dry-activate --flake .#kkbook`
(and the other linux hosts), `darwin-rebuild check --flake .#kg-continabook`,
build the ISO.

## Risks

- **Module order becomes alphabetical** (was hand-ordered in the
  registries). Equal-priority conflicting definitions that previously
  "won" by order will now error loudly. Full-host rebuilds in step 5 are
  the detector; fix by adjusting priorities, not by re-adding lists.
- **`src/helpers/secrets.nix` is unreadable** (permission rule denies
  `*secrets*`). If it references secrets by path relative to the repo root
  (e.g. `../secrets/...`), moving `helpers/` → `src/helpers/` silently
  breaks those paths at eval. Inspect it during step 2 (as the user) and
  update references, or switch to absolute `/etc/nixos/secrets/...` paths.
- **ISO scope creep**: routing `mkIsoHost` through `_resolveHostSet` gives
  the installer the full linux tiers + `homeModules.linux`. All gated
  modules must be confirmed `mkIf`-gated with default-false enables;
  anything unconditional leaks into the ISO (and into eval time).
- **Dropped-module risk in step 5** is highest for
  `console/terminal` (+kitty +wezterm) — mitigated by the `base.nix`
  rename and the before/after module-list comparison.
- **Rust seed crate is live everywhere scripts are** (fish/zsh/elvish
  enable `apps.my.scripts`): `hello-world-rs` will build and land on PATH
  for those users. Intentional; set `apps.my.scripts.rust.enable = false`
  per-user to opt out. Keep each crate's `Cargo.lock` in sync with its
  `Cargo.toml` — `buildRustPackage` fails on mismatch (a new dependency
  needs a regenerated lock via `cargo update`).
- **Darwin**: `homeModules.darwin` and `systemModules.darwin` are small;
  aarch64-darwin eval must be part of every verification round (no darwin
  machine needed — `nix eval` of `darwinConfigurations` suffices).
- Historical `changes/` patches reference pre-migration paths and will no
  longer apply cleanly — expected, do not "fix".

## Verification

- `nix flake show` lists all 8 configurations (5 nixos + 1 iso + 1 darwin +
  devShells/formatter).
- `nix eval` of `config.system.build.toplevel.drvPath` for every linux
  host + iso; `nix eval` of `darwinConfigurations.kg-continabook.system`
  drvPath.
- `nix eval --impure --expr` smoke tests of `readModules` (array + set
  mode, `stopOnDefault` on a program dir like `src/modules/home/common/console/git`
  returns the dir, not its `nix/` children).
- Before/after module-list diff for `kkbook` (the host using the most
  feature paths: gui, serv/apps, extraModules).
- Scripts/rust merge: `nix eval` that `apps.my.scripts.rust.enable`
  defaults to `true` and that the crate set is `[ "hello-world-rs" ]`;
  `nix build` the `hello-world-rs` derivation and run the resulting
  binary; confirm `hello-world-rs` is in a shell user's `home.path`.
- `alejandra .`, `statix check`, `deadnix` clean.
- Grep: no hits for `home-modules|system-modules|myLib\.serv\b|myLib\.apps\b|scan-pkgs`
  outside `plans/` and `changes/`.
- On-machine: dry-activate kkbook; `darwin-rebuild check` for
  kg-continabook; build the installer ISO once.

## Open questions

- Keep `isoConfigurations` as a bespoke output, or fold the installer into
  `nixosConfigurations` now that `mkIsoHost` shares `_resolveHostSet`?
- Autoload `src/users/` later? (`readModules` set mode + per-file
  `import` with `inputs` would produce
  `{peon = {system = ...; home = ...}; ...}` if each user file returns the
  attrset directly — currently they are wrapped in `{...}@ inputs:`.)
- `enableHm` in `_resolveHostSet.nix` is asserted but unused
  (`# TODO: handle enableHm == false`) — implement while touching the
  file, or leave?
- Should `src/modules/system/gui/` ever get a linux-only counterpart for
  home (e.g. a `home/linux-gui/` for noctalia-adjacent modules), or is
  the input-wired noctalia module enough?
