#!/usr/bin/env bash
# ISSUE-017: Customer simulation — static structural validation.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ── archetypes.json ────────────────────────────────────────────────────────────

ARCHETYPES="$ROOT/game/content/customers/archetypes.json"

if [ -f "$ARCHETYPES" ]; then
    pass "archetypes.json exists"
else
    fail "archetypes.json missing at game/content/customers/archetypes.json"
fi

ARCHETYPE_COUNT=$(python3 -c "import json,sys; d=json.load(open('$ARCHETYPES')); print(len(d))" 2>/dev/null || echo 0)
if [ "$ARCHETYPE_COUNT" -ge 3 ]; then
    pass "archetypes.json defines >= 3 archetypes ($ARCHETYPE_COUNT found)"
else
    fail "archetypes.json needs >= 3 archetypes (found $ARCHETYPE_COUNT)"
fi

python3 - "$ARCHETYPES" <<'EOF'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
missing = []
for entry in data:
    for field in ("id", "wtp_multiplier", "preferred_types", "haggle_probability"):
        if field not in entry:
            missing.append("archetype '%s' missing field '%s'" % (entry.get("id","?"), field))
if missing:
    for m in missing:
        print("FAIL:", m)
    sys.exit(1)
print("PASS: all archetypes have wtp_multiplier, preferred_types, haggle_probability")
EOF
[ $? -eq 0 ] && PASS=$((PASS + 1)) || FAIL=$((FAIL + 1))

# ── CustomerSimulator script ──────────────────────────────────────────────────

SIM="$ROOT/game/scripts/systems/customer_simulator.gd"

if [ -f "$SIM" ]; then
    pass "customer_simulator.gd exists"
else
    fail "customer_simulator.gd missing"
fi

if grep -q "func simulate_day" "$SIM" 2>/dev/null; then
    pass "simulate_day method defined"
else
    fail "simulate_day method missing from customer_simulator.gd"
fi

if grep -q "func calculate_traffic" "$SIM" 2>/dev/null; then
    pass "calculate_traffic method defined"
else
    fail "calculate_traffic method missing from customer_simulator.gd"
fi

if grep -q "PriceResolver" "$SIM" 2>/dev/null; then
    pass "CustomerSimulator uses PriceResolver"
else
    fail "CustomerSimulator does not reference PriceResolver"
fi

if grep -q "item_sold" "$SIM" 2>/dev/null; then
    pass "item_sold emitted in customer_simulator.gd"
else
    fail "item_sold not emitted in customer_simulator.gd"
fi

if grep -q "customer_purchased" "$SIM" 2>/dev/null; then
    pass "customer_purchased emitted in customer_simulator.gd"
else
    fail "customer_purchased not emitted in customer_simulator.gd"
fi

# ── StoreController integration ───────────────────────────────────────────────

SC="$ROOT/game/scripts/stores/store_controller.gd"

if grep -q "_run_customer_simulation" "$SC" 2>/dev/null; then
    pass "StoreController calls _run_customer_simulation"
else
    fail "StoreController missing _run_customer_simulation"
fi

if grep -q "CustomerSimulator" "$SC" 2>/dev/null; then
    pass "StoreController references CustomerSimulator"
else
    fail "StoreController does not reference CustomerSimulator"
fi

# ── GUT test exists ───────────────────────────────────────────────────────────

TEST="$ROOT/tests/gut/test_customer_simulator.gd"

if [ -f "$TEST" ]; then
    pass "test_customer_simulator.gd exists"
else
    fail "test_customer_simulator.gd missing"
fi

if grep -q "test_seeded_simulate_day" "$TEST" 2>/dev/null; then
    pass "seeded determinism test present"
else
    fail "seeded determinism test missing"
fi

if grep -q "test_traffic_formula" "$TEST" 2>/dev/null; then
    pass "traffic formula test present"
else
    fail "traffic formula test missing"
fi

# ── No store implements its own purchase loop ─────────────────────────────────

for ctrl in retro_games.gd pocket_creatures_store_controller.gd video_rental_store_controller.gd electronics_store_controller.gd sports_memorabilia_controller.gd; do
    path="$ROOT/game/scripts/stores/$ctrl"
    if [ -f "$path" ]; then
        if grep -qE "purchase_loop|_simulate_purchases|_run_purchases" "$path" 2>/dev/null; then
            fail "$ctrl contains its own purchase loop"
        else
            pass "$ctrl delegates to CustomerSimulator (no own purchase loop)"
        fi
    fi
done

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "=== ISSUE-017 Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
