#!/usr/bin/env bash
# Validates ISSUE-010 (.aidlc/issues): CameraAuthority autoload + sole ownership.
#
# Note: tests/validate_issue_010.sh exists for an unrelated legacy issue.
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUTHORITY="$ROOT/game/autoload/camera_authority.gd"
PROJECT="$ROOT/project.godot"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-010 (aidlc): CameraAuthority ==="

if [ -f "$AUTHORITY" ]; then
	pass "exists: game/autoload/camera_authority.gd"
else
	fail "missing: game/autoload/camera_authority.gd"
fi

if grep -q '^CameraAuthority="\*res://game/autoload/camera_authority.gd"' "$PROJECT"; then
	pass "registered as autoload in project.godot"
else
	fail "CameraAuthority not registered in [autoload] section of project.godot"
fi

if grep -Eq 'func request_current\(cam: Variant, source: StringName\)' "$AUTHORITY"; then
	pass "exposes request_current(cam, source)"
else
	fail "request_current(cam: Variant, source: StringName) signature missing"
fi

if grep -Eq 'func current\(\) -> Node' "$AUTHORITY"; then
	pass "exposes current() -> Node"
else
	fail "current() -> Node signature missing"
fi

if grep -Eq 'func assert_single_active\(\) -> bool' "$AUTHORITY"; then
	pass "exposes assert_single_active() -> bool"
else
	fail "assert_single_active() -> bool signature missing"
fi

if grep -q 'CHECKPOINT_SINGLE_ACTIVE' "$AUTHORITY" \
	&& grep -q 'fail_check(CHECKPOINT_SINGLE_ACTIVE' "$AUTHORITY"; then
	pass "wires AuditLog.fail_check on violations"
else
	fail "no AuditLog.fail_check wiring for camera_single_active"
fi

bash "$ROOT/tests/validate_camera_ownership.sh" \
	&& pass "validate_camera_ownership.sh: zero bypasses" \
	|| fail "validate_camera_ownership.sh reported bypasses"

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
