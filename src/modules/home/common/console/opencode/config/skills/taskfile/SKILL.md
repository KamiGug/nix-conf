---
name: taskfile
description: Use when the user asks to run, list, or inspect tasks defined in a Taskfile (Taskfile.yml, Taskfile.yaml, Taskfile.dist.yml, go-task, the "task" CLI). Finds the Taskfile, lists available tasks, reads task definitions before running them, and runs tasks with the right directory, variables and flags.
---

# Taskfile tasks

Project tasks are defined with [go-task](https://taskfile.dev) in
`Taskfile.yml` / `Taskfile.yaml` (also `Taskfile.dist.yml`). The `task`
binary is installed system-wide. In the NixOS config repo the Taskfile lives
at `docker-services/Taskfile.yml` (compose generation and service lifecycle).

## 1. Find the Taskfile

Glob for `**/Taskfile.y*ml` and `**/Taskfile.dist.y*ml`. If several match,
use the one in the directory the user named; otherwise list the matches and
ask. Task only auto-discovers a Taskfile in its dir (the cwd by default), so
from the repo root point at it explicitly with `-d` (see step 3).

## 2. List what exists

Run in the Taskfile's directory or pass `-d <dir>`:

```bash
task --list          # tasks with a description
task --list-all      # including undescribed tasks
task --list --json   # machine-readable
```

## 3. Read the task before running it

For any task that changes state (starts or stops containers, regenerates
files, runs migrations), read its definition in the Taskfile first: `desc`,
`deps`, `cmds`, `preconditions`, `dir`, `vars`. `deps` run before the task
itself; `preconditions` abort with a message when unmet.

## 4. Run

```bash
task <name>                      # in the Taskfile's directory
task -d <dir> <name>             # from anywhere (--dir; note -C is concurrency, not cwd)
task -t path/Taskfile.yml <name> # explicit Taskfile path
task                             # runs the `default` task
task build test                  # several tasks, in order
task -p build test               # in parallel
```

Preview instead of executing:

```bash
task -d <dir> --dry <name>       # print the command order, run nothing
task -d <dir> --summary <name>   # one task's summary
task -d <dir> --status <name>    # non-zero exit if the task is not up to date
```

## 5. Variables and arguments

```bash
task up SERVICES=postgres        # CLI variable, read as {{.SERVICES}}
task greet "NAME=Jane Doe"       # quote values that contain spaces
task build test ENV=production   # shared by every task in the run
task yarn -- install             # everything after `--` goes to {{.CLI_ARGS}}
```

A variable declared in the task's own `vars:` block beats the CLI value; a
default in the root `vars:` block or a `{{.VAR | default "..."}}` template is
what makes a value overridable from the command line.

## 6. Other useful flags

- `-v` verbose output
- `-f` force, even if the task is up to date
- `--exit-code` pass the task's exit code through to the caller
- `-o prefixed|group|interleaved` output style; group/prefixed keep output from
  parallel tasks readable
- `--yes` answer yes to prompts — tasks that ask for confirmation would
  otherwise hang in a non-interactive session
- `-w` watch mode: never leave it running in a session, re-run instead

## 7. When it fails

Task prints the failing command and exits non-zero; a failed `dep` aborts the
tasks that depend on it. Report the failing command and the precondition or
dependency message verbatim instead of guessing.
