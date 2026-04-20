#!/usr/bin/env bash
# Validates ISSUE-001: Wire MarketEventSystem into GameWorld
# Checks acceptance criteria via static code analysis when Godot is unavailable.
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-001: Wire MarketEventSystem into GameWorld ==="
echo ""

# --- AC1: MarketEventSystem instantiated in game_world.gd ---
echo "[AC1] MarketEventSystem declared in game_world.gd"

# Accept either @onready scene-node pattern or new()+add_child() pattern
if grep -qE '(market_event_system\s*[:=].*MarketEventSystem|MarketEventSystem\.new\(\))' \
    "$ROOT/game/scenes/world/game_world.gd"; then
    pass "MarketEventSystem declared in game_world.gd"
else
    fail "MarketEventSystem not declared in game_world.gd"
fi

if grep -q 'market_event_system\.initialize()' \
    "$ROOT/game/scenes/world/game_world.gd"; then
    pass "market_event_system.initialize() called"
else
    fail "market_event_system.initialize() not called"
fi

# Accept either add_child() call or @onready $NodePath pattern
if grep -qE '(add_child\(market_event_system\)|@onready var market_event_system)' \
    "$ROOT/game/scenes/world/game_world.gd"; then
    pass "market_event_system added to scene"
else
    fail "market_event_system not added to scene"
fi

# --- AC2: EventBus declares 3 market event signals ---
echo ""
echo "[AC2] EventBus declares market event signals"

for sig in market_event_announced market_event_started market_event_ended; do
    if grep -q "signal ${sig}" "$ROOT/game/autoload/event_bus.gd"; then
        pass "signal $sig declared"
    else
        fail "signal $sig not declared"
    fi
done

# --- AC3: EconomySystem includes market event multiplier ---
echo ""
echo "[AC3] EconomySystem.calculate_market_value() includes market event multiplier"

if grep -q '_market_event_system' \
    "$ROOT/game/scripts/systems/economy_system.gd"; then
    pass "_market_event_system variable exists in EconomySystem"
else
    fail "_market_event_system variable missing in EconomySystem"
fi

if grep -q 'set_market_event_system' \
    "$ROOT/game/scripts/systems/economy_system.gd"; then
    pass "set_market_event_system() setter exists"
else
    fail "set_market_event_system() setter missing"
fi

if grep -q '_get_market_event_multiplier' \
    "$ROOT/game/scripts/systems/economy_system.gd"; then
    pass "_get_market_event_multiplier() used in price calculation"
else
    fail "_get_market_event_multiplier() missing from price calculation"
fi

if grep -q 'market_event_system\.get_trend_multiplier' \
    "$ROOT/game/scripts/systems/economy_system.gd"; then
    pass "Calls MarketEventSystem.get_trend_multiplier()"
else
    fail "Does not call MarketEventSystem.get_trend_multiplier()"
fi

# Verify multiplier is in the final formula
if grep -q '\* market_event' \
    "$ROOT/game/scripts/systems/economy_system.gd"; then
    pass "market_event multiplier included in value formula"
else
    fail "market_event multiplier missing from value formula"
fi

# --- AC4: SaveManager serializes and deserializes MarketEventSystem state ---
echo ""
echo "[AC4] SaveManager serializes/deserializes MarketEventSystem state"

if grep -q 'set_market_event_system' \
    "$ROOT/game/scripts/core/save_manager.gd"; then
    pass "SaveManager has set_market_event_system() setter"
else
    fail "SaveManager missing set_market_event_system() setter"
fi

if grep -q '_market_event_system\.get_save_data()' \
    "$ROOT/game/scripts/core/save_manager.gd"; then
    pass "SaveManager calls get_save_data() for serialization"
else
    fail "SaveManager does not call get_save_data()"
fi

if grep -q '_market_event_system\.load_save_data' \
    "$ROOT/game/scripts/core/save_manager.gd"; then
    pass "SaveManager calls load_save_data() for deserialization"
else
    fail "SaveManager does not call load_save_data()"
fi

# --- AC5: ~15% daily probability ---
echo ""
echo "[AC5] Market events trigger with ~15% daily probability"

if grep -q 'BASE_EVENT_CHANCE.*=.*0\.15' \
    "$ROOT/game/scripts/systems/market_event_system.gd"; then
    pass "BASE_EVENT_CHANCE = 0.15 (15%)"
else
    fail "BASE_EVENT_CHANCE != 0.15"
fi

if grep -q 'GUARANTEED_EVENT_DAYS.*=.*15' \
    "$ROOT/game/scripts/systems/market_event_system.gd"; then
    pass "GUARANTEED_EVENT_DAYS = 15"
else
    fail "GUARANTEED_EVENT_DAYS != 15"
fi

# --- AC6: No direct autoload-to-autoload references ---
echo ""
echo "[AC6] No direct autoload-to-autoload references — EventBus signals only"

# MarketEventSystem should use EventBus signals, not call other autoloads directly
if grep -q 'GameManager\.' "$ROOT/game/scripts/systems/market_event_system.gd"; then
    # GameManager.data_loader in initialize() and GameManager.current_day are allowed
    # (reading data, not calling methods on other autoloads)
    NON_DATA_REFS=$(grep 'GameManager\.' \
        "$ROOT/game/scripts/systems/market_event_system.gd" \
        | grep -v 'data_loader' \
        | grep -v 'current_day' \
        | grep -c '.' || true)
    if [ "$NON_DATA_REFS" -eq 0 ]; then
        pass "No improper autoload-to-autoload references"
    else
        fail "Found direct autoload method calls (not data_loader/current_day)"
    fi
else
    pass "No GameManager references at all"
fi

if grep -q 'EventBus\.' "$ROOT/game/scripts/systems/market_event_system.gd"; then
    pass "Uses EventBus for signal communication"
else
    fail "Does not use EventBus signals"
fi

# --- Additional: MarketEventSystem has required methods ---
echo ""
echo "[Extra] MarketEventSystem implementation completeness"

for method in get_trend_multiplier get_save_data load_save_data initialize \
    _on_day_started _try_select_new_event; do
    if grep -q "func ${method}" \
        "$ROOT/game/scripts/systems/market_event_system.gd"; then
        pass "Method $method exists"
    else
        fail "Method $method missing"
    fi
done

# --- Additional: game_world.gd wires MarketEventSystem to EconomySystem ---
echo ""
echo "[Extra] GameWorld wires MarketEventSystem to EconomySystem"

if grep -q 'economy_system\.set_market_event_system' \
    "$ROOT/game/scenes/world/game_world.gd"; then
    pass "economy_system.set_market_event_system() called in game_world.gd"
else
    fail "economy_system.set_market_event_system() not called in game_world.gd"
fi

# --- Additional: market_events.json exists with event data ---
echo ""
echo "[Extra] Content data exists"

if [ -f "$ROOT/game/content/events/market_events.json" ]; then
    EVENT_COUNT=$(python3 -c "
import json
with open('$ROOT/game/content/events/market_events.json') as f:
    data = json.load(f)
    if isinstance(data, list):
        print(len(data))
    elif isinstance(data, dict) and 'events' in data:
        print(len(data['events']))
    else:
        print(0)
" 2>/dev/null || echo "0")
    if [ "$EVENT_COUNT" -gt 0 ]; then
        pass "market_events.json has $EVENT_COUNT event definitions"
    else
        fail "market_events.json has no events"
    fi
else
    fail "market_events.json not found"
fi

# --- Summary ---
echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

echo ""
echo "All ISSUE-001 acceptance criteria validated."
exit 0
