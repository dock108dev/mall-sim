#!/usr/bin/env bash
# Validate ISSUE-239: pocket_creatures_cards.json and pocket_creatures_tournaments.json
set -euo pipefail

CARDS_FILE="game/content/stores/pocket_creatures_cards.json"
TOURNAMENTS_FILE="game/content/stores/pocket_creatures_tournaments.json"
DATA_LOADER="game/autoload/data_loader.gd"
CONTENT_PARSER="game/scripts/content_parser.gd"
TOURNAMENT_DEF="game/resources/tournament_event_definition.gd"
EXIT_CODE=0

echo "=== ISSUE-239: PocketCreatures Cards and Tournaments Content Files ==="

echo ""
echo "[File existence]"

if [ -f "$CARDS_FILE" ]; then
    echo "PASS: pocket_creatures_cards.json exists at stores/"
else
    echo "FAIL: pocket_creatures_cards.json not found at $CARDS_FILE"
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

if python3 -c "import json,sys; json.load(open('$CARDS_FILE'))" 2>/dev/null; then
    echo "PASS: pocket_creatures_cards.json is valid JSON"
else
    echo "FAIL: pocket_creatures_cards.json is not valid JSON"
    EXIT_CODE=1
fi

if python3 -c "import json,sys; json.load(open('$TOURNAMENTS_FILE'))" 2>/dev/null; then
    echo "PASS: pocket_creatures_tournaments.json is valid JSON"
else
    echo "FAIL: pocket_creatures_tournaments.json is not valid JSON"
    EXIT_CODE=1
fi

echo ""
echo "[Cards: minimum count >= 20]"

CARD_COUNT=$(python3 -c "import json; data=json.load(open('$CARDS_FILE')); print(len(data))" 2>/dev/null || echo "0")
if [ "$CARD_COUNT" -ge 20 ]; then
    echo "PASS: $CARD_COUNT card entries found (>= 20)"
else
    echo "FAIL: only $CARD_COUNT card entries found (need >= 20)"
    EXIT_CODE=1
fi

echo ""
echo "[Cards: required fields]"

MISSING_FIELDS=$(python3 -c "
import json
data = json.load(open('$CARDS_FILE'))
required = {'id', 'display_name', 'card_category', 'rarity', 'base_price', 'spawn_weight', 'flavor_text'}
missing = []
for i, card in enumerate(data):
    for field in required:
        if field not in card:
            missing.append('card[%d] (%s) missing %s' % (i, card.get('id', '?'), field))
print('\n'.join(missing))
" 2>/dev/null || echo "parse error")

if [ -z "$MISSING_FIELDS" ]; then
    echo "PASS: all cards have required fields (id, display_name, card_category, rarity, base_price, spawn_weight, flavor_text)"
else
    echo "FAIL: missing fields detected:"
    echo "$MISSING_FIELDS"
    EXIT_CODE=1
fi

echo ""
echo "[Cards: rarity distribution]"

python3 -c "
import json, sys
data = json.load(open('$CARDS_FILE'))
counts = {}
for card in data:
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
echo "[Cards: spawn_weight sums per rarity bucket]"

python3 -c "
import json, sys
data = json.load(open('$CARDS_FILE'))
buckets = {}
for card in data:
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
echo "[Cards: base_price scaling by rarity]"

python3 -c "
import json, sys
data = json.load(open('$CARDS_FILE'))
buckets = {}
for card in data:
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
echo "[Cards: original parody names — no real TCG names]"

REAL_NAMES=("Charizard" "Pikachu" "Blastoise" "Venusaur" "Mewtwo" "Mew" "Gengar" "Alakazam" "Machamp")
FOUND_REAL=""
for name in "${REAL_NAMES[@]}"; do
    if grep -qi "\"$name\"" "$CARDS_FILE"; then
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
echo "[Tournaments: card_category values match cards.json categories]"

python3 -c "
import json, sys
cards = json.load(open('$CARDS_FILE'))
tournaments = json.load(open('$TOURNAMENTS_FILE'))
card_cats = set(c.get('card_category', '') for c in cards)
exit_code = 0
for t in tournaments:
    cat = t.get('card_category', '')
    if cat in card_cats:
        print('PASS: tournament category %s found in cards.json' % cat)
    else:
        print('FAIL: tournament category %s not found in cards.json (available: %s)' % (cat, sorted(card_cats)))
        exit_code = 1
sys.exit(exit_code)
" 2>/dev/null || EXIT_CODE=1

echo ""
echo "[DataLoader: routes pocket_creatures_cards as item type]"

if grep -q "pocket_creatures_cards" "$DATA_LOADER"; then
    echo "PASS: DataLoader has pocket_creatures_cards detection"
else
    echo "FAIL: DataLoader missing pocket_creatures_cards routing"
    EXIT_CODE=1
fi

if grep -A2 "pocket_creatures_cards" "$DATA_LOADER" | grep -q '"item"'; then
    echo "PASS: pocket_creatures_cards routed to item type"
else
    echo "FAIL: pocket_creatures_cards not routed to item type"
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
