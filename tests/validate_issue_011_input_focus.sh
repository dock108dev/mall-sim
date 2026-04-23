#!/usr/bin/env bash
# Validates ISSUE-011 (.aidlc/issues): InputFocus autoload + sole ownership.
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INPUT_FOCUS="$ROOT/game/autoload/input_focus.gd"
PROJECT="$ROOT/project.godot"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-011 (aidlc): InputFocus ==="

if [ -f "$INPUT_FOCUS" ]; then
	pass "exists: game/autoload/input_focus.gd"
else
	fail "missing: game/autoload/input_focus.gd"
fi

if grep -q '^InputFocus="\*res://game/autoload/input_focus.gd"' "$PROJECT"; then
	pass "registered as autoload in project.godot"
else
	fail "InputFocus not registered in [autoload] section of project.godot"
fi

if grep -Eq 'func push_context\(ctx: StringName\)' "$INPUT_FOCUS"; then
	pass "exposes push_context(ctx: StringName)"
else
	fail "push_context(ctx: StringName) signature missing"
fi

if grep -Eq 'func pop_context\(\) -> StringName' "$INPUT_FOCUS"; then
	pass "exposes pop_context() -> StringName"
else
	fail "pop_context() -> StringName signature missing"
fi

if grep -Eq 'func current\(\) -> StringName' "$INPUT_FOCUS"; then
	pass "exposes current() -> StringName"
else
	fail "current() -> StringName signature missing"
fi

if grep -q 'signal context_changed' "$INPUT_FOCUS"; then
	pass "declares context_changed signal"
else
	fail "context_changed signal missing"
fi

if grep -q 'CHECKPOINT_NON_EMPTY' "$INPUT_FOCUS" \
	&& grep -q 'fail_check(CHECKPOINT_NON_EMPTY' "$INPUT_FOCUS"; then
	pass "wires AuditLog.fail_check on empty-stack-after-transition"
else
	fail "no AuditLog.fail_check wiring for input_focus_non_empty"
fi

if grep -q '_input_focus_allows_gameplay' \
	"$ROOT/game/scripts/player/player_controller.gd"; then
	pass "PlayerController gates input on InputFocus.current()"
else
	fail "PlayerController is not gated on InputFocus"
fi

bash "$ROOT/tests/validate_input_focus.sh" \
	&& pass "validate_input_focus.sh: zero set_process_input bypasses" \
	|| fail "validate_input_focus.sh reported bypasses"

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
