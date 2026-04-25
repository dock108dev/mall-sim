#!/usr/bin/env bash
# Validates ISSUE-018: Mall overview store navigation hub scene.
set -euo pipefail

PASS=0
FAIL=0

check() {
	local label="$1"
	shift
	if "$@" >/dev/null 2>&1; then
		echo "  PASS: $label"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $label"
		FAIL=$((FAIL + 1))
	fi
}

echo ""
echo "=== ISSUE-018: Mall Overview Navigation Hub ==="
echo ""

OVERVIEW="game/scenes/mall/mall_overview.tscn"
OVERVIEW_GD="game/scenes/mall/mall_overview.gd"
CARD="game/scenes/mall/store_slot_card.tscn"
CARD_GD="game/scenes/mall/store_slot_card.gd"
GAME_WORLD="game/scenes/world/game_world.gd"
TEST_FILE="tests/gut/test_mall_overview.gd"

echo "[AC1] mall_overview.tscn at required path"
check "mall_overview.tscn exists" test -f "$OVERVIEW"
check "mall_overview.tscn is tracked by git" git ls-files --error-unmatch "$OVERVIEW"

echo ""
echo "[AC2] Store slots and live data"
check "MallOverview class defined" grep -q "class_name MallOverview" "$OVERVIEW_GD"
check "setup() wires inventory and economy systems" \
	grep -q "func setup" "$OVERVIEW_GD"
check "StoreSlotCard class defined" grep -q "class_name StoreSlotCard" "$CARD_GD"
check "revenue updates via customer_purchased signal" \
	grep -q "_on_customer_purchased" "$OVERVIEW_GD"
check "revenue updates via inventory_updated signal" \
	grep -q "_on_inventory_updated" "$OVERVIEW_GD"
check "StoreGrid node present in tscn" grep -q "StoreGrid" "$OVERVIEW"
check "store cards populated from ContentRegistry" \
	grep -q "ContentRegistry.get_all_store_ids" "$OVERVIEW_GD"

echo ""
echo "[AC3] Click-to-navigate emits store_selected and enter_store_requested"
check "store_selected signal declared" grep -q "signal store_selected" "$OVERVIEW_GD"
check "store_selected signal on card" grep -q "signal store_selected" "$CARD_GD"
check "enter_store_requested emitted on card click" \
	grep -q "EventBus.enter_store_requested.emit" "$OVERVIEW_GD"

echo ""
echo "[AC4] Alert badge for low stock or pending event"
check "AlertBadge node in store_slot_card.tscn" grep -q "AlertBadge" "$CARD"
check "low stock threshold < 3 items" grep -q "count < 3" "$CARD_GD"
check "event_pending flag on card" grep -q "set_event_pending" "$CARD_GD"
check "market_event_triggered wired in overview" \
	grep -q "_on_market_event_triggered" "$OVERVIEW_GD"
check "random_event_triggered wired in overview" \
	grep -q "_on_random_event_triggered" "$OVERVIEW_GD"

echo ""
echo "[AC5] No direct store controller references"
check "no StoreController direct reference in overview gd" \
	bash -c '! grep -q "StoreController\|store_controller\|get_node.*store" '"$OVERVIEW_GD"
check "no StoreController direct reference in card gd" \
	bash -c '! grep -q "StoreController\|store_controller" '"$CARD_GD"

echo ""
echo "[AC6] Day close button accessible from overview"
check "DayCloseButton node present in tscn" grep -q "DayCloseButton" "$OVERVIEW"
check "day_close_requested emitted on button press" \
	grep -q "EventBus.day_close_requested.emit" "$OVERVIEW_GD"

echo ""
echo "[AC7] GameWorld wires the mall overview"
check "MallOverviewScene preloaded in game_world" \
	grep -q "_MALL_OVERVIEW_SCENE" "$GAME_WORLD"
check "mall overview instantiated in game_world" \
	grep -q "_mall_overview" "$GAME_WORLD"
check "mall overview setup called with systems" \
	grep -q "_mall_overview.setup" "$GAME_WORLD"

echo ""
echo "[AC8] GUT tests present"
check "test_mall_overview.gd exists" test -f "$TEST_FILE"
check "day close button test present" \
	grep -q "test_day_close_button_emits_event_bus_signal" "$TEST_FILE"
check "alert badge low stock test present" \
	grep -q "test_store_slot_card_alert_visible_when_low_stock" "$TEST_FILE"
check "store_selected signal test present" \
	grep -q "test_store_slot_card_emits_store_selected" "$TEST_FILE"

echo ""
TOTAL=$((PASS + FAIL))
echo "=== ISSUE-018 Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""
if [ "$FAIL" -eq 0 ]; then
	echo "All ISSUE-018 acceptance criteria validated."
else
	echo "Some ISSUE-018 checks failed."
	exit 1
fi
