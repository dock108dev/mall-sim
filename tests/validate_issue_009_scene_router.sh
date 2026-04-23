#!/usr/bin/env bash
# Validates ISSUE-009 (.aidlc/issues): SceneRouter autoload + sole ownership.
#
# Note: tests/validate_issue_009.sh exists for an unrelated legacy issue. This
# script covers the aidlc-tracked ISSUE-009 specifically.
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROUTER="$ROOT/game/autoload/scene_router.gd"
PROJECT="$ROOT/project.godot"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-009 (aidlc): SceneRouter ==="

if [ -f "$ROUTER" ]; then
	pass "exists: game/autoload/scene_router.gd"
else
	fail "missing: game/autoload/scene_router.gd"
fi

if grep -q '^SceneRouter="\*res://game/autoload/scene_router.gd"' "$PROJECT"; then
	pass "registered as autoload in project.godot"
else
	fail "SceneRouter not registered in [autoload] section of project.godot"
fi

if grep -Eq 'func route_to\(target: StringName, payload: Dictionary' "$ROUTER"; then
	pass "exposes route_to(target, payload)"
else
	fail "route_to(target: StringName, payload: Dictionary) signature missing"
fi

if grep -Eq '^signal scene_ready\(target: StringName, payload: Dictionary\)' "$ROUTER"; then
	pass "exposes scene_ready(target, payload) signal"
else
	fail "scene_ready(target, payload) signal missing"
fi

if grep -q 'AUDIT: PASS scene_change_ok' "$ROUTER" \
	|| grep -q 'pass_check(&"scene_change_ok"' "$ROUTER"; then
	pass "emits AUDIT scene_change_ok on success"
else
	fail "no scene_change_ok emission found"
fi

bash "$ROOT/tests/validate_scene_router_owner.sh" \
	&& pass "validate_scene_router_owner.sh: zero bypasses" \
	|| fail "validate_scene_router_owner.sh reported bypasses"

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
