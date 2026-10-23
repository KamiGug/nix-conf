# sops-nix: Modular secrets management

Status: **done** (2026-10-21) — `nixos-rebuild dry-activate` and all plan verification steps pass.

Secrets are declared by dropping an encrypted YAML file into `secrets/`. A lib
function walks that directory at evaluation time and returns a nested
`config.sops.secrets` attrset whose **namespace mirrors the filesystem tree**
(`secrets/users/darwin/post2016/dude.yml` + key `password_hash` →
`config.sops.secrets.users.darwin.post2016.dude.password_hash`). There is **no
imposed directory structure**, recursion is **unconditional** (to the leaves, no
`default.nix` stop-rule), and the result is **assigned explicitly at the call
site** — the function returns a plain value, it is **not** a module and is **not**
wired through the NixOS `imports` mechanism.

Per-secret sops options are passed by the caller from host/user config (default
`{}`). Any option naming a secret that no `.yml` file produces is a **hard
evaluation error** (`throw`), so a typo is never silently discarded.

## 0. Verified starting state

Ground truth on disk (checked before writing this plan):

| Path | State |
|------|-------|
| `src/helpers/default.nix` | list: `[ ./secrets.nix ./using.nix ]` — imported by every host |
| `src/helpers/secrets.nix` | legacy module, 23 lines, uses `../../secrets.yml` |
| `src/lib/default.nix` | autoloads every `src/lib/*.nix` (except `default`) via `readModules` |
| `src/lib/secrets.nix` | **does not exist** |
| `src/helpers/secrets/` | **does not exist** |
| `secrets/` | **exists** (directory at repo root) |
| `secrets.yml`, `sops.yml` | **exist** (legacy, repo root) |
| `_resolveHostSet.nix:47` | `myLib = import (root + "/src/lib") { inherit pkgs; }` |

## 1. The contract

```nix
# src/lib/sops.nix  ->  myLib.sops
{ lib, pkgs, ... }: {
  buildSecrets = root: options ? {}: { <nested sops.secrets attrset> };
}
```

- **Returns only the `sops.secrets` attrset.** No module, no `imports`, no
  assertions option (validation throws inline).
- `root` — path to the `secrets/` directory (e.g. `../../secrets`).
- `options` — per-secret sops options, keyed by the same tree; **defaults to `{}`**.
- The caller assigns the result and owns `sops.age.keyFile`
  (default `/etc/sops/age.key`, overridable per host/user via `mkDefault`).
- **No `imports`.** The secrets machinery is never registered via the NixOS
  module `imports` mechanism, never listed in `src/helpers/default.nix`.

## 2. Layout

`secrets/` holds **encrypted YAML only — no `.nix` files, ever**. Its sub-tree is
free-form; whatever dirs the user creates become namespace segments.

```
secrets/
├── hosts/
│   └── kkbook.yml
├── services/
│   └── db/postgres.yml
├── users/
│   └── darwin/post2016/dude.yml
└── ssh-public.yml
```

Code lives in exactly **one new file**:

```
src/lib/sops.nix          # NEW: myLib.sops.buildSecrets
```

## 3. Steps

### Step 1 — Implement `src/lib/sops.nix`
A lib module (auto-loaded by `src/lib/default.nix` → `myLib.sops`) exposing
`buildSecrets`:

