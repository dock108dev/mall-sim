#!/usr/bin/env bash
# Validate ISSUE-239 / ISSUE-013: creatures.json and packs.json canonical content,
# pocket_creatures_tournaments.json, and DataLoader routing.
set -euo pipefail

CREATURES_FILE="game/content/stores/pocket_creatures/creatures.json"
PACKS_FILE="game/content/stores/pocket_creatures/packs.json"
TOURNAMENTS_FILE="game/content/stores/pocket_creatures_tournaments.json"
DATA_LOADER="game/autoload/data_loader.gd"
CONTENT_PARSER="game/scripts/content_parser.gd"
TOURNAMENT_DEF="game/resources/tournament_event_definition.gd"
EXIT_CODE=0

echo "=== ISSUE-239 / ISSUE-013: PocketCreatures Content Files ==="

echo ""
echo "[File existence]"

if [ -f "$CREATURES_FILE" ]; then
    echo "PASS: creatures.json exists at pocket_creatures/"
else
    echo "FAIL: creatures.json not found at $CREATURES_FILE"
    EXIT_CODE=1
fi

if [ -f "$PACKS_FILE" ]; then
    echo "PASS: packs.json exists at pocket_creatures/"
else
    echo "FAIL: packs.json not found at $PACKS_FILE"
    EXIT_CODE=1
fi

if [ -f "$TOURNAMENTS_FILE" ]; then
    echo "PASS: pocket_creatures_tournaments.json exists at stores/"
else
    echo "FAIL: pocket_creatures_tournaments.json not found at $TOURNAMENTS_FILE"
    EXIT_CODE=1
fi

echo ""
echo "[JSON validity]"

if python3 -c "import json,sys; json.load(open('$CREATURES_FILE'))" 2>/dev/null; then
    echo "PASS: creatures.json is valid JSON"
else
    echo "FAIL: creatures.json is not valid JSON"
    EXIT_CODE=1
fi

if python3 -c "import json,sys; json.load(open('$PACKS_FILE'))" 2>/dev/null; then
    echo "PASS: packs.json is valid JSON"
else
    echo "FAIL: packs.json is not valid JSON"
    EXIT_CODE=1
fi

if python3 -c "import json,sys; json.load(open('$TOURNAMENTS_FILE'))" 2>/dev/null; then
    echo "PASS: pocket_creatures_tournaments.json is valid JSON"
else
    echo "FAIL: pocket_creatures_tournaments.json is not valid JSON"
    EXIT_CODE=1
fi

echo ""
echo "[Creatures: root type is item_definition]"

if python3 -c "
import json, sys
data = json.load(open('$CREATURES_FILE'))
assert isinstance(data, dict), 'root must be a dict'
assert data.get('type') == 'item_definition', 'root type must be item_definition'
print('type=%s' % data.get('type'))
" 2>/dev/null; then
    echo "PASS: creatures.json root type is item_definition"
else
    echo "FAIL: creatures.json root type must be item_definition"
    EXIT_CODE=1
fi

echo ""
echo "[Creatures: minimum count >= 20]"

