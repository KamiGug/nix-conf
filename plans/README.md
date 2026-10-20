# Plans

Ordered execution guide for the plans in this directory. Run them **top to
bottom** — later plans build on conventions the earlier ones introduce, so a
plan must be fully landed before the next one starts.

## Execution order

| # | Plan | Status | Depends on | Scope |
|---|------|--------|-----------|-------|
| 1 | [`migration.md`](./migration.md) | in progress — step 1 done | — | `src/` layout, filesystem-as-registry (`readModules`/`readHosts`/`readUsers`), lib autoloading, module/host/user auto-discovery |
| 2 | [`homelab.md`](./homelab.md) | blocked | `migration.md` | `myLib.services.mk`/`mkEnv`/presets, config+image derivations, sops-nix secrets, multi-env via `postfix`, retires `docker-services/` |
| 3 | [`sec-management.md`](./sec-management.md) | proposed | `migration.md`, `homelab.md` | modular auto-discovering secrets tree, sops-nix config, encryption policy |
| — | [`opencode.md`](./opencode.md) | deferred | — | OpenCode V1 → V2 migration; independent of the three above, do whenever |

## Rules

1. **Strict ordering.** Do not start plan N+1 until plan N is fully done and
   verified. `homelab.md` explicitly assumes `migration.md` is executed;
   `sec-management.md` assumes both.
2. **Verify after each plan.** Each plan has its own `## Verification` section
   — run the checks listed there (host evals, `nix flake show`, lint, etc.)
   before declaring the plan done.
3. **Status is truth.** Each plan's `Status:` line is authoritative. Update it
   (and the table above) as work progresses: `proposed` → `in progress` →
   `done`. `homelab.md` is `blocked` until `migration.md` is `done`.
4. **`opencode.md` is orthogonal.** It can be done at any time; it does not
   unblock or depend on the other three.
5. **Secrets are user-executed.** `migration.md` and `sec-management.md` touch
   sops material (`secrets.yml`, `sops.yml`, age keys) that agents cannot read
   (permission rules). Those transcription steps are for the user; do not
   guess their contents.

## Step workflow

There is no step-file splitting. Each plan is executed directly from its own
`.md`, using its internal `## Migration steps` / task sections as the checklist.
