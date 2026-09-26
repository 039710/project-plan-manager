# Demo Plan

Last updated: 2026-09-26

Minimal example plan. Copy it into a project to exercise the CLI and the
dashboard without authoring JSON first.

## Objective

Show the `.ppm/` layout, the phase file contract, and one CLI round trip:
list tasks, record progress, mark a task completed.

## Ordered phases

1. `phase_0` - Prepare: confirm the plan is visible, then replace these tasks.
2. `phase_1` - Ship: record progress through the CLI.

## Deliverables

- `tasks/phase_0.json`: one completed task, one open task.
- `tasks/phase_1.json`: one open task that follows phase 0.

## How to use it

From a project root:

```sh
plan-task init --plan demo
cp -R <package>/examples/demo-plan/plan.md .ppm/demo/plan.md
cp <package>/examples/demo-plan/tasks/*.json .ppm/demo/tasks/
plan-task task_list --plan demo --phase phase_0
```

Delete `.ppm/demo/` when you are done, and remember that `plan-task init`
registered the project in `~/.config/project-plan-manager/config.json`.