```nix
{ lib, pkgs, ... }: {
  buildSecrets = root: options ? {}:
    let
      # YAML -> JSON index at eval time (yq-go is in the devShell).
      # sops leaves top-level keys plaintext; only values are ENC[...]. No decryption.
      index = file:
        builtins.fromJSON (builtins.readFile (pkgs.runCommand "sops-index.json"
          { nativeBuildInputs = [ pkgs.yq-go ]; } ''
            yq -o=json 'del(.sops)' ${file} > $out
          ''));

      isSecret = name: kind:
        kind == "regular"
        && (lib.hasSuffix ".yml" name || lib.hasSuffix ".yaml" name)
        && !(lib.hasPrefix "_" name);

      # Unconditional recursion to the leaves (no default.nix stop-rule).
      walk = dir:
        let entries = builtins.readDir dir; in
        lib.concatMap (name:
          let p = dir + "/${name}"; in
          if entries.${name} == "directory" then walk p
          else lib.optional (isSecret name entries.${name}) p)
        (builtins.attrNames entries);

      # "…/secrets/users/darwin/post2016/dude.yml" -> ["users" "darwin" "post2016" "dude"]
      relSegments = p:
        lib.splitString "/"
          (lib.removeSuffix ".yml" (lib.removeSuffix ".yaml"
            (lib.removePrefix (toString root + "/") (toString p))));

      # nested { <seg...>.<key> = { sopsFile; format; key; }; }
      expand = p:
        let
          doc  = index p;                  # .sops already stripped
          segs = relSegments p;
        in map (k: lib.setAttrByPath (segs ++ [ k ]) {
             sopsFile = p;
             format = "yaml";
             key = k;
           }) (builtins.attrNames doc);

      pieces = lib.concatMap expand (walk root);
      discovered = lib.foldl' lib.recursiveUpdate {} pieces;

      # --- validation (throw, not assertions) ---
      flatten = set: prefix:
        lib.concatLists (lib.mapAttrsToList (n: v:
          if builtins.isAttrs v && !(v ? sopsFile)
          then flatten v (prefix ++ [ n ])
          else [ (lib.concatStringsSep "." (prefix ++ [ n ])) ]) set);

      discoveredNames = flatten discovered [];
      optionNames     = flatten options [];
      stray           = lib.subtractLists discoveredNames optionNames;
      dupes           = discoveredNames -- lib.unique discoveredNames;

      built = lib.recursiveUpdate discovered options;   # options win
    in
      if stray != []
      then throw "secrets: options reference unknown secret(s): ${lib.concatStringsSep ", " stray}"
      else if dupes != []
      then throw "secrets: name collision: ${lib.concatStringsSep ", " dupes}"
      else built;
}
```

### Step 2 — Call it from each host/user that needs secrets
Explicit assignment; no `imports`. Minimal case (no options):

```nix
{ config, lib, myLib, ... }:
{
  sops.secrets = myLib.sops.buildSecrets ../../secrets;
  sops.age.keyFile = lib.mkDefault "/etc/sops/age.key";
}
```

With per-secret options from the host/user config:

```nix
{ config, lib, myLib, ... }:
{
  sops.secrets = myLib.sops.buildSecrets ../../secrets {
    users.peon.password_hash = { neededForUsers = true; };
    hosts.kkbook.ssh_host_key = {
      mode = "0400"; owner = "root"; group = "root";
      restartUnits = [ "sshd.service" ];
    };
  };
  sops.age.keyFile = lib.mkDefault "/etc/sops/age.key";
}
```

### Step 3 — Delete the legacy module
```bash
rm src/helpers/secrets.nix
```
Then remove its entry from `src/helpers/default.nix`:
```nix
# before
[ ./secrets.nix ./using.nix ]
# after
[ ./using.nix ]
```
No shim. The hard-coded names (`peon-password`, `nixos-secret-test`,
`hm-secret-test`) are re-expressed as YAML keys in `secrets/**/*.yml` and, where
needed, as options at the call sites.

### Step 4 — Migrate the three test secrets into data files
For each legacy name, create the matching `secrets/.../*.yml` with the value as a
top-level YAML key, then `sops`-encrypt it:

```bash
# user-only: requires the age key; agent cannot read these files
sops secrets/users/peon.yml            # key: password_hash
sops secrets/services/nixos-test.yml   # key: test
sops secrets/services/hm-test.yml      # key: test
```

### Step 5 — Repoint password-hash consumers
```nix
users.users.peon.hashedPasswordFile =
  config.sops.secrets.users.peon.password_hash.path;
```
Find them with:
```bash
rg -n 'hashedPassword|sops\.secrets' src/
```

### Step 6 — Repoint `.sops.yaml` recipients
Path-based `creation_rules` covering the new tree (admin key is the only known ID;
per-host recipients appended by the user once each key exists):

```yaml
keys:
  - &admin age1dmawdc96sk8yent9u9wvmwzxk6ean4zpkq6n7msx952ppnnxj90q5utu5u
creation_rules:
  - path_regex: '^secrets/.*\.ya?ml$'
    key_groups: [{ age: [*admin] }]
```

### Step 7 — Remove the legacy files
```bash
rm secrets.yml sops.yml
```
Only after `rg -n 'secrets\.yml|sops\.yml' src/` returns nothing.

### Step 8 — Public metadata must not be walked
Put public metadata at `secrets/_ssh-public.yml` (leading `_` → skipped by
`isSecret`) or outside `secrets/` entirely.

### Step 9 — Update the plans table
Edit `plans/README.md` row 3: status `proposed` → `in progress` → `done`, and
rewrite the `Scope` cell to the tree-preserving description.

## 4. Naming rules (authoritative)

