# OpenCode: editor deprecation warnings & V2 migration

Status: **deferred** — stay on OpenCode V1 for now.
Date: 2026-10-16

## Problem

Editors (Zed et al.) show deprecation warnings on nearly every key in
`home-modules/console/opencode/config/opencode.jsonc`.

Cause: the config's `$schema` is `https://opencode.ai/config.json`, which now
serves the **V2** JSON schema. That schema marks all V1 top-level keys
(`permission`, `agent`, `provider`, and also `command`, `plugin`, `snapshot`,
`mode`, `small_model`, `autoupdate`, `reference`, `tools`, `attachment`,
`logLevel`, `server`, ...) as `"deprecated": true`. The three keys actually used
in the file span ~99% of it, hence "pretty much everything" lights up.

This is **cosmetic**: the file is valid V1 and the installed binary is V1. No
runtime warning is emitted by opencode itself (`opencode debug config` is
clean); only the editor's schema validation complains.

## Decision

- Stay on OpenCode **V1**; keep the current `nixpkgs` pin.
- Leave the `$schema` warnings as-is (do **not** remove `$schema`, do **not**
  ship a local V1 schema).
- Keep the notification plugin deleted/disabled.
- No changes to `opencode-sandboxed`.

Revisit when nixpkgs ships a V2 package, or when the upstream overlay build
cost is deemed acceptable.

## Current state (facts verified 2026-10-16)

- Installed binary: `pkgs.opencode` **1.18.25** (V1). NixOS host `kkbook`
  (`result -> nixos-system-kkbook-26.11.20260903.0968519`).
- Pinned `nixpkgs` rev `0968519e14f7aa7d3e9b389682bd74d2b51c8ce8`.
- `nixos-unstable` `pkgs.opencode` is **1.19.0, still V1** — builds V1
  `packages/opencode`, ships `tui.json`, uses the old `completion` subcommand.
  There is **no `opencode2` package** in nixpkgs.
  => Bumping nixpkgs does NOT yield V2 and does NOT fix the warnings.
- V2 is a separate major line (`v2.0.x`, latest ~`2.0.30`); V1 line continues
  (1.19.x).
- V1 rejects V2 config: `V2 permissions are not supported by OpenCode V1. Use
  V1 "permission" rules or run opencode2.`

## Host / platform matrix

| Host            | System          | Runs opencode |
|-----------------|-----------------|---------------|
| kkbook          | x86_64-linux    | peon          |
| kktab           | x86_64-linux    | ?             |
| kkserv          | x86_64-linux    | ?             |
| kknas           | (linux)         | ?             |
| kkworker        | (linux)         | ?             |
| kg-continabook  | aarch64-darwin  | kg            |
| installer (ISO) | x86_64-linux    | peasant       |

Any packaging path must cover x86_64-linux, aarch64-linux, aarch64-darwin.

## Relevant files

- `home-modules/console/opencode/config/opencode.jsonc` — V1 config
  (`$schema` line 2, `permission` line 3, `agent` line 277, `provider` line 496).
- `home-modules/console/opencode/config/tui.json` — V1 terminal config
  (`attention.enabled/notifications/sound`).
- `home-modules/console/opencode/config/plugin/notification.js` — deleted in the
  working tree (recover: `git show HEAD:home-modules/console/opencode/config/plugin/notification.js`).
- `home-modules/console/opencode/default.nix` — module using `myLib.program.mk`
  (`target = "opencode"`).
- `home-modules/console/opencode/nix/packages.nix` — `home.packages = [ pkgs.opencode pkgs.libnotify ]`.
- `home-modules/console/scripts/bash/opencode-sandboxed` — container wrapper;
  Dockerfile `FROM ghcr.io/anomalyco/opencode:latest`, mounts host
  `opencode.jsonc` read-only.
- `overlays/default.nix` — empty overlay stub `{...}: _final: _prev: {}`.
- `flake.nix:106-107` — `overlays = [ (import ./overlays {inherit inputs;}) ];`
  (overlays already receive `inputs`).
- `lib/program.nix` — `program.mk` / `staticFiles` / `collectFiles`; copies
  everything under `config/` verbatim to `$XDG_CONFIG_HOME/<target>` and renders
  `templates/`.
- `flake.nix` — `nixpkgs` = `nixos-unstable`; devShell includes `opencode`.

Deployed files are symlinks into the home-manager store, e.g.
`~/.config/opencode/opencode.jsonc -> /nix/store/<hm>/.../opencode.jsonc -> /nix/store/<hm_opencode.jsonc>`.

## Deferred V2 migration plan

### 1. Package OpenCode V2

Two viable options (nixpkgs bump ruled out).

**Option A (recommended): upstream flake overlay.** Add
`github:anomalyco/opencode/v2.0.30` as a flake input, then in
`overlays/default.nix`:

