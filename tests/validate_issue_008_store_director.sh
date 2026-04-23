#!/usr/bin/env bash
# Validates .aidlc/issues/ISSUE-008: StoreDirector autoload + state machine.
# Static checks only — behavioural acceptance is covered by
# tests/unit/test_store_director.gd under GUT. (Distinct from the legacy
# tests/validate_issue_008.sh / *_theme.sh in another numbering namespace.)
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIRECTOR="$ROOT/game/autoload/store_director.gd"
PROJECT="$ROOT/project.godot"
TEST="$ROOT/tests/unit/test_store_director.gd"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-008 (aidlc): StoreDirector ==="

[ -f "$DIRECTOR" ] && pass "exists: game/autoload/store_director.gd" \
	|| fail "missing: game/autoload/store_director.gd"

[ -f "$TEST" ] && pass "exists: tests/unit/test_store_director.gd" \
	|| fail "missing: tests/unit/test_store_director.gd"

if grep -q '^StoreDirector="\*res://game/autoload/store_director.gd"' "$PROJECT"; then
	pass "registered as autoload in project.godot"
else
	fail "StoreDirector not registered in [autoload] section"
fi

if grep -Eq 'func enter_store\(store_id: StringName\) -> bool' "$DIRECTOR"; then
	pass "exposes enter_store(store_id: StringName) -> bool"
else
	fail "enter_store(store_id) signature missing or wrong"
fi

for sig in "signal store_ready" "signal store_failed"; do
	if grep -q "$sig" "$DIRECTOR"; then
		pass "declares $sig"
	else
		fail "missing $sig"
	fi
done

for st in IDLE REQUESTED LOADING_SCENE INSTANTIATING VERIFYING READY FAILED; do
	if grep -q "$st," "$DIRECTOR" || grep -Eq "$st\b" "$DIRECTOR"; then
		pass "state enum includes $st"
	else
		fail "state enum missing $st"
	fi
done

if grep -q 'StoreReadyContract.check' "$DIRECTOR"; then
	pass "delegates verification to StoreReadyContract.check"
else
	fail "does not call StoreReadyContract.check"
fi

if grep -Eq '\bawait\b' "$DIRECTOR"; then
	pass "uses await (async state machine)"
else
	fail "no await in director — state machine cannot be async"
fi

if grep -q 'change_scene_to_file\|change_scene_to_packed' "$DIRECTOR"; then
	fail "director calls change_scene_to_* directly — must route through SceneRouter (ISSUE-009)"
else
	pass "no direct change_scene_to_* calls (defers to SceneRouter)"
fi

if grep -q 'unknown store_id' "$DIRECTOR"; then
	pass "fails loud on unknown store_id"
else
	fail "no unknown store_id failure path"
fi

if grep -q 'rejected' "$DIRECTOR"; then
	pass "rejects concurrent enter_store calls"
else
	fail "no concurrent-call rejection path"
fi

# Test coverage of the four acceptance criteria.
if grep -q 'enter_store(&"unknown")' "$TEST"; then
	pass "test covers unknown store_id path"
else
	fail "test does not call enter_store(&\"unknown\")"
fi

if grep -q 'store_ready must fire exactly once\|ready_emissions.size() == 1\|assert_eq(ready_emissions.size(), 1' "$TEST"; then
	pass "test asserts store_ready fires exactly once on happy path"
else
	fail "test does not assert single store_ready emission"
fi

if grep -q 'director_state_' "$TEST"; then
	pass "test asserts AuditLog state checkpoints"
else
	fail "test does not check AuditLog state checkpoints"
fi

if grep -q 'concurrent\|second_ok' "$TEST"; then
	pass "test covers concurrent-call rejection"
else
	fail "test does not cover concurrent-call rejection"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
