#!/usr/bin/env bash
# Validates ISSUE-019: Add recommended markup guidance to pricing UI
# Checks store_definitions.json has correct markup ranges and pricing panel
# reads them from store data rather than hardcoding thresholds.
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-019: Recommended Markup Guidance ==="
echo ""

STORE_FILE="$ROOT/game/content/stores/store_definitions.json"
STORE_DEF_GD="$ROOT/game/resources/store_definition.gd"
CONTENT_PARSER_GD="$ROOT/game/scripts/content_parser.gd"
PRICING_PANEL_GD="$ROOT/game/scenes/ui/pricing_panel.gd"

# --- AC1: Each store has recommended_markup with optimal_min, optimal_max, max_viable ---
echo "[AC1] Store definitions have recommended_markup fields"

check_store_markup() {
    local store_id="$1"
    local exp_opt_min="$2"
    local exp_opt_max="$3"
    local exp_max_viable="$4"
    python3 -c "
import json, sys
with open('$STORE_FILE') as f:
    stores = json.load(f)
for s in stores:
    aliases = s.get('aliases', [])
    if s['id'] == '$store_id' or '$store_id' in aliases:
        rm = s.get('recommended_markup')
        if rm is None:
            print('missing recommended_markup', file=sys.stderr)
            sys.exit(1)
        errors = []
        if abs(rm.get('optimal_min', 0) - $exp_opt_min) > 0.001:
            errors.append(f'optimal_min={rm.get(\"optimal_min\")} expected $exp_opt_min')
        if abs(rm.get('optimal_max', 0) - $exp_opt_max) > 0.001:
            errors.append(f'optimal_max={rm.get(\"optimal_max\")} expected $exp_opt_max')
        if abs(rm.get('max_viable', 0) - $exp_max_viable) > 0.001:
            errors.append(f'max_viable={rm.get(\"max_viable\")} expected $exp_max_viable')
        if errors:
            print('; '.join(errors), file=sys.stderr)
            sys.exit(1)
        sys.exit(0)
print('store not found', file=sys.stderr)
sys.exit(1)
" 2>/dev/null
}

for store_args in \
    "sports_memorabilia 1.30 1.80 3.00" \
    "retro_games 1.25 1.60 2.50" \
    "video_rental 1.40 2.00 3.00" \
    "pocket_creatures 1.30 1.70 2.50" \
    "consumer_electronics 1.15 1.40 2.00"; do
    set -- $store_args
    if check_store_markup "$1" "$2" "$3" "$4"; then
        pass "$1 markup ranges correct ($2/$3/$4)"
    else
        fail "$1 markup ranges incorrect"
    fi
done

# --- AC2: StoreDefinition resource has recommended_markup fields ---
echo ""
echo "[AC2] StoreDefinition resource has markup fields"

for field in recommended_markup_optimal_min recommended_markup_optimal_max recommended_markup_max_viable; do
    if grep -q "$field" "$STORE_DEF_GD"; then
        pass "StoreDefinition has $field"
    else
        fail "StoreDefinition missing $field"
    fi
done

# --- AC3: ContentParser parses recommended_markup ---
echo ""
echo "[AC3] ContentParser parses recommended_markup"

if grep -q "recommended_markup" "$CONTENT_PARSER_GD"; then
    pass "ContentParser handles recommended_markup"
else
    fail "ContentParser does not parse recommended_markup"
fi

# --- AC4: Pricing panel reads thresholds from store data, not hardcoded ---
echo ""
echo "[AC4] Pricing panel uses store-specific markup thresholds"

if grep -q "_load_store_markup_ranges" "$PRICING_PANEL_GD"; then
    pass "Pricing panel loads store markup ranges"
else
    fail "Pricing panel does not load store markup ranges"
fi

if grep -q "GameManager.data_loader" "$PRICING_PANEL_GD"; then
    pass "Pricing panel reads from data_loader"
else
    fail "Pricing panel does not read from data_loader"
fi

# Verify hardcoded MARKUP_GREEN_MAX / MARKUP_YELLOW_MAX constants are removed
if grep -q "MARKUP_GREEN_MAX\|MARKUP_YELLOW_MAX" "$PRICING_PANEL_GD"; then
    fail "Pricing panel still has hardcoded markup threshold constants"
else
    pass "No hardcoded markup threshold constants in pricing panel"
fi

# --- AC5: Color indicator uses three tiers (green/yellow/red via positive/warning/negative) ---
echo ""
echo "[AC5] Color indicator uses three tiers from store data"

if grep -q "get_positive_color" "$PRICING_PANEL_GD" && \
   grep -q "get_warning_color" "$PRICING_PANEL_GD" && \
   grep -q "get_negative_color" "$PRICING_PANEL_GD"; then
    pass "Three color tiers present (positive/warning/negative)"
else
    fail "Missing color tier functions in pricing panel"
fi

if grep -q "_optimal_max" "$PRICING_PANEL_GD" && \
   grep -q "_max_viable" "$PRICING_PANEL_GD"; then
    pass "Color thresholds use store-specific _optimal_max and _max_viable"
else
    fail "Color thresholds not using store-specific fields"
fi

# --- Summary ---
echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

echo ""
echo "All ISSUE-019 acceptance criteria validated."
exit 0
