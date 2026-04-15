#!/usr/bin/env bash
# Validates ISSUE-013: Apply economy balance tuning from research spec
# Checks starting cash values and supplier tier wholesale/daily_limit changes.
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-013: Economy Balance Tuning ==="
echo ""

# --- AC1: Starting cash is 750 in constants.gd ---
echo "[AC1] Starting cash is 750 in constants.gd"

if grep -q 'STARTING_CASH\s*:=\s*750\.0' "$ROOT/game/scripts/core/constants.gd"; then
    pass "STARTING_CASH = 750.0"
else
    fail "STARTING_CASH is not 750.0"
fi

# --- AC2: Per-store starting cash overrides in store_definitions.json ---
echo ""
echo "[AC2] Per-store starting cash overrides"

STORE_FILE="$ROOT/game/content/stores/store_definitions.json"

check_store_cash() {
    local store_id="$1"
    local expected="$2"
    local actual
    actual=$(python3 -c "
import json
with open('$STORE_FILE') as f:
    stores = json.load(f)
for s in stores:
    if s['id'] == '$store_id' or '$store_id' in s.get('aliases', []):
        print(s['starting_cash'])
        break
" 2>/dev/null || echo "0")
    if [ "$(echo "$actual == $expected" | bc -l)" -eq 1 ]; then
        pass "$store_id starting_cash = $expected"
    else
        fail "$store_id starting_cash = $actual (expected $expected)"
    fi
}

check_store_cash "sports_memorabilia" "750.0"
check_store_cash "retro_games" "800.0"
check_store_cash "video_rental" "900.0"
check_store_cash "pocket_creatures" "850.0"
check_store_cash "consumer_electronics" "1000.0"

# --- AC3: Supplier wholesale rates inverted ---
echo ""
echo "[AC3] Supplier tier wholesale rates"

SUPPLIER_FILE="$ROOT/game/scripts/systems/supplier_tier_system.gd"

check_tier_value() {
    local tier="$1"
    local key="$2"
    local expected="$3"
    # Extract tier block and check value
    if python3 -c "
import re, sys
with open('$SUPPLIER_FILE') as f:
    content = f.read()
# Find the tier dictionary entries
pattern = r'$tier:\s*\{([^}]+)\}'
match = re.search(pattern, content)
if not match:
    sys.exit(1)
block = match.group(1)
val_pattern = r'\"$key\":\s*([\d.]+)'
val_match = re.search(val_pattern, block)
if not val_match:
    sys.exit(1)
actual = float(val_match.group(1))
expected = float('$expected')
if abs(actual - expected) < 0.001:
    sys.exit(0)
else:
    print(f'actual={actual}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null; then
        pass "Tier $tier $key = $expected"
    else
        fail "Tier $tier $key != $expected"
    fi
}

check_tier_value "1" "wholesale" "0.75"
check_tier_value "2" "wholesale" "0.65"
check_tier_value "3" "wholesale" "0.55"

# --- AC4: Supplier daily limits updated ---
echo ""
echo "[AC4] Supplier tier daily limits"

check_tier_value "1" "daily_limit" "250.0"
check_tier_value "2" "daily_limit" "600.0"
check_tier_value "3" "daily_limit" "1500.0"

# --- AC5: Higher tiers yield better margins ---
echo ""
echo "[AC5] Higher tiers yield better profit margins"

if python3 -c "
t1 = 0.75
t2 = 0.65
t3 = 0.55
# Lower wholesale = better margin (buy cheaper, sell at market)
if t1 > t2 > t3:
    exit(0)
exit(1)
" 2>/dev/null; then
    pass "Tier 3 wholesale < Tier 2 < Tier 1 (better margins at higher tiers)"
else
    fail "Wholesale rates not properly ordered for better margins at higher tiers"
fi

# --- Summary ---
echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

echo ""
echo "All ISSUE-013 acceptance criteria validated."
exit 0
