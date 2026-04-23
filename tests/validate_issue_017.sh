#!/usr/bin/env bash
# Validates ISSUE-017 (.aidlc/issues): Interactable component + HUD
# objective text bound to store state.
set -u

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

INTERACTABLE_GD="$ROOT/game/scripts/components/interactable.gd"
STORE_GD="$ROOT/game/scripts/stores/store_controller.gd"
HUD_GD="$ROOT/game/scenes/ui/hud.gd"
HUD_TSCN="$ROOT/game/scenes/ui/hud.tscn"
EVENTBUS_GD="$ROOT/game/autoload/event_bus.gd"
TEST_GD="$ROOT/tests/gut/test_interactable_objective_issue_017.gd"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-017: Interactable + HUD objective binding ==="

# AC1: Interactable exposes display_name, action_verb, interacted signal.
if grep -q '^class_name Interactable' "$INTERACTABLE_GD"; then
	pass "interactable.gd defines class_name Interactable"
else
	fail "class_name Interactable missing"
fi

if grep -q '@export var display_name' "$INTERACTABLE_GD"; then
	pass "Interactable exposes display_name"
else
	fail "Interactable.display_name missing"
fi

if grep -q '@export var action_verb' "$INTERACTABLE_GD"; then
	pass "Interactable exposes action_verb"
else
	fail "Interactable.action_verb missing"
fi

if grep -q '^signal interacted' "$INTERACTABLE_GD" \
	&& grep -q 'signal interacted_by' "$INTERACTABLE_GD"; then
	pass "Interactable declares interacted + interacted_by signals"
else
	fail "Interactable interacted/interacted_by signals missing"
fi

if grep -q 'add_to_group(&"interactables")' "$INTERACTABLE_GD"; then
	pass "Interactable joins the 'interactables' group used by StoreReadyContract"
else
	fail "Interactable not added to 'interactables' group"
fi

if grep -q 'func interact(by: Node = null)' "$INTERACTABLE_GD" \
	&& grep -q 'interacted_by.emit(by)' "$INTERACTABLE_GD"; then
	pass "interact(by) emits interacted_by(by)"
else
	fail "interact(by) does not emit interacted_by(by)"
fi

# AC2: StoreController.count_visible_interactables() returns visible only.
if grep -q 'func count_visible_interactables' "$STORE_GD"; then
	pass "StoreController.count_visible_interactables() defined"
else
	fail "count_visible_interactables() missing on StoreController"
fi

if grep -q 'is_visible_in_tree' "$STORE_GD"; then
	pass "count uses is_visible_in_tree filter"
else
	fail "count_visible_interactables does not filter on is_visible_in_tree"
fi

if grep -q 'func register_interactable' "$STORE_GD" \
	&& grep -q '_register_interactables' "$STORE_GD"; then
	pass "StoreController auto-registers interactables on _ready"
else
	fail "StoreController interactable registration missing"
fi

# AC3: HUD bound to StoreController.current_objective_text via signal.
if grep -q 'signal objective_text_changed' "$STORE_GD" \
	&& grep -q 'var current_objective_text' "$STORE_GD" \
	&& grep -q 'func set_objective_text' "$STORE_GD"; then
	pass "StoreController exposes current_objective_text + set_objective_text"
else
	fail "StoreController objective text API missing"
fi

if grep -q 'signal objective_text_changed' "$EVENTBUS_GD"; then
	pass "EventBus mirrors objective_text_changed"
else
	fail "EventBus.objective_text_changed signal missing"
fi

if grep -q 'name="ObjectiveLabel"' "$HUD_TSCN"; then
	pass "hud.tscn contains ObjectiveLabel node"
else
	fail "hud.tscn missing ObjectiveLabel node"
fi

if grep -q 'EventBus.objective_text_changed.connect' "$HUD_GD" \
	&& grep -q '_on_objective_text_changed' "$HUD_GD"; then
	pass "HUD binds ObjectiveLabel to EventBus.objective_text_changed"
else
	fail "HUD ObjectiveLabel binding missing"
fi

# AC4: StoreReadyContract objective_matches_action() lives on controller.
if grep -q 'func objective_matches_action' "$STORE_GD"; then
	pass "StoreController.objective_matches_action() defined (Contract INV_OBJECTIVE)"
else
	fail "objective_matches_action() missing on StoreController"
fi

# AC5: GUT integration test present and covers the required cases.
if [ -f "$TEST_GD" ]; then
	pass "GUT integration test present"
else
	fail "tests/gut/test_interactable_objective_issue_017.gd missing"
fi

if grep -q 'test_count_visible_interactables_returns_one_for_shelf' "$TEST_GD" \
	&& grep -q 'test_objective_match_passes_when_text_references_action' "$TEST_GD" \
	&& grep -q 'test_hud_objective_label_updates_within_one_frame' "$TEST_GD"; then
	pass "GUT test covers count, objective match, and HUD binding"
else
	fail "GUT test missing required cases"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