CARD_COUNT=$(python3 -c "
import json
data = json.load(open('$CREATURES_FILE'))
items = data.get('items', [])
print(len(items))
" 2>/dev/null || echo "0")
if [ "$CARD_COUNT" -ge 20 ]; then
    echo "PASS: $CARD_COUNT creature entries found (>= 20)"
else
    echo "FAIL: only $CARD_COUNT creature entries found (need >= 20)"
    EXIT_CODE=1
fi

echo ""
echo "[Creatures: required fields]"

MISSING_FIELDS=$(python3 -c "
import json
data = json.load(open('$CREATURES_FILE'))
items = data.get('items', [])
required = {'id', 'display_name', 'category', 'rarity', 'base_price', 'creature_type', 'spawn_weight', 'flavor_text'}
missing = []
for i, card in enumerate(items):
    for field in required:
        if field not in card:
            missing.append('creature[%d] (%s) missing %s' % (i, card.get('id', '?'), field))
print('\n'.join(missing))
" 2>/dev/null || echo "parse error")

if [ -z "$MISSING_FIELDS" ]; then
    echo "PASS: all creatures have required fields (id, display_name, category, rarity, base_price, creature_type, spawn_weight, flavor_text)"
else
    echo "FAIL: missing fields detected:"
    echo "$MISSING_FIELDS"
    EXIT_CODE=1
fi

echo ""
echo "[Creatures: rarity distribution]"

python3 -c "
import json, sys
data = json.load(open('$CREATURES_FILE'))
items = data.get('items', [])
counts = {}
for card in items:
    r = card.get('rarity', '')
    counts[r] = counts.get(r, 0) + 1
exit_code = 0
for rarity, min_count in [('common', 8), ('uncommon', 5), ('rare', 4), ('ultra_rare', 2), ('secret_rare', 1)]:
    n = counts.get(rarity, 0)
    if n >= min_count:
        print('PASS: %s count = %d (>= %d)' % (rarity, n, min_count))
    else:
        print('FAIL: %s count = %d (need >= %d)' % (rarity, n, min_count))
        exit_code = 1
sys.exit(exit_code)
" 2>/dev/null || EXIT_CODE=1

echo ""
echo "[Creatures: spawn_weight sums per rarity bucket]"

python3 -c "
import json, sys
data = json.load(open('$CREATURES_FILE'))
items = data.get('items', [])
buckets = {}
for card in items:
    r = card.get('rarity', '')
    buckets.setdefault(r, []).append(float(card.get('spawn_weight', 0)))
exit_code = 0
for rarity, weights in buckets.items():
    total = round(sum(weights), 6)
    if abs(total - 1.0) < 0.01:
        print('PASS: %s spawn_weight sum = %.4f (~1.0)' % (rarity, total))
    else:
        print('FAIL: %s spawn_weight sum = %.4f (should be ~1.0)' % (rarity, total))
        exit_code = 1
sys.exit(exit_code)
" 2>/dev/null || EXIT_CODE=1

echo ""
echo "[Creatures: base_price scaling by rarity]"

python3 -c "
import json, sys
data = json.load(open('$CREATURES_FILE'))
items = data.get('items', [])
buckets = {}
for card in items:
    r = card.get('rarity', '')
    buckets.setdefault(r, []).append(float(card.get('base_price', 0)))
medians = {}
for r, prices in buckets.items():
    sorted_p = sorted(prices)
    n = len(sorted_p)
    medians[r] = sorted_p[n // 2]
order = ['common', 'uncommon', 'rare', 'ultra_rare', 'secret_rare']
present = [r for r in order if r in medians]
exit_code = 0
for i in range(len(present) - 1):
    lo, hi = present[i], present[i + 1]
    if medians[lo] < medians[hi]:
        print('PASS: median %s (\$%.2f) < %s (\$%.2f)' % (lo, medians[lo], hi, medians[hi]))
    else:
        print('FAIL: median %s (\$%.2f) not < %s (\$%.2f)' % (lo, medians[lo], hi, medians[hi]))
        exit_code = 1
sys.exit(exit_code)
" 2>/dev/null || EXIT_CODE=1

echo ""
echo "[Creatures: original parody names — no real TCG names]"

REAL_NAMES=("Charizard" "Pikachu" "Blastoise" "Venusaur" "Mewtwo" "Mew" "Gengar" "Alakazam" "Machamp")
FOUND_REAL=""
for name in "${REAL_NAMES[@]}"; do
    if grep -qi "\"$name\"" "$CREATURES_FILE"; then
        FOUND_REAL="$FOUND_REAL $name"
    fi
done
if [ -z "$FOUND_REAL" ]; then
    echo "PASS: no real TCG card names detected"
else
    echo "FAIL: real TCG card names found:$FOUND_REAL"
    EXIT_CODE=1
fi

echo ""
echo "[Packs: required fields per pack type]"

MISSING_PACK=$(python3 -c "
import json
packs = json.load(open('$PACKS_FILE'))
required = {'id', 'display_name', 'set_tag', 'cost', 'slot_count', 'slots', 'rarity_weights'}
missing = []
for i, p in enumerate(packs):
    for field in required:
        if field not in p:
            missing.append('pack[%d] (%s) missing %s' % (i, p.get('id', '?'), field))
    rw = p.get('rarity_weights', {})
    for rk in ('rare', 'holo_rare', 'secret_rare'):
        if rk not in rw:
            missing.append('pack[%d] (%s) rarity_weights missing %s' % (i, p.get('id', '?'), rk))
print('\n'.join(missing))
" 2>/dev/null || echo "parse error")

if [ -z "$MISSING_PACK" ]; then
    echo "PASS: all pack types have required fields"
else
    echo "FAIL: missing pack fields:"
    echo "$MISSING_PACK"
    EXIT_CODE=1
fi

echo ""
echo "[Packs: rarity weights sum to ~1.0 per pack]"

python3 -c "
import json, sys
packs = json.load(open('$PACKS_FILE'))
exit_code = 0
for p in packs:
    rw = p.get('rarity_weights', {})
    total = sum(float(v) for v in rw.values())
    if abs(total - 1.0) < 0.01:
        print('PASS: %s rarity_weights sum = %.4f (~1.0)' % (p.get('set_tag', '?'), total))
    else:
        print('FAIL: %s rarity_weights sum = %.4f (should be ~1.0)' % (p.get('set_tag', '?'), total))
        exit_code = 1
sys.exit(exit_code)
" 2>/dev/null || EXIT_CODE=1

echo ""
echo "[Packs: slot_count matches slots sum]"

python3 -c "
import json, sys
packs = json.load(open('$PACKS_FILE'))
exit_code = 0
for p in packs:
    declared = int(p.get('slot_count', 0))
    slots_sum = sum(int(s.get('count', 0)) for s in p.get('slots', []))
    if declared == slots_sum:
        print('PASS: %s slot_count=%d matches slots sum' % (p.get('set_tag', '?'), declared))
    else:
        print('FAIL: %s slot_count=%d but slots sum=%d' % (p.get('set_tag', '?'), declared, slots_sum))
        exit_code = 1
sys.exit(exit_code)
" 2>/dev/null || EXIT_CODE=1

echo ""
echo "[Tournaments: minimum count >= 3]"

TOURNAMENT_COUNT=$(python3 -c "import json; data=json.load(open('$TOURNAMENTS_FILE')); print(len(data))" 2>/dev/null || echo "0")
if [ "$TOURNAMENT_COUNT" -ge 3 ]; then
    echo "PASS: $TOURNAMENT_COUNT tournament entries found (>= 3)"
else
    echo "FAIL: only $TOURNAMENT_COUNT tournament entries found (need >= 3)"
    EXIT_CODE=1
fi

echo ""
echo "[Tournaments: required fields]"

MISSING_TOURN=$(python3 -c "
import json
data = json.load(open('$TOURNAMENTS_FILE'))
required = {'id', 'display_name', 'card_category', 'demand_multiplier', 'duration_days', 'notification_day'}
missing = []
for i, t in enumerate(data):
    has_day = 'day' in t or 'start_day' in t
    for field in required:
        if field not in t:
            missing.append('tournament[%d] (%s) missing %s' % (i, t.get('id', '?'), field))
    if not has_day:
        missing.append('tournament[%d] (%s) missing day/start_day' % (i, t.get('id', '?')))
print('\n'.join(missing))
" 2>/dev/null || echo "parse error")

if [ -z "$MISSING_TOURN" ]; then
    echo "PASS: all tournaments have required fields"
else
    echo "FAIL: missing tournament fields:"
    echo "$MISSING_TOURN"
    EXIT_CODE=1
fi

echo ""
echo "[Tournaments: no category overlaps on same day ranges]"

python3 -c "
import json, sys
data = json.load(open('$TOURNAMENTS_FILE'))
events = []
for t in data:
    start = int(t.get('start_day', t.get('day', 0)))
    dur = int(t.get('duration_days', 1))
    cat = t.get('card_category', '')
    events.append((t['id'], cat, start, start + dur - 1))
exit_code = 0
for i in range(len(events)):
    for j in range(i + 1, len(events)):
        id1, cat1, s1, e1 = events[i]
        id2, cat2, s2, e2 = events[j]
        if cat1 == cat2 and not (e1 < s2 or e2 < s1):
            print('FAIL: %s and %s share category %s on overlapping days' % (id1, id2, cat1))
            exit_code = 1
if exit_code == 0:
    print('PASS: no category overlaps on same day ranges')
sys.exit(exit_code)
" 2>/dev/null || EXIT_CODE=1

echo ""
echo "[DataLoader: routes item_definition root type to item]"

if grep -q '"item_definition": "item"' "$DATA_LOADER"; then
    echo "PASS: DataLoader _ROOT_TYPE_MAP routes item_definition to item"
else
    echo "FAIL: DataLoader missing item_definition -> item routing"
    EXIT_CODE=1
fi

echo ""
echo "[DataLoader: routes packs.json to pocket_creatures_packs_config]"

if grep -q "pocket_creatures_packs_config" "$DATA_LOADER"; then
    echo "PASS: DataLoader routes packs.json to pocket_creatures_packs_config"
else
    echo "FAIL: DataLoader missing pocket_creatures_packs_config routing"
    EXIT_CODE=1
fi

echo ""
echo "[DataLoader: pocket_creatures_tournaments detection before dir check]"

TOURN_LINE=$(grep -n "pocket_creatures_tournaments" "$DATA_LOADER" | head -1 | cut -d: -f1)
DIR_MAP_LINE=$(grep -n "_DIR_TYPE_MAP.has(dir_name)" "$DATA_LOADER" | head -1 | cut -d: -f1)
if [ -n "$TOURN_LINE" ] && [ -n "$DIR_MAP_LINE" ] && [ "$TOURN_LINE" -lt "$DIR_MAP_LINE" ]; then
    echo "PASS: pocket_creatures_tournaments detected before directory type check"
else
    echo "FAIL: pocket_creatures_tournaments should be checked before _DIR_TYPE_MAP"
    EXIT_CODE=1
fi

echo ""
echo "[ContentParser: display_name fallback for item_name]"

if grep -q "display_name" "$CONTENT_PARSER"; then
    echo "PASS: ContentParser handles display_name field"
else
    echo "FAIL: ContentParser missing display_name support"
    EXIT_CODE=1
fi

echo ""
echo "[TournamentEventDefinition: notification_day field]"

if grep -q "notification_day" "$TOURNAMENT_DEF"; then
    echo "PASS: TournamentEventDefinition has notification_day field"
else
    echo "FAIL: TournamentEventDefinition missing notification_day field"
    EXIT_CODE=1
fi

echo ""
echo "=== Results ==="
if [ $EXIT_CODE -eq 0 ]; then
    echo "All ISSUE-239 checks passed."
else
    echo "Some ISSUE-239 checks failed."
fi

exit $EXIT_CODE