- Namespace = path of the `.yml` under `secrets/`, minus extension, split on `/`,
  then the YAML top-level key as the final segment.
  - `secrets/services/db/postgres.yml` + key `password`
    → `config.sops.secrets.services.db.postgres.password`
  - `secrets/users/darwin/post2016/dude.yml` + key `password_hash`
    → `config.sops.secrets.users.darwin.post2016.dude.password_hash`
- **No `/`→`-` flattening. No `__` joining.** The tree is preserved.
- `.yml` and `.yaml` both accepted; extension trimmed.
- Files beginning with `_` are skipped.
- The reserved `sops` key is stripped by `del(.sops)` in the `yq` call.

## 5. Per-secret options (from sops-nix)

Any sops-nix secret option is valid at the leaf: `neededForUsers`, `mode`,
`owner`, `group`, `restartUnits`, `reloadUnits`, `path`, etc. `sopsFile` and `key`
are supplied by the walker; caller options are merged over them
(`lib.recursiveUpdate discovered options` — options win).

## 6. Verification

```bash
# 1. Plain host still evaluates.
nixos-rebuild dry-activate --flake .#kkbook

# 2. A host with no secrets file present still evaluates (no error).
nixos-rebuild dry-activate --flake .#kkedge

# 3. Nested names appear as expected (no decryption, no age key needed).
nix eval --impure --raw --expr \
  'builtins.concatStringsSep "\n" (builtins.attrNames
     ((import ./src/lib {pkgs = import <nixpkgs> {};}).sops.buildSecrets ./secrets {}))'

# 4. Guards:
#    - add a bogus leaf to options -> eval must throw "unknown secret(s)"
#    - two files producing the same name  -> eval must throw "collision"

# 5. REPL sanity: nested lookup resolves.
nix repl -f flake.nix
# > :lf .
# > nixosConfigurations.kkbook.config.sops.secrets.users.peon.password_hash.path
```

## 7. Open questions

None — resolved during planning:

1. **`dupes` computation.** Leaf names are collected via the `flatten` helper
   (keyed off `? sopsFile`) and compared with `lib.unique`; a mismatch throws.
2. **`yq` at eval time.** `pkgs.yq-go` is the correct attribute and works inside
   `runCommand` at eval.
3. **Naming.** The lib file is `src/lib/sops.nix`, so it is `myLib.sops`
   (not `myLib.secrets`); no `secrets.secrets` shadowing.

## 8. Dependencies

- `plans/migration.md` — `src/` layout, `readModules`/`readHosts`/`readUsers`,
  lib autoloading; the reason `src/lib/sops.nix` becomes `myLib.sops`
  without extra wiring.
- `plans/homelab.md` — service ownership and `myLib.services`, which decides
  which `secrets/services/*.yml` files exist.

## 9. Deviations from the original plan

- **Flat `"/"`-joined names instead of nested attrsets.** The plan's §4 showed
  `config.sops.secrets.services.db.postgres.password`. In practice, sops-nix's
  `sops.secrets` is declared as `lib.types.attrsOf secretType` — the module
  system rejects nested attrsets (error: "The option `sops.secrets.users.peon' does
  not exist"). The tree is therefore preserved inside the attribute name
  (`services/db/postgres/password`). Nothing is flattened to `-` or `__`.
- **`buildSecrets` signature uses an attrset pattern.** The plan wrote
  `buildSecrets = root: options ? {}:` — default arguments on positional
  parameters are invalid Nix syntax. Changed to `buildSecrets = {root, options ? {}}:`.
- **`ananas-priv-key` / `github-priv-key` migrated.** The plan's Step 4 only
  listed the three test secrets; the two SSH private keys were silently omitted.
  They are now at `secrets/ssh/ananas.yml` (`private_key`) and `secrets/ssh/github.yml`
  (`private_key`) to avoid data loss.
- **`secrets/common/API_keys.yml` renamed to `_API_keys.yml`** (leading `_` =
  skipped by walker) and rewritten as valid YAML. The original was invalid YAML
  (parser error at L4).
- **Call sites at `src/modules/system/common/secrets.nix` and
  `src/modules/home/common/secrets.nix`.** These use the filesystem-as-registry
  convention (`myLib` from `specialArgs`/`extraSpecialArgs`), not the old
  `src/helpers/secrets.nix` module loaded via `src/helpers/default.nix` imports.
- **`.sops.yaml` instead of `sops.yml`.** Modern sops 3.x convention; the
  `creation_rules.path_regex` covers `^secrets/.*\.ya?ml$`. Legacy `sops.yml`
  and `secrets.yml` deleted.
