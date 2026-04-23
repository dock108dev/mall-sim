#!/usr/bin/env bash
# Validates ISSUE-018 (.aidlc/issues): Full-screen fail diagnostic card for
# StoreReady invariant failures.
set -u

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

CARD_TSCN="$ROOT/game/scenes/ui/fail_card.tscn"
CARD_GD="$ROOT/game/scenes/ui/fail_card.gd"
RESULT_GD="$ROOT/game/scripts/stores/store_ready_result.gd"
DIRECTOR_GD="$ROOT/game/autoload/store_director.gd"
PROJECT="$ROOT/project.godot"
GUT_TEST="$ROOT/tests/gut/test_fail_card_issue_018.gd"
NO_HEX="$ROOT/tests/validate_no_hex_colors.sh"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-018: FailCard diagnostic ==="

# AC1: fail_card.tscn + fail_card.gd exist, director wires them.
if [ -f "$CARD_TSCN" ]; then
	pass "fail_card.tscn exists"
else
	fail "fail_card.tscn missing"
fi

if [ -f "$CARD_GD" ]; then
	pass "fail_card.gd exists"
else
	fail "fail_card.gd missing"
fi

if grep -q '_raise_fail_card' "$DIRECTOR_GD"; then
	pass "StoreDirector._raise_fail_card wired from _fail()"
else
	fail "StoreDirector does not raise FailCard on failure"
fi

# AC2: card displays failed_invariant, reason, store_id; has Return button.
if grep -q 'InvariantLabel' "$CARD_TSCN" \
	&& grep -q 'ReasonLabel' "$CARD_TSCN" \
	&& grep -q 'StoreIdLabel' "$CARD_TSCN"; then
	pass "card scene exposes invariant / reason / store_id labels"
else
	fail "card scene missing one of invariant/reason/store_id labels"
fi

if grep -q 'ReturnToMallButton' "$CARD_TSCN" \
	&& grep -q 'ReturnToMallButton' "$CARD_GD"; then
	pass "Return to Mall button present and bound"
else
	fail "Return to Mall button missing"
fi

if grep -q 'route_to.*mall_hub' "$CARD_GD"; then
	pass "Return button routes via SceneRouter to mall_hub"
else
	fail "FailCard does not route back via SceneRouter"
fi

if grep -q 'func failed_invariant' "$RESULT_GD"; then
	pass "StoreReadyResult.failed_invariant() accessor defined"
else
	fail "StoreReadyResult.failed_invariant() missing"
fi

# AC3: InputFocus modal push/pop.
if grep -q 'push_context' "$CARD_GD" \
	&& grep -q 'pop_context' "$CARD_GD"; then
	pass "FailCard pushes + pops InputFocus modal context"
else
	fail "FailCard does not push/pop InputFocus modal context"
fi

# AC4: No bare hex colors in .tscn files (project-wide guard).
if bash "$NO_HEX" > /dev/null 2>&1; then
	pass "no bare hex colors in .tscn files"
else
	fail "validate_no_hex_colors.sh failed"
fi

# AC5: AuditLog SHOWN + DISMISSED checkpoints.
if grep -q 'CHECKPOINT_SHOWN.*fail_card_shown' "$CARD_GD" \
	&& grep -q 'CHECKPOINT_DISMISSED.*fail_card_dismissed' "$CARD_GD"; then
	pass "FailCard declares fail_card_shown + fail_card_dismissed constants"
else
	fail "FailCard checkpoint constants missing"
fi

if grep -q '_audit_fail(CHECKPOINT_SHOWN' "$CARD_GD" \
	&& grep -q '_audit_pass(CHECKPOINT_DISMISSED' "$CARD_GD"; then
	pass "FailCard emits SHOWN (fail) + DISMISSED (pass) to AuditLog"
else
	fail "FailCard does not emit SHOWN/DISMISSED to AuditLog"
fi

# AC6: GUT integration test present with required cases.
if [ -f "$GUT_TEST" ]; then
	pass "GUT integration test present"
else
	fail "tests/gut/test_fail_card_issue_018.gd missing"
fi

if grep -q 'test_show_failure_makes_card_visible' "$GUT_TEST" \
	&& grep -q 'test_show_failure_pushes_modal_focus_context' "$GUT_TEST" \
	&& grep -q 'test_mall_gameplay_input_suppressed_while_card_visible' "$GUT_TEST" \
	&& grep -q 'test_dismiss_emits_fail_card_dismissed_audit_checkpoint' "$GUT_TEST"; then
	pass "GUT test covers visible, modal push, gameplay suppression, dismiss audit"
else
	fail "GUT test missing required cases"
fi

# Autoload registration.
if grep -q '^FailCard="\*res://game/scenes/ui/fail_card.tscn"' "$PROJECT"; then
	pass "FailCard registered as autoload in project.godot"
else
	fail "FailCard autoload registration missing from project.godot"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
