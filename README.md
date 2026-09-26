# Project Plan Manager

Local package for the `project-plan-manager` agent skill: structured project plans, phased JSON tasks, progress tracking, and a local dashboard.

This directory is the source of truth. `install.sh` distributes it to the skill directories the agent clients read, and to the CLI location the `plan-task` shim calls.

Clone it anywhere you like; `~/.project-plan-manager` is the recommended location, and the paths in this README assume it. The installer always works from its own directory, so any clone location is fine.

## Origin and attribution

Inspired by [alfahluzi/project-plan-manager](https://github.com/alfahluzi/project-plan-manager), an MIT-licensed project that defines the canonical `project-plan-manager` skill layout: a lowercase hyphenated skill folder with a routing `SKILL.md` and tiered flow prompt files.

This package is a locally maintained variant of that idea, not a fork of the upstream repository and not affiliated with its author. It keeps the same concept (phased JSON plans under `.ppm/`, task status tracking, a local dashboard) but has diverged in CLI name, command surface, and skill file layout; see [Differences from the upstream reference](#differences-from-the-upstream-reference). Credit for the original design belongs upstream. If you redistribute this package, keep this attribution and the upstream MIT notice.

Upstream remains the reference for the fuller feature set: `ppm` CLI, `prompts/*-flow.md` routing, and task dependency handling.

## Layout

```text
~/.project-plan-manager/
|-- README.md
|-- install.sh              # distributes skill/, cli/, and pi/ to their runtime paths
|-- skill/                  # canonical skill payload
|   |-- SKILL.md
|   |-- templates/task.html # dashboard (served, never copied into projects)
|   `-- scripts/smoke-test-task-html.js
|-- pi/                     # Pi harness extras
|   |-- prompts/            # slash-command templates -> ~/.pi/agent/prompts/
|   |   |-- plan-new.md     # /plan-new
|   |   |-- plan-run.md     # /plan-run
|   |   `-- plan-audit.md   # /plan-audit
|   `-- AGENTS.snippet.md   # bounded auto-use block for ~/.pi/agent/AGENTS.md
|-- examples/demo-plan/     # copyable plan: plan.md + tasks/phase_*.json
`-- cli/
    |-- plan-task.js        # CLI implementation -> $HOME/.local/lib/opencode/plan-task.js
    `-- plan-task           # POSIX sh shim -> $HOME/.local/bin/plan-task
```

`SKILL.md` is the routing file; it is the only mandatory read for an agent. There are no separate `prompts/` flow files in this package (see [Differences from the upstream reference](#differences-from-the-upstream-reference)).

Two runtime skill copies exist on this machine because two clients read different directories:

| Client | Skill directory | Reads the package |
| --- | --- | --- |
| Pi | `~/.pi/agent/skills/project-plan-manager` | via `install.sh --client pi` |
| OpenCode | `~/.config/opencode/skills/project-plan-manager` | via `install.sh --client opencode` |

The CLI resolves the dashboard template by searching, in order:

1. `$HOME/.config/opencode/skills/project-plan-manager/templates/task.html` (installed layout)
2. `<package>/skill/templates/task.html` (running from a clone)
3. `<package>/templates/task.html` (flattened layout)

If none exists, `dashboard_serve` reports every path it tried and exits non-zero instead of starting a server that cannot serve its page. `install.sh` still installs the first path unconditionally, so the dashboard works whichever client you selected. Keep the runtime copies identical by running `install.sh` after every edit rather than editing a runtime copy by hand.

## Features

- Create and manage `.ppm/<plan-name>/` project plans.
- Track ordered phases and task status through a JSON contract.
- Register project roots in a user-local configuration file.
- Serve a local dashboard bound to `127.0.0.1`.
- Migrate legacy `docs/plans/` layouts.
- Copy-paste prompts per plan, per phase, and per task, plus raw CLI commands, from the dashboard.
- Pi slash commands `/plan-new`, `/plan-run`, and `/plan-audit`.

## Requirements

- Node.js >= 18 on `PATH`.
- No npm, no build step, no dependencies. Everything here is plain Node and static HTML.
- POSIX shell for the installer (Linux/macOS; on Windows use WSL or Git Bash).

## Installation

```sh
git clone https://github.com/039710/project-plan-manager.git ~/.project-plan-manager
cd ~/.project-plan-manager
./install.sh --dry-run                 # show every path that would change
./install.sh                           # copy mode: pi + opencode (+ CLI)
./install.sh --client claude           # Claude Code skill dir
./install.sh --client codex            # Codex / ~/.agents skills dir
./install.sh --client all              # every supported client
./install.sh --mode link               # symlink skill dirs at skill/ (live development)
./install.sh --agents-md               # pi only: append the auto-use block to AGENTS.md
./install.sh --uninstall               # move installed skill dirs aside, remove CLI
```

The clone target is a convenience, not a requirement: run `install.sh` from wherever the repository landed and it installs from that tree.

Supported `--client` values: `pi`, `opencode`, `claude`, `codex`, `agents`, `all`.

`copy` mode (default) snapshots the package into each skill directory. `link` mode symlinks them back at `skill/`, so an edit takes effect immediately in every client — use it while working on the skill, copy mode for a stable install.

When a destination already exists, the installer moves it to `<destination>.rollback-<timestamp>` instead of deleting it. Nothing is removed silently; delete those rollback directories yourself once the install is verified.

`--uninstall` touches only the skill directories, the Pi prompt templates it installed (identical files only), and the CLI. Your plans (`.ppm/`), `config.json`, project data, and `AGENTS.md` are left untouched.

### PATH

The shim is installed at `~/.local/bin/plan-task`. If `plan-task` is not found:

```sh
command -v plan-task
npm prefix -g          # only relevant if you also install node tools globally
```

Add `$HOME/.local/bin` to your shell `PATH` yourself after reviewing your shell profile. The installer never edits shell profiles. Restart the terminal and the agent client after changing `PATH`.

### Optional automatic use

To have the skill loaded automatically for planning, execution, and plan audits, add this bounded block to the **user-level** `AGENTS.md` your client reads (not the project one). Edit it only with explicit consent.

For Pi, `install.sh --agents-md` appends the block to `~/.pi/agent/AGENTS.md` for you: it keeps existing content, skips when the block is already present, and prints a dry-run line under `--dry-run`. Nothing appends it implicitly — the flag is the consent. `--uninstall` deliberately leaves that file alone; remove the block by hand.

The block itself:

```markdown
<!-- project-plan-manager:start -->
For planning, executing/resuming plans, or auditing plans before execution, load and use the `project-plan-manager` skill and the `plan-task` CLI.
<!-- project-plan-manager:end -->
```

## Pi harness

Pi reads the skill from `~/.pi/agent/skills/project-plan-manager` (`--client pi`, included in the default install). Confirm it loaded with `/skill:project-plan-manager`, or force it when the model does not pick the skill up on its own.

The package also ships three prompt templates, installed to `~/.pi/agent/prompts/` when `pi` is among the selected clients. The filename is the command name, so they appear in `/` completion:

| Command | Arguments | Does |
| --- | --- | --- |
| `/plan-new` | `<plan-name> [goal]` | Plans with the skill, then writes `.ppm/<plan-name>/` |
| `/plan-run` | `<plan-name> [phase]` | Executes or resumes a plan through `plan-task` |
| `/plan-audit` | `<plan-name> [phase]` | Audits the plan against current code, edits nothing |

Run `/reload` in an active Pi session after installing or editing a template. Existing templates with the same name are moved to `<name>.md.rollback-<timestamp>` before being replaced.

Pi also reads the Agent Skills location `~/.agents/skills/`, which is what `--client codex` and `--client agents` install to.

## Usage

Run the CLI from a project root, or pass `--project <path>` to target another project. With no arguments it prints its usage block and exits non-zero.

```sh
plan-task -h | --help                                   # full usage, exit 0
plan-task init [--plan <name>] [--project <path>]
plan-task plan_init --plan <name> [--project <path>]     # alias for init --plan
plan-task migrate [--project <path>] [--dry-run]
plan-task clean_roots [--dry-run]
plan-task dashboard_serve [--project <path>] [--port <port>]

plan-task task_list --plan <name> --phase <phase_x> [--project <path>]
plan-task task_get_detail --plan <name> --phase <phase_x> --task-id <id> [--project <path>]
plan-task task_get_progress --plan <name> --phase <phase_x> --task-id <id> [--project <path>]
plan-task task_write_progress --plan <name> --phase <phase_x> --task-id <id> --progress-text <text> [--project <path>]
plan-task task_completed --plan <name> --phase <phase_x> --task-id <id> [--project <path>]
plan-task task_fail --plan <name> --phase <phase_x> --task-id <id> [--project <path>]
plan-task task_reset --plan <name> --phase <phase_x> --task-id <id> [--project <path>]
```

Task status values are `todo`, `completed`, and `fail`. Progress text is free-form and read back with `task_get_progress`. Phases run in numeric order; parallelism inside a phase is a judgment call described in `SKILL.md`, not a CLI flag.

`--dry-run` is supported by `migrate` and `clean_roots` only. Successive runs are safe: `init` re-registers the project root, and `task_*` commands are idempotent for the same target status.

With no arguments at all, `plan-task` prints the same usage block and exits non-zero.

### Try it in a minute

`examples/demo-plan/` is a ready-made plan, so you can see the layout and the CLI round trip before authoring anything. From a project root:

```sh
plan-task init --plan demo
cp -R ~/.project-plan-manager/examples/demo-plan/plan.md .ppm/demo/plan.md
cp ~/.project-plan-manager/examples/demo-plan/tasks/*.json .ppm/demo/tasks/
plan-task task_list --plan demo --phase phase_0
plan-task dashboard_serve           # http://127.0.0.1:4173/task.html
```

Adjust the `cp` source if you cloned the package somewhere else. Remove `.ppm/demo/` when done.

Phase files are hand-authored (or written by the skill's agent) — there is deliberately no `task_add` command, because a task's `detail` is the contract another agent executes, and that is worth writing in full. Copy the example file as your starting point.

## Dashboard

```sh
plan-task dashboard_serve [--port 4173]
```

- Binds to `127.0.0.1` only.
- Serves `templates/task.html` and polls `.ppm/*/tasks/phase_*.json` every 3 seconds.
- Shows per-plan phase strips, task status, detail, progress, and copy buttons for execute/audit prompts and `plan-task task_get_detail` commands.
- Controls: project selector, status filter, task search, refresh, column count (`1`/`2`/`3`), and theme (`auto`/`light`/`dark`). Preferences are stored in the browser, not on disk.
- There is no authentication. Anyone who can reach the port can read the plan data, so do not bind it to a public interface.

## Data and configuration locations

| What | Where |
| --- | --- |
| Project plans and task data | `<project>/.ppm/` |
| Example plan | `<package>/examples/demo-plan/` |
| Pi prompt templates | `~/.pi/agent/prompts/plan-*.md` |
| Pi auto-use instructions | `~/.pi/agent/AGENTS.md` (opt-in via `--agents-md`) |
| Registered project roots | `~/.config/project-plan-manager/config.json` (`0700` dir, `0600` file) |
| Dashboard template | `~/.config/opencode/skills/project-plan-manager/templates/task.html` |
| CLI implementation | `~/.local/lib/opencode/plan-task.js` |
| CLI shim | `~/.local/bin/plan-task` |

`config.json` holds `{"projects":[{"name","path"}]}`, sorted, and is rewritten atomically with a temporary file plus rename.

## Security and privacy

- The CLI writes project paths and task data locally. Do not publish `config.json`, `.ppm/`, plan content, or task progress.
- The dashboard is not an authenticated service. Keep it on `127.0.0.1`.
- Task text is inserted into the dashboard DOM with HTML escaping; plan files are shown as plain text, so `plan.md` content is not executed.
- `--agents-md` appends to `~/.pi/agent/AGENTS.md`, which Pi loads as user instructions in every working directory. Only the bounded block is added, existing content is kept, and running it twice does not duplicate the block.

## Development verification

From this directory:

```sh
sh -n install.sh                                    # installer syntax
node --check cli/plan-task.js                       # CLI syntax
node skill/scripts/smoke-test-task-html.js          # dashboard render + example contract
plan-task                                           # prints usage, exits non-zero
cd "$(mktemp -d)" && HOME="$PWD/home" sh "$OLDPWD/install.sh" --dry-run
```

The smoke test extracts the dashboard script, runs it against a stub DOM, and asserts forced-open behaviour, persisted accordion state, copy prompts, phase labels, theme, and column settings. When run from the package it also validates `examples/demo-plan` against the phase JSON contract and the `pi/` prompt templates and AGENTS snippet. Installed copies carry `skill/` only, so those extra checks report as skipped there. Run it after any edit to `skill/templates/task.html`, the example plan, or `pi/`.

The installer is safe to exercise with a throwaway `HOME`, which is how its dry-run, copy, link, and uninstall paths are checked without touching a real installation:

```sh
T=$(mktemp -d) && mkdir -p "$T/home"
HOME="$T/home" sh install.sh --client all --mode link --dry-run
HOME="$T/home" sh install.sh --client pi --agents-md
HOME="$T/home" sh install.sh --client pi --uninstall
```

## Differences from the upstream reference

The upstream [alfahluzi/project-plan-manager](https://github.com/alfahluzi/project-plan-manager) ships a different surface. This package is the local, working variant; it does not implement the upstream features below, and its README deliberately does not document them:

| Upstream reference | Here |
| --- | --- |
| `ppm` CLI via `npm link` / `install.sh` | `plan-task` shim in `~/.local/bin`; no npm package |
| `prompts/planning-flow.md`, `execution-flow.md`, `audition-flow.md`, `installation-flow.md` | single `SKILL.md` routing file |
| `task_ready`, `task_blocked`, `task_get`, `task_in_progress`, `check_dashboard` | not present |
| `pre_request` dependencies between tasks in a phase | not present; ordering is agent judgment per `SKILL.md` |
| `in_progress` task status | not present; statuses are `todo`, `completed`, `fail` |

If you prefer the upstream names, symlink them yourself rather than adding aliases here:

```sh
ln -s ~/.local/bin/plan-task ~/.local/bin/ppm
```

## Credits

- Original design and reference implementation: [alfahluzi/project-plan-manager](https://github.com/alfahluzi/project-plan-manager) (MIT).
- Local variant, dashboard template, and installer: maintained in this package.

## License

MIT. See [LICENSE](LICENSE).

Upstream is MIT-licensed by its own author; keep that attribution when you redistribute this package.