```nix
{ inputs, ... }: final: prev:
let up = inputs.opencode.overlays.default final prev; in
{
  opencode = up.opencode;
  opencode-desktop = up.opencode-desktop; # optional
}
```

- Upstream `nix/opencode.nix` + `nix/node_modules.nix` (FOD) source-builds V2
  with bun; `nix/hashes.json` already pins node_modules for x86_64-linux,
  aarch64-linux, aarch64-darwin — i.e. all our platforms.
- Provides `bin/opencode` **and** `bin/opencode2` (symlink) plus shell
  completions for both.
- Wraps `ripgrep` (PATH), `wayland` (LD_LIBRARY_PATH, OpenTUI clipboard on
  Linux), `sysctl` (darwin); sets `MODELS_DEV_API_JSON`/`OPENCODE_DISABLE_MODELS_FETCH`.
- Needs `bun`, `nodejs`, `models-dev` in the pinned nixpkgs — all present.
- Cost: heavy bun build (~4 GB), FOD needs network on first build.
- Replaces `pkgs.opencode` everywhere (home-module `nix/packages.nix` unchanged,
  devShell).

**Option B: prebuilt npm binary.** `fetchurl` the versioned platform tarball,
`autoPatchelfHook` + `makeBinaryWrapper`.
- Stable versioned URLs, e.g.
  `https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-2.0.30.tgz`
  (contains `package/bin/opencode`, 211 MB binary).
  shasum `654f989a83075c39b09bee9058e9296f2988e1f6`.
- Also `@opencode/cli-linux-arm64`, `@opencode/cli-darwin-arm64`,
  `@opencode/cli-darwin-x64` (and `-baseline`, `-musl` variants).
- opencode.ai serves only an unversioned `latest` tarball
  (`https://opencode.ai/update/api/latest/cli/opencode/opencode-linux-x64.tar.gz`,
  200, ~98 MB gz / 211 MB binary); versioned URLs 404 there.
- Lighter build, but recipe is hand-maintained and models data is not bundled.

### 2. Migrate `opencode.jsonc` to native V2

- Keep `$schema: https://opencode.ai/config.json` (now matches).
- `permission` -> `permissions`: ordered array of `{ action, resource, effect }`.
  Action renames: `bash` -> `shell`, `task` -> `subagent`, `write`/`patch` ->
  `edit` (edit/write/patch merge). Preserve last-rule-wins order.
- `agent` -> `agents` (`#defs` per agent): `prompt` -> `system`,
  `disable` -> `disabled`, `maxSteps` -> `steps`,
  `temperature`/`top_p`/`options` -> `request.body`, model+variant joined as
  `provider/model#variant`.
- `provider` -> `providers`: `npm` -> `package` with `aisdk:` prefix. For
  `contina`: `package = "aisdk:@ai-sdk/openai-compatible"`, keep `options`
  (`baseURL`, `apiKey`) and `models`.
- `mcp` -> `mcp.servers` (`enabled` -> `disabled`, timeout object); `plugin` ->
  `plugins` (array/object form); `command` -> `commands`; `snapshot` ->
  `snapshots`; `reference` -> `references`; `small_model` -> `agents.title.model`;
  `autoupdate` -> `update`; `disabled/enabled_providers` -> `policies`.
- Note: V1 config still loads under V2, and V2 under V1 for shared keys, but the
  converted file is V2-only (V1 binary would reject `permissions`).

### 3. `tui.json` -> `cli.json`

- V2 terminal config moved from `tui.json` to `cli.json` (auto-migrated by V2).
- Replace `config/tui.json` with `config/cli.json` carrying the
  `attention.*` settings. Home-module copies `config/` verbatim, so this is a
  file swap.
- V2 `cli.json` schema: `https://opencode.ai/v2/cli.json`.

### 4. Notification plugin (optional)

- V1 plugins do not run in V2; the new V2 plugin API requires a rewrite.
- Plan: leave disabled until a V2 plugin is written.

### 5. Sandbox image

- `opencode-sandboxed` uses `FROM ghcr.io/anomalyco/opencode:latest`, mounting
  the host config read-only.
- When migrating, consider pinning to a versioned tag (e.g. `:2.0.30`) so the
  container matches the host. Not done while on V1.

### 6. Verification

- `opencode --version` == `2.0.30`; `opencode2 --version` works.
- `opencode debug config` / `opencode doctor` report no unknown keys.
- Editor deprecation warnings gone.
- Rebuild a host (e.g. `kkbook`) and confirm `opencode.jsonc`/`cli.json` deploy.

## Open questions

- Which additional hosts/users enable `apps.opencode`? (only peon on kkbook,
  kg on kg-continabook, peasant on installer confirmed so far.)
- Preferred V2 packaging: upstream flake overlay vs prebuilt npm binary.
- Port the notification plugin now or later?
- Pin the sandbox image alongside the host upgrade?
