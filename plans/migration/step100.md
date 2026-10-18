# step100.md — Foundations: Convert plans/migration.md to step format

## Depends on
None (first step).

## Reads from
- `plans/migration.md` (original — being converted into step format)

## Does
1. Read `plans/migration.md` in full and identify all top-level sections and steps.
2. Create individual step files (`step101.md`, `step102.md`, ...) for each atomic task in the migration plan, preserving order.
3. Each new step file should follow the convention in `README.md`: summary, depends on, reads from, does, verifies.
4. Delete or mark `plans/migration.bak.md` as reference-only once all steps are extracted.
5. Verify: all migration steps have corresponding `step*.md` files and no top-level content remains unassigned.

## Verifies
- `nix flake show` still produces 8 configurations (or equivalent validation for the migration state).
- Every section of the original `plans/migration.md` appears in some `step*.md` file.
- No step file ends without a "Verifies" subsection.