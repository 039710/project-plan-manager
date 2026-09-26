#!/usr/bin/env sh
# Installer for the project-plan-manager package that lives in this directory.
# POSIX sh, no npm, no dependencies: this package is distributed by copy or symlink.
set -eu

PKG_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_SRC="$PKG_DIR/skill"
CLI_SRC="$PKG_DIR/cli/plan-task.js"
SHIM_SRC="$PKG_DIR/cli/plan-task"

CLI_LIB_DIR="$HOME/.local/lib/opencode"
CLI_LIB="$CLI_LIB_DIR/plan-task.js"
BIN_DIR="$HOME/.local/bin"
BIN_SHIM="$BIN_DIR/plan-task"
# plan-task.js resolves its dashboard template from this exact path, so it is
# installed even when only another client was requested.
DASHBOARD_SKILL_DIR="$HOME/.config/opencode/skills/project-plan-manager"

CLIENTS="pi,opencode"
MODE="copy"
DO_UNINSTALL=0
DRY_RUN=0

usage() {
	cat <<'EOF'
Usage: install.sh [options]

  --client <list>   comma-separated: pi, opencode, claude, codex, agents, all
                    (default: pi,opencode)
  --mode <mode>     copy (snapshot, default) or link (symlink to skill/)
  --dry-run         print every action without touching the filesystem
  --uninstall       move installed skill dirs aside and remove the CLI
  -h, --help        show this message

Existing destinations are moved to <destination>.rollback-<timestamp>, never
deleted. Shell profiles are never modified; add $HOME/.local/bin to PATH
yourself if the plan-task shim is not found.
EOF
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--client) [ "$#" -ge 2 ] || { echo "missing value for --client" >&2; exit 2; }; CLIENTS="$2"; shift 2 ;;
		--mode) [ "$#" -ge 2 ] || { echo "missing value for --mode" >&2; exit 2; }; MODE="$2"; shift 2 ;;
		--dry-run) DRY_RUN=1; shift ;;
		--uninstall) DO_UNINSTALL=1; shift ;;
		-h|--help) usage; exit 0 ;;
		*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
	esac
done

case "$MODE" in
	copy|link) ;;
	*) echo "--mode must be copy or link (got: $MODE)" >&2; exit 2 ;;
esac

[ -f "$SKILL_SRC/SKILL.md" ] || { echo "missing $SKILL_SRC/SKILL.md" >&2; exit 1; }
[ -f "$SKILL_SRC/templates/task.html" ] || { echo "missing $SKILL_SRC/templates/task.html" >&2; exit 1; }
[ -f "$CLI_SRC" ] || { echo "missing $CLI_SRC" >&2; exit 1; }
[ -f "$SHIM_SRC" ] || { echo "missing $SHIM_SRC" >&2; exit 1; }

say() { printf '%s\n' "$*"; }
run() {
	if [ "$DRY_RUN" -eq 1 ]; then say "would: $*"; else "$@"; fi
}

skill_dir_for() {
	case "$1" in
		pi) say "$HOME/.pi/agent/skills/project-plan-manager" ;;
		opencode) say "$HOME/.config/opencode/skills/project-plan-manager" ;;
		claude) say "$HOME/.claude/skills/project-plan-manager" ;;
		codex|agents) say "$HOME/.agents/skills/project-plan-manager" ;;
		all)
			skill_dir_for pi
			skill_dir_for claude
			skill_dir_for codex
			;;
		*) echo "unknown client: $1" >&2; return 2 ;;
	esac
}

# Every destination, de-duplicated, always including the dashboard template path.
targets() {
	{
		say "$DASHBOARD_SKILL_DIR"
		for client in $(printf '%s' "$CLIENTS" | tr ',' ' '); do
			skill_dir_for "$client" || exit 2
		done
	} | awk '!seen[$0]++'
}

move_aside() {
	destination="$1"
	[ -e "$destination" ] || [ -L "$destination" ] || return 0
	stamp=$(date +%Y%m%d%H%M%S)
	if [ "$DRY_RUN" -eq 1 ]; then
		say "would: mv $destination $destination.rollback-$stamp"
	else
		mv "$destination" "$destination.rollback-$stamp"
		say "moved existing $destination -> $destination.rollback-$stamp"
	fi
}

install_skill() {
	destination="$1"
	run mkdir -p "$(dirname -- "$destination")"
	if [ "$MODE" = "link" ]; then
		move_aside "$destination"
		run ln -s "$SKILL_SRC" "$destination"
	else
		move_aside "$destination"
		run cp -R "$SKILL_SRC" "$destination"
	fi
	say "skill $MODE -> $destination"
}

uninstall_skill() {
	destination="$1"
	if [ -L "$destination" ]; then
		run rm -f "$destination"
		say "unlinked $destination"
	elif [ -e "$destination" ]; then
		move_aside "$destination"
	fi
}

install_cli() {
	run mkdir -p "$CLI_LIB_DIR" "$BIN_DIR"
	run cp "$CLI_SRC" "$CLI_LIB"
	run cp "$SHIM_SRC" "$BIN_SHIM"
	run chmod 755 "$BIN_SHIM"
	say "cli -> $CLI_LIB"
	say "shim -> $BIN_SHIM"
}

uninstall_cli() {
	run rm -f "$BIN_SHIM" "$CLI_LIB"
	say "removed $BIN_SHIM and $CLI_LIB"
}

say "package: $PKG_DIR"
say "mode: $MODE"
say ""

if [ "$DO_UNINSTALL" -eq 1 ]; then
	targets | while IFS= read -r destination; do uninstall_skill "$destination"; done
	uninstall_cli
	say ""
	say "Uninstall done. Skill directories were moved to *.rollback-<timestamp>;"
	say "review and delete them yourself. Nothing was deleted silently."
	exit 0
fi

targets | while IFS= read -r destination; do install_skill "$destination"; done
install_cli

say ""
if [ "$DRY_RUN" -eq 1 ]; then
	say "Dry run only; no files were changed."
	exit 0
fi
say "Installed. Verify with:"
say "  command -v plan-task && plan-task"
say "If command -v plan-task prints nothing, add $BIN_DIR to PATH yourself"
say "(the installer never edits shell profiles), then restart your agent client."
