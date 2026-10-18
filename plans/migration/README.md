# Migration Step Directory

**Purpose:** Track progress across the three interdependent plans: `migration`, `homelab`, and `sops`.

## Step Selection Rule

At any point, the next step to work on is the one with the **lowest numeric prefix** that does **not** end with `.done`.

- Steps are named `stepXXX.md` where `XXX` is a 3-digit number (e.g., `step100.md`, `step250.md`).
- To find the next step: list all `step*.md` files in `plans/migration/`, extract the numeric prefix, sort ascending, and pick the first one whose filename does **not** end with `.done`.
- After completing a step, rename the file by appending `.done` to its name (e.g., `step100.md` → `step100.md.done`). This marks it as completed and prevents re-selection.

## Plan Merging & Step Splitting

The three plans are conceptually merged and then split into independent, sequentially-numbered steps. The dependency order is:

1. `plans/migration.md` — filesystem-as-registry, `readModules` autoloader, `myLib` conventions
2. `plans/homelab.md` — blocked on `migration.md`; builds on `myLib.services`, sops-nix, docker-services migration
3. `plans/sops.md` — depends on both `migration.md` and `homelab.md`; sops-nix configuration, secrets, encryption policy

Each step should:

- Refer back to this README for the selection rule and `.done` renaming convention.
- Contain enough information (context, tasks, verification checks) so that a fresh agent can take a simple prompt and continue work.
- Be independently eval-able when its turn comes (no step should block another except via the `.done` ordering).
- Reference the parent plans where its decisions overlap or depend on prior steps.

## Step File Convention

- Name: `stepXXX.md` (XXX = 3-digit number, padded, starting from 100 or as decided by the maintainer).
- Each step should begin with a brief summary of what it accomplishes.
- Each step should list:
  - **Depends on** — which prior step(s) must be `.done` first.
  - **Reads from** — which of the three parent plans it builds on.
  - **Does** — the concrete tasks to complete.
  - **Verifies** — how to confirm correctness after the step.
- After completion: rename to `stepXXX.md.done` so the next run picks the next uncompleted step.

## Initial Steps Skeleton

This directory starts with a minimal set of steps that, when completed in order, cover the full merge of `migration.md` → `homelab.md` → `sops.md` and the sops-nix refactoring. The exact numbering and task breakdown can be adjusted, but the `.done` convention must be preserved.