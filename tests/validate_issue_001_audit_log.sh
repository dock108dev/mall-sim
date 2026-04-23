#!/usr/bin/env bash
# Validates ISSUE-001: Add AuditLog autoload for structured runtime checkpoint logging
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="$ROOT/game/autoload/audit_log.gd"
PROJECT="$ROOT/project.godot"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-001: AuditLog autoload ==="

# AC1 — Autoload registered
if grep -q '^AuditLog="\*res://game/autoload/audit_log\.gd"' "$PROJECT"; then
	pass "AuditLog autoload registered in project.godot"
else
	fail "AuditLog autoload not registered in project.godot"
fi

# Source file exists
if [ -f "$LOG_FILE" ]; then
	pass "audit_log.gd exists"
else
	fail "audit_log.gd missing"
	echo ""
	echo "=== Results: $PASS passed, $FAIL failed ==="
	exit 1
fi

# Public API
if grep -q 'func pass_check(checkpoint: StringName' "$LOG_FILE"; then
	pass "pass_check(checkpoint, detail) declared"
else
	fail "pass_check(checkpoint, detail) missing"
fi

if grep -q 'func fail_check(checkpoint: StringName, reason: String' "$LOG_FILE"; then
	pass "fail_check(checkpoint, reason) declared"
else
	fail "fail_check(checkpoint, reason) missing"
fi

# Signals
for sig in checkpoint_passed checkpoint_failed; do
	if grep -q "^signal ${sig}" "$LOG_FILE"; then
		pass "signal $sig declared"
	else
		fail "signal $sig missing"
	fi
done

# Stable stdout format
if grep -q '"AUDIT: PASS %s"' "$LOG_FILE"; then
	pass "stable PASS print format present"
else
	fail "stable PASS print format missing"
fi

if grep -q '"AUDIT: FAIL %s"' "$LOG_FILE"; then
	pass "stable FAIL print format present"
else
	fail "stable FAIL print format missing"
fi

# Ring buffer
if grep -q 'RING_CAPACITY: int = 256' "$LOG_FILE"; then
	pass "ring buffer capacity = 256"
else
	fail "ring buffer capacity != 256"
fi

if grep -q 'func recent(n: int) -> Array\[Dictionary\]' "$LOG_FILE"; then
	pass "recent(n) -> Array[Dictionary] declared"
else
	fail "recent(n) -> Array[Dictionary] missing"
fi

# Duplicate-pass warning
if grep -q 'duplicate PASS' "$LOG_FILE"; then
	pass "duplicate-checkpoint warning present"
else
	fail "duplicate-checkpoint warning missing"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
