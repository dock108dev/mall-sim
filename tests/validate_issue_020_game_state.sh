#!/usr/bin/env bash
# Validates .aidlc/issues/ISSUE-020: GameState autoload (active run state).
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAMESTATE="$ROOT/game/autoload/game_state.gd"
PROJECT="$ROOT/project.godot"
TEST="$ROOT/tests/unit/test_game_state.gd"
EVENTBUS="$ROOT/game/autoload/event_bus.gd"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-020 (aidlc): GameState autoload ==="

[ -f "$GAMESTATE" ] && pass "exists: game/autoload/game_state.gd" \
	|| fail "missing: game/autoload/game_state.gd"

if grep -q '^GameState="\*res://game/autoload/game_state.gd"' "$PROJECT"; then
	pass "registered as autoload in project.godot"
else
	fail "GameState not registered in [autoload] section"
fi

if grep -Eq 'var active_store_id: StringName' "$GAMESTATE"; then
	pass "typed field active_store_id: StringName"
else
	fail "active_store_id not typed as StringName"
fi

if grep -Eq 'var day: int' "$GAMESTATE"; then
	pass "typed field day: int"
else
	fail "day not typed as int"
fi

if grep -Eq 'var money: int' "$GAMESTATE"; then
	pass "typed field money: int"
else
	fail "money not typed as int"
fi

if grep -Eq 'var flags: Dictionary' "$GAMESTATE"; then
	pass "typed field flags: Dictionary"
else
	fail "flags not typed as Dictionary"
fi

if grep -Eq 'func reset_new_game\(\) -> void' "$GAMESTATE"; then
	pass "exposes reset_new_game() -> void"
else
	fail "reset_new_game() signature missing"
fi

if grep -Eq 'func set_active_store\(id: StringName\) -> void' "$GAMESTATE"; then
	pass "exposes set_active_store(id: StringName) -> void"
else
	fail "set_active_store signature missing or wrong"
fi

# AC: no scene/camera/input ownership in GameState (pure data). Strip comments
# so the doc string is allowed to mention these owners by name.
NONCOMMENT="$(sed -E 's/[[:space:]]*#.*$//' "$GAMESTATE")"
if echo "$NONCOMMENT" | grep -Eq 'change_scene_to_|CameraAuthority\.|InputFocus\.'; then
	fail "GameState code references scene/camera/input ownership (must be pure data)"
else
	pass "no scene_change / camera / input coupling in GameState code"
fi

if grep -q 'signal run_state_changed' "$EVENTBUS"; then
	pass "EventBus declares run_state_changed signal"
else
	fail "EventBus.run_state_changed not declared"
fi

[ -f "$TEST" ] && pass "GUT test exists: tests/unit/test_game_state.gd" \
	|| fail "missing GUT test tests/unit/test_game_state.gd"

if grep -q 'reset_new_game' "$TEST"; then
	pass "test covers reset_new_game"
else
	fail "test does not cover reset_new_game"
fi

if grep -q 'set_active_store' "$TEST"; then
	pass "test covers set_active_store"
else
	fail "test does not cover set_active_store"
fi

if grep -q 'assert_signal_emit_count' "$TEST"; then
	pass "test asserts signal emission count"
else
	fail "test does not assert emission count"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
