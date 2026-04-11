#!/usr/bin/env bash
# Validates ISSUE-003: Extract OrderingSystem from economy_system.gd
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-003: Extract OrderingSystem from economy_system.gd ==="
echo ""

# --- AC1: economy_system.gd is under 500 lines ---
echo "[AC1] economy_system.gd is under 500 lines"
ECON_LINES=$(wc -l < "$ROOT/game/scripts/systems/economy_system.gd" | tr -d ' ')
if [ "$ECON_LINES" -lt 500 ]; then
    pass "economy_system.gd is $ECON_LINES lines (< 500)"
else
    fail "economy_system.gd is $ECON_LINES lines (>= 500)"
fi

# --- AC2: OrderingSystem is a standalone script under 300 lines ---
echo ""
echo "[AC2] OrderingSystem is standalone and under 300 lines"
if [ -f "$ROOT/game/scripts/systems/ordering_system.gd" ]; then
    pass "ordering_system.gd exists"
else
    fail "ordering_system.gd not found"
fi

ORDER_LINES=$(wc -l < "$ROOT/game/scripts/systems/ordering_system.gd" | tr -d ' ')
if [ "$ORDER_LINES" -lt 300 ]; then
    pass "ordering_system.gd is $ORDER_LINES lines (< 300)"
else
    fail "ordering_system.gd is $ORDER_LINES lines (>= 300)"
fi

if grep -q 'class_name OrderingSystem' \
    "$ROOT/game/scripts/systems/ordering_system.gd"; then
    pass "OrderingSystem class_name declared"
else
    fail "OrderingSystem class_name not declared"
fi

# --- AC3: Stock ordering, delivery queue, and supplier filtering in OrderingSystem ---
echo ""
echo "[AC3] Ordering functionality lives in OrderingSystem"
for method in place_order _deliver_pending_orders get_supplier_tier \
    is_item_available_at_tier get_wholesale_price; do
    if grep -q "func ${method}" \
        "$ROOT/game/scripts/systems/ordering_system.gd"; then
        pass "Method $method in ordering_system.gd"
    else
        fail "Method $method missing from ordering_system.gd"
    fi
done

# Verify these methods are NOT in economy_system.gd
for method in place_order _deliver_pending_orders get_supplier_tier \
    is_item_available_at_tier get_wholesale_price; do
    if grep -q "func ${method}" \
        "$ROOT/game/scripts/systems/economy_system.gd"; then
        fail "Method $method should not be in economy_system.gd"
    else
        pass "Method $method correctly absent from economy_system.gd"
    fi
done

# --- AC4: OrderingSystem communicates via EventBus ---
echo ""
echo "[AC4] OrderingSystem uses EventBus — no direct EconomySystem method calls"

if grep -q '_economy_system' \
    "$ROOT/game/scripts/systems/ordering_system.gd"; then
    fail "OrderingSystem still holds _economy_system reference"
else
    pass "No _economy_system reference in OrderingSystem"
fi

if grep -q 'EventBus\.order_cash_check\.emit' \
    "$ROOT/game/scripts/systems/ordering_system.gd"; then
    pass "OrderingSystem uses EventBus for cash checking"
else
    fail "OrderingSystem does not use EventBus for cash checking"
fi

if grep -q 'EventBus\.order_cash_deduct\.emit' \
    "$ROOT/game/scripts/systems/ordering_system.gd"; then
    pass "OrderingSystem uses EventBus for cash deduction"
else
    fail "OrderingSystem does not use EventBus for cash deduction"
fi

# EventBus has the required signals
for sig in order_cash_check order_cash_deduct order_placed order_delivered; do
    if grep -q "signal ${sig}" "$ROOT/game/autoload/event_bus.gd"; then
        pass "EventBus signal $sig declared"
    else
        fail "EventBus signal $sig not declared"
    fi
done

# EconomySystem connects to ordering signals
if grep -q 'order_cash_check\.connect' \
    "$ROOT/game/scripts/systems/economy_system.gd"; then
    pass "EconomySystem connects to order_cash_check"
else
    fail "EconomySystem does not connect to order_cash_check"
fi

if grep -q 'order_cash_deduct\.connect' \
    "$ROOT/game/scripts/systems/economy_system.gd"; then
    pass "EconomySystem connects to order_cash_deduct"
else
    fail "EconomySystem does not connect to order_cash_deduct"
fi

# --- AC5: Save/load for ordering state works ---
echo ""
echo "[AC5] Save/load for ordering state"

if grep -q 'func get_save_data' \
    "$ROOT/game/scripts/systems/ordering_system.gd"; then
    pass "OrderingSystem has get_save_data()"
else
    fail "OrderingSystem missing get_save_data()"
fi

if grep -q 'func load_save_data' \
    "$ROOT/game/scripts/systems/ordering_system.gd"; then
    pass "OrderingSystem has load_save_data()"
else
    fail "OrderingSystem missing load_save_data()"
fi

if grep -q 'ordering_system\.get_save_data\|_ordering_system\.get_save_data' \
    "$ROOT/game/scripts/core/save_manager.gd"; then
    pass "SaveManager calls ordering get_save_data()"
else
    fail "SaveManager does not call ordering get_save_data()"
fi

if grep -q 'ordering_system\.load_save_data\|_ordering_system\.load_save_data' \
    "$ROOT/game/scripts/core/save_manager.gd"; then
    pass "SaveManager calls ordering load_save_data()"
else
    fail "SaveManager does not call ordering load_save_data()"
fi

# --- AC6: No behavioral changes — wiring intact ---
echo ""
echo "[AC6] GameWorld wires OrderingSystem correctly"

if grep -q 'ordering_system.*=.*OrderingSystem\.new()' \
    "$ROOT/game/scenes/world/game_world.gd"; then
    pass "OrderingSystem instantiated in game_world.gd"
else
    fail "OrderingSystem not instantiated in game_world.gd"
fi

if grep -q 'ordering_system\.initialize' \
    "$ROOT/game/scenes/world/game_world.gd"; then
    pass "ordering_system.initialize() called"
else
    fail "ordering_system.initialize() not called"
fi

if grep -q 'add_child(ordering_system)' \
    "$ROOT/game/scenes/world/game_world.gd"; then
    pass "ordering_system added as child"
else
    fail "ordering_system not added as child"
fi

# OrderPanel uses ordering_system for tier methods (not economy_system)
if grep -q 'ordering_system\.get_supplier_tier_config' \
    "$ROOT/game/scenes/ui/order_panel.gd"; then
    pass "OrderPanel calls ordering_system.get_supplier_tier_config()"
else
    fail "OrderPanel does not call ordering_system.get_supplier_tier_config()"
fi

if grep -q 'economy_system\.get_supplier_tier_config\|economy_system\.get_next_tier_info' \
    "$ROOT/game/scenes/ui/order_panel.gd"; then
    fail "OrderPanel still calls tier methods on economy_system"
else
    pass "OrderPanel no longer calls tier methods on economy_system"
fi

# --- Summary ---
echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

echo ""
echo "All ISSUE-003 acceptance criteria validated."
exit 0
