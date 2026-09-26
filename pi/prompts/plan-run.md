---
description: Execute or resume a .ppm plan with the project-plan-manager skill
argument-hint: "<plan-name> [phase]"
---
Load the `project-plan-manager` skill and follow its execution flow.

Execute plan `$1`, phase: ${2:-the first phase with unfinished tasks}.

Requirements:

- Read task status through `plan-task`, never from memory or `plan.md`: `plan-task task_list --plan $1 --phase <phase_x>`.
- Take the next task with `task_get_detail`, and `task_get_progress` when it reports progress.
- Record evidence with `task_write_progress` before `task_completed`; use `task_fail` with the cause when a task cannot be finished.
- Report back at the end of each phase: what was done, how it was verified, and what is next.
- Stop and ask when a finding changes scope, behavior, or architecture.
