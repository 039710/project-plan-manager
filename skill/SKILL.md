---
name: project-plan-manager
description: Create and execute structured project plans with phased JSON tasks and per-task progress. Use when the user asks for a project plan, implementation plan, task breakdown, progress tracking, or plan execution.
compatibility: Node.js is required for the global task CLI.
metadata:
  scope: global
  task-format: json
---

# Project Plan Manager

Create and manage plans inside the active project only. Resolve `<project-path>` from the project explicitly named by the user, otherwise from the active working directory or repository root. Ask if multiple roots are plausible.

## Layout

```text
<project-path>/.ppm/<plan-name>/
|-- plan.md
`-- tasks/
    |-- phase_0.json
    |-- phase_1.json
    `-- phase_2.json
```

Projects are registered in `~/.config/project-plan-manager/config.json`. The dashboard template is global and is never copied into projects.

Create only the phases required by the plan. Use lowercase kebab-case for plan names unless the project already follows another convention. Preserve unrelated files and existing project conventions.

## Planning Rules

- Inspect relevant source, configuration, and existing documentation before planning.
- Separate verified facts, assumptions, decisions, open questions, and future work.
- Do not invent requirements. Ask when missing information changes scope, behavior, acceptance criteria, or architecture.
- Before writing files, share a short draft (phases + key decisions + open questions) with the user and invite correction. Skip only when the user already gave a complete spec or said "just do it".
- Make phases ordered, dependency-aware, and independently verifiable.
- Within a phase, identify tasks that can run in parallel (see Parallel Execution). Group them and mark it in each task's `detail`, e.g. last line: `Parallel: group A | Depends on: none | Touches: src/api/user.ts, src/api/user.test.ts`. Sequential tasks use `Parallel: no | Depends on: TASK-002`.
- Link source requirements and related project documentation with relative paths.
- Include `Last updated: YYYY-MM-DD` in maintained Markdown files.

## plan.md

Use applicable sections:

1. Objective
2. Source documents and requirements
3. Current-state findings
4. Constraints and invariants
5. Proposed approach
6. Ordered phases
7. Deliverables per phase
8. Dependencies
9. Risks and mitigations
10. Verification strategy
11. Definition of done

Every JSON task must trace to a phase and deliverable in `plan.md`.

## Task JSON Contract

Each `tasks/phase_x.json` uses:

```json
{
  "phase": "phase_x",
  "title": "Phase title",
  "tasks": [
    {
      "id": "TASK-001",
      "title": "Short action-oriented title",
      "detail": "Implementation detail, constraints, expected result, and verification.",
      "status": "todo",
      "progress": ""
    }
  ]
}
```

Invariants:

- `phase` matches the filename without `.json`.
- IDs are unique within a phase and remain stable.
- Status is `todo`, `completed`, or `fail`.
- New tasks start as `todo`.
- `progress` is a string containing concise, factual execution progress, verification evidence, or failure context.
- Task detail must let another agent execute without rediscovering settled intent.
- Task detail states intent and acceptance criteria, not a script. Executors may choose a different route when it meets the same intent.

## Plan Execution Flow

The plan is a map, not a cage. Hard rules are only: task data goes through the CLI, and status must reflect reality. Everything else is judgment.

Before writing any plan files, initialize the plan:

```bash
plan-task init --plan <plan-name>
```

This creates `.ppm/<plan-name>/tasks/` recursively and registers the resolved project root. `plan-task init` without `--plan` initializes and registers only the project.

1. Resolve the target project and plan name. Enumerate phase filenames only to determine phase order.
2. Work phases in numeric order by default. Call `task_list` for the current phase; block order is the default task order. Reorder when dependencies or findings justify it, and say why.
3. For the next non-`completed` task, call `task_get_detail` (and `task_get_progress` when it shows `Has progress`).
4. Explore freely before and during the task: read surrounding code, run checks, verify the detail still matches reality. Task detail may be stale; the codebase wins.
5. Execute toward the task's intent. Small adjacent fixes needed to make it work are in scope; mention them in progress.
6. Record what was done and how it was verified with `task_write_progress`, then `task_completed`.
7. Repeat until the phase is done, then continue to the next phase.

### Parallel Execution

Sequential is the default only when tasks actually depend on each other. When independent tasks exist, run them in parallel instead of queueing them.

Tasks may run in parallel only when all hold:

1. **No dependency**: neither needs the other's output (code, types, schema, generated files, decisions).
2. **Disjoint write sets**: they do not edit the same files. Shared read-only files are fine.
3. **No shared mutable resources**: no both touching lockfiles/package installs, DB migrations or schema, global config, env files, codegen output, or the same running service/port.
4. **Independently verifiable**: each has its own check that does not need the other finished.

If any condition is uncertain, check the code first; if still unclear, run sequentially. Planning marks (`Parallel: group X`) are hints; re-verify against the current code before dispatching.

How:

- The main agent is the orchestrator. It dispatches each parallel task to a subagent (`Agent` tool, e.g. `sidekick`, `run_in_background: true`), with the full task detail, the allowed write set, and the verification to run. Use `isolation` (git worktree) when write sets are close or the risk of collision is non-trivial.
- Cap concurrency at 3 unless the user asks otherwise.
- Only the orchestrator calls `task_write_progress`, `task_completed`, and `task_fail`, to avoid concurrent writes to the same phase JSON. Subagents return a result summary + verification evidence; the orchestrator records it.
- While subagents run, the orchestrator may do a non-conflicting sequential task itself.
- After a parallel group finishes: merge worktree results if used, then run an integration check (build/typecheck/tests covering the group) before marking the group done or starting dependent tasks.
- If one parallel task fails, do not cancel the others unless they depend on it; record the failure and handle it per "When reality diverges".
- Phases stay a barrier by default. Start a next-phase task early only if it satisfies all four conditions against every unfinished task, and say so.

Tell the user which tasks run in parallel and why before dispatching (one line is enough).

### When reality diverges from the plan

Do not silently force the plan, and do not silently stop. Pick one:

- **Minor drift** (renamed file, extra small step): adapt, note it in progress, continue.
- **Missing task discovered**: finish current task if possible, note the gap in `plan.md` under `Follow-ups`, tell the user, and propose adding it.
- **Task wrong or obsolete**: write why in progress, ask the user whether to rewrite, skip, or drop it.
- **Failure**: write cause + what was tried in progress, call `task_fail`, then report to the user with 1-3 concrete options (retry approach, change scope, skip). Continue with independent tasks if the user already allowed autonomy.
- **Decision that changes scope, behavior, or architecture**: stop and ask. One focused question with a recommended answer.

### Check-ins with the user

The executor is a collaborator, not a batch job. Report back:

- At the end of each phase: what was done, verification, anything surprising, what is next. Continue without waiting unless something needs a decision.
- Whenever a finding changes the value, risk, or cost of remaining work.
- At the end: summary, open follow-ups, and suggested next steps (improvements, tests, risks noticed during work).

If the user said "run it all" or similar, keep check-ins short and keep moving; still stop for scope-changing decisions.

### Data rules (hard)

- Read and change task status/progress only through the CLI. Do not batch-read or hand-edit `phase_*.json` for status or progress.
- Adding or rewriting tasks after user approval: edit the phase JSON directly, following the Task JSON Contract (stable IDs, new tasks `todo`), and update `plan.md` to match.
- Do not claim completion from memory or `plan.md`; confirm through `task_list` for every phase.

## Task CLI

Use the global `plan-task` command directly. Never invoke its JavaScript implementation through `node`. Run from the target project root or provide `--project <project-path>`:

```bash
plan-task init [--project <project-path>]
plan-task init --plan <plan-name> [--project <project-path>]
plan-task migrate [--project <project-path>] [--dry-run]
plan-task clean_roots [--dry-run]
plan-task dashboard_serve [--project <project-path>] [--port 4173]
plan-task task_list --plan <plan-name> --phase phase_0
plan-task task_get_progress --plan <plan-name> --phase phase_0 --task-id TASK-001
plan-task task_get_detail --plan <plan-name> --phase phase_0 --task-id TASK-001
plan-task task_completed --plan <plan-name> --phase phase_0 --task-id TASK-001
plan-task task_fail --plan <plan-name> --phase phase_0 --task-id TASK-001
plan-task task_reset --plan <plan-name> --phase phase_0 --task-id TASK-001
plan-task task_write_progress --plan <plan-name> --phase phase_0 --task-id TASK-001 --progress-text "Implemented endpoint; verification passed."
```

`dashboard_serve` binds only to `127.0.0.1` and serves the global live dashboard at `http://127.0.0.1:4173/task.html` (or the selected port). Without `--project`, it loads registered roots from the global config and provides a project dropdown. It polls fresh `.ppm/*/tasks/phase_*.json` data every 3 seconds. Absolute JSON paths remain server-generated runtime metadata; they are not persisted in config.

## Legacy Migration

Use `plan-task migrate --dry-run` first, then `plan-task migrate`. Migration moves each `docs/plans/<plan-name>/` to `.ppm/<plan-name>/`, removes the obsolete project-local `task.html`, removes empty legacy directories, and registers the project. It stops before changing anything if any destination plan already exists. `plan-task plan_init --plan <name>` remains a compatibility alias for `plan-task init --plan <name>`.

Use `plan-task clean_roots --dry-run` before `plan-task clean_roots`. It removes missing, duplicate, or non-`.ppm` roots from global config. It does not search for projects moved elsewhere; initialize the new path explicitly.

Command results:

- `task_list`: Markdown blocks formatted as `## <id> - <title>` followed by `Status: <status>`, preserving task order. A `todo` task with non-empty progress adds `. Has progress` after its status.
- `task_get_progress`: Markdown sections for `Title`, `Status`, and `Progress`.
- `task_get_detail`: Markdown sections for `Title`, `Status`, and `Detail`.
- `task_completed`, `task_fail`, and `task_reset`: plain text `Task status updated`.
- `task_write_progress`: plain text `progress updated`.

## Completion Check

1. Confirm all files are inside the intended project.
2. Validate every phase and completion state with `task_list`.
3. Confirm referenced paths exist.
4. Report files changed, current status, unresolved questions, verification, and proposed follow-ups.
