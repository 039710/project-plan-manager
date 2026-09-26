---
description: Audit a .ppm plan against the current code before executing it
argument-hint: "<plan-name> [phase]"
---
Load the `project-plan-manager` skill and audit plan `$1`, scope: ${2:-all phases}.

Check the plan against the repository as it exists now, then report briefly. Do not edit any plan file.

Report only findings that change what an executor should do:

- Task details that no longer match the code (renamed files, changed interfaces, settled decisions).
- Tasks missing acceptance criteria or a way to verify completion.
- Phases that cannot be verified independently, or that depend on unfinished work.
- Referenced paths, commands, or migrations that do not exist.

For each finding give the task id, what is wrong, and the smallest correction. Confirm status from `plan-task task_list` rather than `plan.md`.
