---
description: Create a project plan under .ppm/ with the project-plan-manager skill
argument-hint: "<plan-name> [goal]"
---
Load the `project-plan-manager` skill and follow its planning flow.

Create plan `$1` for this project. Goal: ${2:-derive it from the repository context first and confirm it with me before writing any file}.

Requirements:

- Run `plan-task init --plan $1` before writing plan files, so the project root is registered.
- Keep `plan.md` and `tasks/phase_*.json` inside this project under `.ppm/$1/`.
- Show me the draft phases, key decisions, and open questions before writing, unless I already gave you a complete spec.
- Do not invent requirements; ask when missing information changes scope or acceptance criteria.
