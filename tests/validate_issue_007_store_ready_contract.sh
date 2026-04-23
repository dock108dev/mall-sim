#!/usr/bin/env bash
# Validates ISSUE-007 (aidlc planning set): StoreReadyContract + StoreReadyResult.
#
# Static checks only — the behavioural acceptance criteria are covered by
# tests/unit/test_store_ready_contract.gd under GUT. This script asserts the
# files exist, expose the required class_names, enumerate all 10 invariants,
# and do not introduce `await` into the contract check (AC4).
#
# Note: tests/validate_issue_007.sh already exists for a legacy per-store SFX
# issue; the ISSUE-007 from .aidlc/issues/ is this contract work. The two are
# unrelated.
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTRACT="$ROOT/game/scripts/stores/store_ready_contract.gd"
RESULT="$ROOT/game/scripts/stores/store_ready_result.gd"
UNIT_TEST="$ROOT/tests/unit/test_store_ready_contract.gd"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-007 (aidlc): StoreReadyContract ==="

for f in "$CONTRACT" "$RESULT" "$UNIT_TEST"; do
	if [ -f "$f" ]; then
		pass "exists: ${f#$ROOT/}"
	else
		fail "missing: ${f#$ROOT/}"
	fi
done

grep -q '^class_name StoreReadyContract' "$CONTRACT" \
	&& pass "class_name StoreReadyContract" \
	|| fail "class_name StoreReadyContract missing"

grep -q '^class_name StoreReadyResult' "$RESULT" \
	&& pass "class_name StoreReadyResult" \
	|| fail "class_name StoreReadyResult missing"

for pattern in 'var ok: bool' 'var failures: Array\[StringName\]' 'var reason: String'; do
	if grep -Eq "$pattern" "$RESULT"; then
		pass "StoreReadyResult has $pattern"
	else
		fail "StoreReadyResult missing $pattern"
	fi
done

INVARIANTS=(
	store_id_resolved
	scene_loaded
	controller_initialized
	content_instantiated
	camera_current
	player_present
	input_gameplay
	no_modal_focus
	interaction_count_ge_1
	objective_matches_action
)
for inv in "${INVARIANTS[@]}"; do
	if grep -q "&\"$inv\"" "$CONTRACT"; then
		pass "invariant enumerated: $inv"
	else
		fail "invariant missing: $inv"
	fi
done

if grep -vE '^\s*#|^\s*##' "$CONTRACT" | grep -nE '\bawait\b'; then
	fail "contract uses await (AC4 requires synchronous check)"
else
	pass "no await in contract (AC4: synchronous)"
fi

if grep -Eq 'static func check\(scene: Node\) -> StoreReadyResult' "$CONTRACT"; then
	pass "check(scene: Node) -> StoreReadyResult declared"
else
	fail "check(scene: Node) -> StoreReadyResult signature missing"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
