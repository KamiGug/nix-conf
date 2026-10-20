# sops-nix: Modular secrets management

Status: **proposed** — depends on `plans/migration.md` and `plans/homelab.md`.

This plan refactors the repository's secrets management into a modular,
auto-discovering sops-nix configuration. It builds on the filesystem-as-registry
conventions established in `plans/migration.md` and the service ownership
definitions in `plans/homelab.md`.

## 1. Overview

The secrets layout is converted from a single `secrets.yml` + `sops.yml` at the
repo root into a directory-based structure under `secrets/` that is auto-discovered
by a `helpers/secrets/default.nix` Nix module. Each host and each service gets its
own encrypted YAML file; recipient metadata is tracked per-file so that decryption
is restricted to the authorised principals.

The `.sops.yaml` master configuration includes one age recipient for the admin
(shared across all hosts) and one recipient per host. A separate `ssh-public.yml`
maps public keys to names without distributing private keys.

## 2. Secrets Directory Structure

```
secrets/
├── common/
│   └── API_keys.yml      # AI service API keys (OpenAI, Anthropic, etc.)
├── hosts/
│   ├── kg-continabook.yml
│   ├── kkbook.yml
│   ├── kkedge.yml       <--- newly added (was missing)
│   ├── kknas.yml
│   ├── kkphone.yml
│   ├── kkserv.yml
│   ├── kktab.yml
│   └── kkworker.yml
├── services/
│   ├── authentik.yml
│   ├── db/postgres.yml
│   ├── forgejo.yml
│   ├── netbird.yml
│   ├── nextcloud.yml
│   └── nfs.yml
├── ssh-public.yml
└── users/
    ├── peon.yml
    └── wisp.yml
```

- **Host secrets** (`secrets/hosts/*`): Each file contains the secrets for one
  machine. The filename matches the hostname. Per-file age recipients are listed
  in the sops file header (`.sops.yaml` creation_rules). A host's own secret is
  decryptable by that host's age key plus the admin key.
- **Service secrets** (`secrets/services/*`): Independent of host secrets; each
  service file contains the credentials consumed by the service regardless of
  which host it runs on.
- **User secrets** (`secrets/users/*`): Credentials for individual users.
  - `peon`: `kkbook`, `kktab`
  - `wisp`: `kkphone`, `kknas`, `kkworker`, `kkserv`, `kkedge`
- **SSH public keys** (`secrets/ssh-public.yml`): Maps key names to key data and
  the hosts/users authorised to use them. Private keys never leave the source host.

## 3. Encryption Policy & Recipients

`.sops.yaml` (at repo root) — do not invent new age key IDs; document missing
keys and manual steps.

```yaml
keys:
  - &admin_key age1dmawdc96sk8yent9u9wvmwzxk6ean4zpkq6n7msx952ppnnxj90q5utu5u   # admin / master
creation_rules:
  - path_regex: secrets/hosts/.*\.yml$
    age: *admin_key
    sops_key: /etc/sops/age.key
  - path_regex: secrets/services/.*\.yml$
    age: *admin_key
    sops_key: /etc/sops/age.key
  - path_regex: secrets/users/.*\.yml$
    age: *admin_key
    sops_key: /etc/sops/age.key
```

**Per-host recipients**: Each `secrets/hosts/<name>.yml` sops file must list the
admin key **plus** the age recipient for the corresponding host. The host recipient
is identified by the age key fingerprint that matches that machine's `/etc/sops/age.key`.
If a host needs to decrypt its own secret, its age key must be listed. The admin
key is always listed so the master can decrypt anything.

- Host secrets: `hosts/<name>.yml` → recipients = `[admin_key, <host_age_key>]`
- Service secrets: `services/<name>.yml` → recipients as determined by required
  hosts (see Section 4)
- User secrets: `users/peon.yml` → recipients = `[admin_key]` (peon can decrypt
  kkbook and kktab); `users/wisp.yml` → recipients = `[admin_key]` (wisp can
  decrypt kkphone, kknas, kkworker, kkserv, kkedge)

**Do not invent recipient keys**: The only age key ID known to exist is the admin
key above. Any host whose age key is not yet in the known recipient list must be
added manually (see Section 6).

## 4. Service Ownership & Secret Consumers

Per `plans/homelab.md`, service secrets are owned by specific hosts. Recipients
are assigned per-service based on the intended owner. Do not assign recipients
without confirming the service actually runs on that host.

