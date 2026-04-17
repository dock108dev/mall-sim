#!/usr/bin/env bash
# Validates ISSUE-076: OrderSystem supplier tiers, order workflow, and delivery timers.
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ORDER_SYSTEM="$ROOT/game/scripts/systems/order_system.gd"
EVENT_BUS="$ROOT/game/autoload/event_bus.gd"
GAME_WORLD="$ROOT/game/scenes/world/game_world.tscn"
SAVE_MANAGER="$ROOT/game/scripts/core/save_manager.gd"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

contains() {
	local file="$1"
	local pattern="$2"
	grep -Eq "$pattern" "$file"
}

echo "=== ISSUE-076: OrderSystem supplier tiers, workflow, and delivery ==="
echo ""

echo "[AC1] OrderSystem exists and is registered in GameWorld"
if [ -f "$ORDER_SYSTEM" ]; then
	pass "order_system.gd exists"
else
	fail "order_system.gd missing"
fi

if contains "$ORDER_SYSTEM" 'class_name[[:space:]]+OrderSystem'; then
	pass "OrderSystem class_name declared"
else
	fail "OrderSystem class_name missing"
fi

if contains "$GAME_WORLD" 'OrderSystem".*parent="\."'; then
	pass "GameWorld has OrderSystem child"
else
	fail "GameWorld missing OrderSystem child"
fi

if contains "$GAME_WORLD" 'path="res://game/scripts/systems/order_system.gd"'; then
	pass "GameWorld references order_system.gd"
else
	fail "GameWorld does not reference order_system.gd"
fi

echo ""
echo "[AC2] SupplierTier enum and tier gates"
for tier in BASIC SPECIALTY LIQUIDATOR PREMIUM; do
	if contains "$ORDER_SYSTEM" "enum SupplierTier.*${tier}"; then
		pass "SupplierTier includes $tier"
	else
		fail "SupplierTier missing $tier"
	fi
done

if contains "$ORDER_SYSTEM" '"required_reputation_tier":[[:space:]]*2'; then
	pass "SPECIALTY requires reputation tier 2"
else
	fail "SPECIALTY reputation gate missing"
fi

if contains "$ORDER_SYSTEM" '"required_store_level":[[:space:]]*3'; then
	pass "LIQUIDATOR requires store level 3"
else
	fail "LIQUIDATOR store-level gate missing"
fi

if contains "$ORDER_SYSTEM" '"required_reputation_tier":[[:space:]]*4'; then
	pass "PREMIUM requires reputation tier 4"
else
	fail "PREMIUM reputation gate missing"
fi

if contains "$ORDER_SYSTEM" 'func is_tier_unlocked'; then
	pass "Tier unlock helper implemented"
else
	fail "Tier unlock helper missing"
fi

echo ""
echo "[AC3] place_order workflow and failures"
if contains "$ORDER_SYSTEM" 'func place_order'; then
	pass "place_order implemented"
else
	fail "place_order missing"
fi

for reason in 'Supplier tier locked' 'Insufficient funds' 'Invalid quantity'; do
	if contains "$ORDER_SYSTEM" "EventBus\\.order_failed\\.emit\\(\"${reason}\"\\)"; then
		pass "order_failed emits '$reason'"
	else
		fail "order_failed missing '$reason'"
	fi
done

if contains "$ORDER_SYSTEM" 'is_item_in_tier_catalog'; then
	pass "Tier catalog validation implemented"
else
	fail "Tier catalog validation missing"
fi

if contains "$ORDER_SYSTEM" 'EventBus\.order_cash_check\.emit' \
		&& contains "$ORDER_SYSTEM" 'EventBus\.order_cash_deduct\.emit'; then
	pass "OrderSystem checks and deducts cash through EventBus"
else
	fail "OrderSystem cash check/deduct wiring missing"
fi

if contains "$ORDER_SYSTEM" '_pending_orders\.append\(order\)' \
		&& contains "$ORDER_SYSTEM" 'EventBus\.order_placed\.emit'; then
	pass "Successful orders create pending order and emit order_placed"
else
	fail "Pending order creation or order_placed missing"
fi

echo ""
echo "[AC4] Delivery timers and inventory fulfillment"
if contains "$ORDER_SYSTEM" 'EventBus\.day_started\.connect\(_on_day_started\)'; then
	pass "OrderSystem listens for day_started"
else
	fail "OrderSystem does not listen for day_started"
fi

if contains "$ORDER_SYSTEM" 'func _deliver_pending_orders' \
		&& contains "$ORDER_SYSTEM" 'delivery_day' \
		&& contains "$ORDER_SYSTEM" '_inventory_system\.create_item'; then
	pass "Pending deliveries create inventory items"
else
	fail "Pending delivery fulfillment missing"
fi

if contains "$ORDER_SYSTEM" 'EventBus\.order_delivered\.emit'; then
	pass "OrderSystem emits order_delivered"
else
	fail "OrderSystem order_delivered signal emit missing"
fi

echo ""
echo "[AC5] EventBus signals"
for sig in 'order_placed\(store_id: StringName, item_id: StringName, quantity: int, delivery_day: int\)' \
		'order_delivered\(store_id: StringName, items: Array\)' \
		'order_failed\(reason: String\)'; do
	if contains "$EVENT_BUS" "signal ${sig}"; then
		pass "EventBus declares $sig"
	else
		fail "EventBus missing $sig"
	fi
done

echo ""
echo "[AC6] Save/load persistence"
if contains "$ORDER_SYSTEM" 'func get_save_data' \
		&& contains "$ORDER_SYSTEM" '"pending_orders"' \
		&& contains "$ORDER_SYSTEM" 'func load_save_data'; then
	pass "OrderSystem persists pending_orders"
else
	fail "OrderSystem pending_orders persistence missing"
fi

if contains "$SAVE_MANAGER" '_order_system\.get_save_data\(\)' \
		&& contains "$SAVE_MANAGER" '_order_system\.load_save_data'; then
	pass "SaveManager saves and loads OrderSystem state"
else
	fail "SaveManager OrderSystem persistence wiring missing"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
	exit 1
fi

echo ""
echo "All ISSUE-076 acceptance criteria validated."
