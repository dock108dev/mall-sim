#!/usr/bin/env bash
# Validates ISSUE-016 (.aidlc/issues): PlayerController for store interior —
# movement + interact input gated by InputFocus.
set -u

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PLAYER_GD="$ROOT/game/scripts/player/store_player_body.gd"
PLAYER_TSCN="$ROOT/game/scenes/player/store_player_body.tscn"
TEST_GD="$ROOT/tests/unit/test_store_player_body.gd"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-016: StorePlayerBody for store interior ==="

# AC1: scene instantiates a CharacterBody with a class_name player script
if [ -f "$PLAYER_TSCN" ]; then
	pass "player scene exists ($PLAYER_TSCN)"
else
	fail "player scene missing ($PLAYER_TSCN)"
fi

if grep -q 'type="CharacterBody3D"' "$PLAYER_TSCN" 2>/dev/null \
	|| grep -q 'type="CharacterBody2D"' "$PLAYER_TSCN" 2>/dev/null; then
	pass "player scene root is a CharacterBody"
else
	fail "player scene root is not a CharacterBody"
fi

if [ -f "$PLAYER_GD" ] && grep -q '^class_name StorePlayerBody' "$PLAYER_GD"; then
	pass "player script defines class_name StorePlayerBody"
else
	fail "player script missing class_name StorePlayerBody"
fi

# Node named "Player" so StoreReadyContract INV_PLAYER passes.
if grep -q 'name="Player"' "$PLAYER_TSCN"; then
	pass "player node is named Player (satisfies StoreReadyContract)"
else
	fail "player node must be named Player for StoreReadyContract"
fi

# AC2: interact signal gated on current_interactable AND InputFocus context.
if grep -q 'signal interact_pressed' "$PLAYER_GD"; then
	pass "interact_pressed signal declared"
else
	fail "interact_pressed signal missing"
fi

if grep -q 'current_interactable == null' "$PLAYER_GD" \
	&& grep -q '_gameplay_allowed' "$PLAYER_GD"; then
	pass "interact gated by current_interactable and gameplay focus"
else
	fail "interact gating logic (null check + focus) missing"
fi

if grep -q 'move_and_slide' "$PLAYER_GD" \
	&& grep -q 'Input.get_vector' "$PLAYER_GD"; then
	pass "movement uses Input.get_vector + move_and_slide"
else
	fail "movement implementation missing Input.get_vector / move_and_slide"
fi

# AC3: gameplay focus is managed by StoreController, not StorePlayerBody.
# The body must read CTX_STORE_GAMEPLAY (to gate input) but must NOT push/pop
# it — push/pop is owned by StoreController on EventBus.store_entered/exited
# per docs/architecture/ownership.md row 5.
if grep -q 'CTX_STORE_GAMEPLAY' "$PLAYER_GD"; then
	pass "reads CTX_STORE_GAMEPLAY for input gating"
else
	fail "CTX_STORE_GAMEPLAY reference missing (needed for _gameplay_allowed)"
fi

if grep -q 'push_context' "$PLAYER_GD" \
	|| grep -q 'pop_context' "$PLAYER_GD"; then
	fail "StorePlayerBody must not push/pop InputFocus — owned by StoreController"
else
	pass "StorePlayerBody does not push/pop CTX_STORE_GAMEPLAY (owned by StoreController)"
fi

if grep -q 'get_store_id' "$PLAYER_GD"; then
	pass "asserts parent chain exposes get_store_id (store scene root)"
else
	fail "store scene root assertion missing (get_store_id lookup)"
fi

# AC4: AuditLog PLAYER_SPAWNED emission with scene path.
if grep -q 'CHECKPOINT_PLAYER_SPAWNED' "$PLAYER_GD" \
	&& grep -q 'player_spawned' "$PLAYER_GD"; then
	pass "AuditLog player_spawned checkpoint emitted"
else
	fail "player_spawned checkpoint missing"
fi

if grep -q 'scene_file_path' "$PLAYER_GD"; then
	pass "player_spawned includes scene path in detail"
else
	fail "player_spawned does not include scene path"
fi

if grep -q 'fail_check' "$PLAYER_GD" \
	&& grep -q 'InputFocus autoload missing' "$PLAYER_GD"; then
	pass "fails loudly when InputFocus autoload absent"
else
	fail "missing loud failure for absent InputFocus"
fi

# AC5: GUT unit test present with the required coverage.
if [ -f "$TEST_GD" ]; then
	pass "GUT unit test file present"
else
	fail "tests/unit/test_store_player_body.gd missing"
fi

if grep -q 'test_interact_suppressed_when_modal_on_top' "$TEST_GD" \
	&& grep -q 'test_interact_resumes_after_modal_pops' "$TEST_GD"; then
	pass "GUT test covers interact suppression + restoration"
else
	fail "GUT test must cover modal suppression and focus restoration"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