| Service | Owner Host | Secrets contained | Recipients |
|---|---|---|---|
| **Nextcloud** | `kknas` | DB password, OIDC client secret, admin password | `kknas_age_key`, `admin_key` |
| **Jellyfin** | `kknas` | Media DB credentials | `kknas_age_key`, `admin_key` |
| **Navidrome** | `kknas` | DB credentials | `kknas_age_key`, `admin_key` |
| **NFS** | `kknas` | Export/auth secrets | `kknas_age_key`, `admin_key` |
| **All database secrets** | `kknas` | PostgreSQL users/passwords for all services | `kknas_age_key`, `admin_key` |
| **Forgejo** | `kkworker` | DB password, repository config | `kkworker_age_key`, `admin_key` |
| **Excalidraw/Excalidash** | `kkworker` | Config/DB secrets | `kkworker_age_key`, `admin_key` |
| **Conduit/Element Call** | `kkworker` | Chat server secrets | `kkworker_age_key`, `admin_key` |
| **Taiga** | `kkworker` | Project/DB secrets | `kkworker_age_key`, `admin_key` |
| **Penpot** | `kkworker` | Design/secrets | `kkworker_age_key`, `admin_key` |
| **Wiki.js** | `kkworker` | DB password, OIDC | `kkworker_age_key`, `admin_key` |
| **Yumtrack** | `kkworker` | Yum repo credentials | `kkworker_age_key`, `admin_key` |
| **NetBird** | `kkserv` | VPN node config | `kkserv_age_key`, `admin_key` |
| **Bind9/Pi-hole** | `kkserv` | DNS/DHCP secrets | `kkserv_age_key`, `admin_key` |
| **Nginx** | `kkserv` | TLS certs, proxy secrets | `kkserv_age_key`, `admin_key` |
| **Smallstep CA** | `kkserv` | CA config, JWKs | `kkserv_age_key`, `admin_key` |
| **Authentik** | — | **Must include PostgreSQL username and password** as required by the actual deployment. Owner: `kknas` (database) + `kkserv` (frontend). Recipients: `kknas_age_key`, `kkserv_age_key`, `admin_key`. | |

*Missing keys*: If a host age key is not yet known, document it in the "Manual
steps" section (Section 6) and do not add it to the `.sops.yaml` creation_rules
until the key fingerprint is verified.

## 5. Automatic Discovery

`helpers/secrets.nix` is refactored into a modular directory structure:

```
helpers/
└── secrets/
    ├── default.nix    # module entry point (auto-discovers all secret files)
    ├── hosts/         # per-host secret definitions (auto-discovered)
    │   ├── default.nix
    │   ├── kg-continabook.nix
    │   ├── kkbook.nix
    │   ├── kkedge.nix   <--- newly added
    │   ├── kknas.nix
    │   ├── kkphone.nix
    │   ├── kkserv.nix
    │   ├── kktab.nix
    │   └── kkworker.nix
    ├── services/      # per-service secret definitions (auto-discovered)
    │   ├── default.nix
    │   ├── authentik.nix
    │   ├── db/
    │   │   └── postgres.nix
    │   ├── forgejo.nix
    │   ├── netbird.nix
    │   ├── nextcloud.nix
    │   └── nfs.nix
    ├── ssh-public.yml # public key mappings (explicit, not auto-discovered)
    └── users/         # per-user secret definitions (auto-discovered)
        ├── default.nix
        ├── peon.nix
        └── wisp.nix
```

### `helpers/secrets/default.nix`

The module exports `config.secrets` as an attrset of `{hosts, services, users}`
derived by walking the `secrets/` directory tree. It supports both NixOS and
Home Manager.

**Walker logic** (analogue of `readModules` from `plans/migration.md`):

- Scan `secrets/hosts/`, `secrets/services/`, `secrets/users/` recursively.
- For each `.yml` file found, produce a Nix module entry keyed by the filename stem.
- **Nested directories** (e.g. `secrets/services/db/postgres.yml`) are descended
  into; the relative path from `secrets/` becomes part of the secret name.
- **Stop at `default.nix`**: if a subdirectory contains a `default.nix`, treat it
  as an opaque module and do not descend further.
- **Host-aware filtering**: each module may declare which host(s) it is authorised
  for via a `hosts` attribute. The caller filters accordingly.
- **Home Manager support**: when running under Home Manager, the same walker
  produces `home-manager.secrets` entries keyed by the same names.
- **Secret naming**: the path relative to `secrets/` is used as a prefix: `/` is
  replaced with `-` (dash), and `.yml`/`.yaml` is trimmed from the filename.
  For each top-level secret key read inside that YAML file, the final sops
  secret name is `<path-prefix>__<key-name>` — the path prefix is joined to the
  secret name (read from the file) with `__` (double underscore). So
  `secrets/services/db/postgres.yml` containing key `password` produces
  sops secret `services-db-postgres__password`, and
  `secrets/hosts/kkbook.yml` containing key `ssh-host-key` produces
  `hosts-kkbook__ssh-host-key`. Extension trimming matches `.ya?ml`
  (both `.yml` and `.yaml`).

The module path is `helpers/secrets/default.nix` and it is included via the
existing `helpers` import in `_resolveHostSet.nix` (updated path from
`../helpers/secrets.nix` to the new directory structure).

## 6. Migration

### 6.1. Preserve existing values

1. **Dump existing `secrets.yml` values**: before any restructuring, transcribe
   every key/value from the root `secrets.yml` into the new per-file structure.
   The existing values are:
   - User-secrets only (confirmed from grep of `secrets.yml:6` = `sops:`).
   - Three test sops secrets in `helpers/secrets.nix`: `peon-password`,
     `nixos-secret-test`, `hm-secret-test`.

