#!/usr/bin/env bash
# ISSUE-011: InputFocus is the SOLE owner of input-mode/focus context.
# Direct `set_process_input(...)` / `set_process_unhandled_input(...)` calls
# in production game code are forbidden — gameplay scripts must gate
# themselves on `InputFocus.current()` instead.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INPUT_FOCUS_REL="game/autoload/input_focus.gd"

echo "=== ISSUE-011: InputFocus sole-owner check ==="

if [ ! -f "$ROOT/$INPUT_FOCUS_REL" ]; then
	echo "  FAIL: missing $INPUT_FOCUS_REL"
	exit 1
fi

violations=$(
	grep -RIn --include='*.gd' \
		-E 'set_process_input\(|set_process_unhandled_input\(' \
		"$ROOT/game" \
		| grep -v "^${ROOT}/${INPUT_FOCUS_REL}:" \
		| grep -v "^${ROOT}/game/tests/" \
		| grep -vE ':\s*#' \
		|| true
)

if [ -n "$violations" ]; then
	echo "  FAIL: set_process_input(...) outside InputFocus autoload:"
	echo "$violations" | sed 's|^|    |'
	exit 1
fi

echo "  PASS: zero direct set_process_input writes in game/ source"
exit 0
