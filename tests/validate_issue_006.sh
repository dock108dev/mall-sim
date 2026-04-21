#!/usr/bin/env bash
# Validates ISSUE-006: Phase 1 — main menu → new game → management hub flow.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*"; FAIL=$((FAIL + 1)); }

echo "=== ISSUE-006: Main Menu → New Game → Management Hub Flow ==="

# ── AC1: GAMEPLAY_SCENE_PATH targets mall_hub.tscn ───────────────────────────
echo "[AC1] GAMEPLAY_SCENE_PATH must point to mall_hub.tscn"

GM="$ROOT/game/autoload/game_manager.gd"
if grep -q 'GAMEPLAY_SCENE_PATH.*mall_hub\.tscn' "$GM"; then
	pass "GAMEPLAY_SCENE_PATH = mall_hub.tscn"
else
	fail "GAMEPLAY_SCENE_PATH does not reference mall_hub.tscn in game_manager.gd"
fi

if ! grep -q 'GAMEPLAY_SCENE_PATH.*game_world\.tscn' "$GM"; then
	pass "GAMEPLAY_SCENE_PATH does not route through game_world.tscn"
else
	fail "GAMEPLAY_SCENE_PATH still references game_world.tscn (should be mall_hub)"
fi

# ── AC2: start_new_game / load_game both call GAMEPLAY_SCENE_PATH ─────────────
echo "[AC2] start_new_game and load_game both use GAMEPLAY_SCENE_PATH"

if grep -q 'func start_new_game' "$GM"; then
	pass "start_new_game() exists in game_manager.gd"
else
	fail "start_new_game() missing from game_manager.gd"
fi

if grep -q 'func load_game' "$GM"; then
	pass "load_game() exists in game_manager.gd"
else
	fail "load_game() missing from game_manager.gd"
fi

# Both functions must call change_scene with GAMEPLAY_SCENE_PATH.
# Count occurrences — start_new_game and load_game each contribute one.
CALL_COUNT=$(grep -c 'change_scene(GAMEPLAY_SCENE_PATH)' "$GM" || true)
if [ "$CALL_COUNT" -ge 2 ]; then
	pass "start_new_game uses GAMEPLAY_SCENE_PATH for the scene transition"
	pass "load_game uses GAMEPLAY_SCENE_PATH for the scene transition"
elif [ "$CALL_COUNT" -eq 1 ]; then
	pass "one of start_new_game / load_game uses GAMEPLAY_SCENE_PATH"
	fail "only one call to change_scene(GAMEPLAY_SCENE_PATH) found — expected at least 2"
else
	fail "start_new_game does not use GAMEPLAY_SCENE_PATH"
	fail "load_game does not use GAMEPLAY_SCENE_PATH"
fi

# ── AC3: Boot completion API ──────────────────────────────────────────────────
echo "[AC3] Boot completion API: _boot_completed, mark_boot_completed, is_boot_completed"

if grep -q '_boot_completed' "$GM"; then
	pass "_boot_completed field declared in game_manager.gd"
else
	fail "_boot_completed field missing from game_manager.gd"
fi

if grep -q 'func mark_boot_completed' "$GM"; then
	pass "mark_boot_completed() exists"
else
	fail "mark_boot_completed() missing from game_manager.gd"
fi

if grep -q 'func is_boot_completed' "$GM"; then
	pass "is_boot_completed() exists"
else
	fail "is_boot_completed() missing from game_manager.gd"
fi

# ── AC4: SceneTransition injectable in GameManager ────────────────────────────
echo "[AC4] GameManager holds injectable _scene_transition"

if grep -q 'var _scene_transition' "$GM"; then
	pass "_scene_transition var declared in game_manager.gd"
else
	fail "_scene_transition var missing from game_manager.gd"
fi

ST="$ROOT/game/scripts/scene_transition.gd"
if grep -q 'func transition_to_scene' "$ST"; then
	pass "SceneTransition.transition_to_scene() exists"
else
	fail "SceneTransition.transition_to_scene() missing"
fi

if grep -q 'func transition_to_packed' "$ST"; then
	pass "SceneTransition.transition_to_packed() exists"
else
	fail "SceneTransition.transition_to_packed() missing"
fi

# ── AC5: MallHub is the hub scene and relays storefront_clicked ───────────────
echo "[AC5] MallHub wires storefront_clicked → enter_store_requested"

HUB="$ROOT/game/scenes/mall/mall_hub.gd"
if [ -f "$HUB" ]; then
	pass "mall_hub.gd exists"
else
	fail "mall_hub.gd not found"
fi

if grep -q 'storefront_clicked' "$HUB" && grep -q 'enter_store_requested' "$HUB"; then
	pass "MallHub bridges storefront_clicked → enter_store_requested"
else
	fail "MallHub does not bridge storefront_clicked to enter_store_requested"
fi

# ── AC6: debug/walkable_mall is not enabled by default ───────────────────────
echo "[AC6] debug/walkable_mall project setting is not forced true"

PROJ="$ROOT/project.godot"
if grep -q 'walkable_mall=true' "$PROJ" 2>/dev/null; then
	fail "debug/walkable_mall is set to true in project.godot (should be false/absent)"
else
	pass "debug/walkable_mall is not forced true in project.godot"
fi

# ── AC7: GUT tests exist for hub flow ────────────────────────────────────────
echo "[AC7] GUT tests for hub flow and boot completion"

for test_file in \
	"tests/gut/test_new_game_hub_flow.gd" \
	"tests/gut/test_hub_store_entry.gd" \
	"tests/gut/test_audit_overlay_toggle.gd"
do
	if [ -f "$ROOT/$test_file" ]; then
		pass "$test_file exists"
	else
		fail "$test_file missing"
	fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS/$((PASS + FAIL)) passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
	echo "ISSUE-006 checks FAILED."
	exit 1
fi
echo "All ISSUE-006 checks passed."