2. **Create new file layout**: for each existing secret, create the appropriate
   `secrets/hosts/<name>.yml`, `secrets/services/<name>.yml`, or
   `secrets/users/<name>.yml` file. Keep the exact same sops key references.

3. **Update `.sops.yaml`**: add per-host creation_rules as described in Section 3.
   The existing `sops.yml` creation_rules for `secrets\.ya?ml` remain valid for
   host and user secrets; service secrets get their own rules.

4. **Update `helpers/secrets.nix`**: change `secretsFile = ../secrets.yml;` to
   point at the new module structure. The new default.nix walks the directory
   tree and does not rely on a single flat file.

### 6.2. Incorporate `kkedge`

`kkedge` is currently missing from the host secret files. During migration:

1. Create `secrets/hosts/kkedge.yml` with the appropriate secrets for that host.
2. Add the age recipient for `kkedge` to the file's sops header (admin key +
   kkedge's age key, once provisioned).
3. If `kkedge` runs any of the services listed in Section 4, add the relevant
   service secrets to `secrets/services/` and assign recipients per the table.
4. Update any host-level imports that reference the old flat secret structure.

### 6.3. Verification after migration

- `nix eval` or `nixos-rebuild dry-activate` on each host (kkbook, kktab,
  kkserv, kknas, kkworker, kg-continabook) should succeed without sops
  decryption errors.
- `rg -n "secrets.yml"` should find zero results in tracked Nix files (the legacy
  file has been removed or is only referenced in migration history).
- No plaintext secret values appear in any `.nix` file or `diff` output.

### 6.4. Remove legacy `secrets.yml`

After all values are transcribed and verified, `rm secrets.yml`. Update any
remaining references in the flake or host configs.

## 7. Validation

After implementing this plan, run the following checks:

### 7.1. Nix evaluation

```bash
# Verify the flake evals on all hosts
nixos-rebuild dry-activate --flake .#kkbook
nixos-rebuild dry-activate --flake .#kktab
nixos-rebuild dry-activate --flake .#kknas
nixos-rebuild dry-activate --flake .#kkserv
nixos-rebuild dry-activate --flake .#kkworker
darwin-rebuild switch --flake .#kg-continabook
```

All should complete without errors related to missing sops secrets or unknown
recipients.

### 7.2. Secret discovery coverage

```bash
# Ensure every secret file under secrets/ is discovered by the module
nix eval --impure --expr "builtins.length (import ./helpers/secrets/default.nix {})"
```
The result should equal the total number of `.yml` files in `secrets/`.

### 7.3. Host-specific access

- `kkbook` should only decrypt secrets in `secrets/hosts/kkbook.yml` and
  `secrets/users/{peon,wisp}` files it is authorised for.
- `wisp` should only decrypt secrets in `secrets/hosts/wisp.yml` (if it has one)
  and `secrets/users/wisp.yml` plus `secrets/services/` for services it runs.
- `kkedge` coverage: verify `secrets/hosts/kkedge.yml` is discovered and its
  recipient is listed (even if the key is not yet active, the file exists).

### 7.4. Legacy reference removal

```bash
grep -r "secrets.yml" --include="*.nix" --include="*.md" /etc/nixos/ | grep -v ".bak" || echo "No remaining references to secrets.yml"
```
Should produce no output (or only references in `plans/` history).

### 7.5. `.sops.yaml` format

```bash
pre-commit run --files .sops.yaml -- check-yaml 2>/dev/null || yaml_validator .sops.yaml
```
The file should parse as valid YAML with the expected keys.

## 5. Outstanding Manual Steps

- **Provision age keys**: Each host's `/etc/sops/age.key` must be generated and
  the fingerprint added as a recipient in the corresponding
  `secrets/hosts/<name>.yml` sops header. The admin key is already known
  (`age1dmawdc96sk8yent9u9wvmwzxk6ean4zpkq6n7msx952ppnnxj90q5utu5u`).
- **Verify `kkedge` age key**: If `kkedge` has an age key, add it as a recipient
  to `secrets/hosts/kkedge.yml`. If not yet provisioned, document the gap in
  Section 6.2 and add the recipient later.
- **Transcribe all plaintext secrets from `secrets.yml` and `environment.yml`**:
  The agent cannot read these files (permission rules). The user must manually
  copy every value into the new `secrets/hosts/*.yml`,
  `secrets/services/*.yml`, `secrets/users/*.yml` files, ensuring no value is
  lost.
- **Update `ssh-public.yml`**: Populate with the current public keys and host/
  user access mappings. This file is referenced by the SSH module but was not
  previously tracked in the repository.
- **Run on-machine functional checks**: After `nixos-rebuild`, verify that
  services can read their sops-decrypted secrets from the expected file paths
  (e.g., `cat /run/secrets/<VAR>` inside running containers).

## 6. Dependencies

- `plans/migration.md` — required for the `readModules` autoloader, filesystem
  disambiguation, and `helpers/` → `src/helpers/` move that affects
  `helpers/secrets.nix` paths.
- `plans/homelab.md` — required for service ownership assignments, the
  `myLib.services` namespace, and the docker-services-to-Nix migration that
  determines which secrets belong to which service.