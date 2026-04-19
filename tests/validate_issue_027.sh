#!/usr/bin/env bash
# Validates ISSUE-027: Phase 6 content volume targets.
set -u
PASS=0
FAIL=0

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTENT="$ROOT/game/content"

check() {
	local label="$1"; shift
	if "$@" >/dev/null 2>&1; then
		echo "  PASS: $label"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $label"
		FAIL=$((FAIL + 1))
	fi
}

echo ""
echo "=== ISSUE-027: Phase 6 content volume ==="

# ---------------------------------------------------------------------------
echo ""
echo "[AC1] 4 season definitions with required fields"
# ---------------------------------------------------------------------------
check "seasons.json exists" test -f "$CONTENT/events/seasons.json"

python3 - "$CONTENT/events/seasons.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
seasons = data.get("seasons", [])
req = ["id", "name", "event_pool", "price_modifier_table", "visual_variant"]
if len(seasons) < 4:
    print(f"FAIL: only {len(seasons)} seasons, need >= 4"); sys.exit(1)
fails = 0
for s in seasons:
    for field in req:
        if field not in s:
            print(f"FAIL season '{s.get('id','?')}' missing '{field}'"); fails += 1
    if not isinstance(s.get("event_pool"), list):
        print(f"FAIL season '{s.get('id','?')}' event_pool not an Array"); fails += 1
    if not isinstance(s.get("price_modifier_table"), dict):
        print(f"FAIL season '{s.get('id','?')}' price_modifier_table not a Dict"); fails += 1
sys.exit(1 if fails else 0)
PY
if [ "$?" -eq 0 ]; then
	echo "  PASS: seasons have all required fields"
	PASS=$((PASS + 1))
else
	echo "  FAIL: seasons missing required fields (see above)"
	FAIL=$((FAIL + 1))
fi

python3 - "$CONTENT/events/seasons.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f: data = json.load(f)
n = len(data.get("seasons", []))
if n >= 4: sys.exit(0)
print(f"Only {n} seasons"); sys.exit(1)
PY
if [ "$?" -eq 0 ]; then
	echo "  PASS: >= 4 seasons defined"
	PASS=$((PASS + 1))
else
	echo "  FAIL: fewer than 4 seasons"
	FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
echo ""
echo "[AC2] >= 20 ambient moment entries with required fields"
# ---------------------------------------------------------------------------
check "ambient_moments.json exists" test -f "$CONTENT/events/ambient_moments.json"

python3 - "$CONTENT/events/ambient_moments.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f: data = json.load(f)
moments = data.get("moments", [])
req = ["id", "flavor_text", "store_id", "season_id", "min_day", "max_day", "duration_seconds"]
if len(moments) < 20:
    print(f"FAIL: only {len(moments)} moments, need >= 20"); sys.exit(1)
fails = 0
for m in moments:
    for field in req:
        if field not in m:
            print(f"FAIL moment '{m.get('id','?')}' missing '{field}'"); fails += 1
sys.exit(1 if fails else 0)
PY
if [ "$?" -eq 0 ]; then
	echo "  PASS: >= 20 ambient moments with required fields"
	PASS=$((PASS + 1))
else
	echo "  FAIL: ambient moments missing fields or insufficient count"
	FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
echo ""
echo "[AC3] 4 secret thread definitions with required fields"
# ---------------------------------------------------------------------------
check "secret_threads.json exists" test -f "$CONTENT/meta/secret_threads.json"

python3 - "$CONTENT/meta/secret_threads.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f: threads = json.load(f)
req = ["id", "trigger_conditions", "stages", "resolution_text"]
if len(threads) < 4:
    print(f"FAIL: only {len(threads)} threads, need >= 4"); sys.exit(1)
fails = 0
for t in threads:
    for field in req:
        if field not in t:
            print(f"FAIL thread '{t.get('id','?')}' missing '{field}'"); fails += 1
    if not isinstance(t.get("trigger_conditions"), list):
        print(f"FAIL thread '{t.get('id','?')}' trigger_conditions not Array"); fails += 1
    if not isinstance(t.get("stages"), list):
        print(f"FAIL thread '{t.get('id','?')}' stages not Array"); fails += 1
sys.exit(1 if fails else 0)
PY
if [ "$?" -eq 0 ]; then
	echo "  PASS: >= 4 secret threads with required fields"
	PASS=$((PASS + 1))
else
	echo "  FAIL: secret threads missing fields or insufficient count"
	FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
echo ""
echo "[AC4] Every store has >= 10 inventory items"
# ---------------------------------------------------------------------------
python3 - "$CONTENT" <<'PY'
import json, os, sys
STORE_FILES = {
    "sports": "items/sports_memorabilia.json",
    "retro_games": "items/retro_games.json",
    "video_rental": "items/video_rental.json",
    "pocket_creatures": "items/pocket_creatures.json",
    "consumer_electronics": "items/consumer_electronics.json",
}
fails = 0
for store, rel in STORE_FILES.items():
    path = os.path.join(sys.argv[1], rel)
    if not os.path.exists(path):
        print(f"FAIL: {store} item file not found at {path}"); fails += 1; continue
    with open(path) as f:
        data = json.load(f)
    items = data if isinstance(data, list) else data.get("items", [])
    if len(items) < 10:
        print(f"FAIL: {store} has {len(items)} items, need >= 10"); fails += 1
sys.exit(1 if fails else 0)
PY
if [ "$?" -eq 0 ]; then
	echo "  PASS: every store has >= 10 inventory items"
	PASS=$((PASS + 1))
else
	echo "  FAIL: some stores have too few inventory items"
	FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
echo ""
echo "[AC5] Parameterized GUT content integrity test present"
# ---------------------------------------------------------------------------
check "test_content_integrity.gd in tests/gut/" \
	test -f "$ROOT/tests/gut/test_content_integrity.gd"
check "test iterates ambient_moments" \
	grep -q "ambient_moments_have_required_fields" "$ROOT/tests/gut/test_content_integrity.gd"
check "test iterates seasons" \
	grep -q "seasons_have_required_fields" "$ROOT/tests/gut/test_content_integrity.gd"
check "test iterates secret_threads" \
	grep -q "secret_threads_have_required_fields" "$ROOT/tests/gut/test_content_integrity.gd"
check "test validates inventory counts" \
	grep -q "inventory_minimum_counts" "$ROOT/tests/gut/test_content_integrity.gd"

# ---------------------------------------------------------------------------
echo ""
echo "[AC6] ContentValidator — season schema present in ContentSchema"
# ---------------------------------------------------------------------------
check "season schema added to ContentSchema" \
	grep -q '"season":' "$ROOT/game/scripts/core/content_schema.gd"
check "DataLoader validates seasons with ContentSchema" \
	grep -q "ContentSchema.validate" "$ROOT/game/autoload/data_loader.gd"

# Verify season schema body contains required field names.
SCHEMA_FILE="$ROOT/game/scripts/core/content_schema.gd"
python3 - "$SCHEMA_FILE" <<'PY'
import sys, re
text = open(sys.argv[1]).read()
fails = 0
# Extract season schema block.
m = re.search(r'"season":\s*\{(.+?)\},\s*"item":', text, re.DOTALL)
if not m:
    print("FAIL: could not locate season schema block"); sys.exit(1)
block = m.group(1)
for field in ["event_pool", "price_modifier_table", "visual_variant"]:
    if field not in block:
        print(f"FAIL: '{field}' not in season schema"); fails += 1
# Extract ambient_moment schema block.
m2 = re.search(r'"ambient_moment":\s*\{(.+?)\},\s*"secret_thread":', text, re.DOTALL)
if not m2:
    print("FAIL: could not locate ambient_moment schema block"); sys.exit(1)
block2 = m2.group(1)
for field in ["store_id", "season_id", "min_day", "max_day", "duration_seconds"]:
    if field not in block2:
        print(f"FAIL: '{field}' not in ambient_moment schema"); fails += 1
# Extract secret_thread schema block.
m3 = re.search(r'"secret_thread":\s*\{(.+?)\},\s*"milestone":', text, re.DOTALL)
if not m3:
    print("FAIL: could not locate secret_thread schema block"); sys.exit(1)
block3 = m3.group(1)
for field in ["trigger_conditions", "stages", "resolution_text"]:
    if field not in block3:
        print(f"FAIL: '{field}' not in secret_thread schema"); fails += 1
sys.exit(1 if fails else 0)
PY
if [ "$?" -eq 0 ]; then
	echo "  PASS: ContentSchema contains all new required fields"
	PASS=$((PASS + 1))
else
	echo "  FAIL: ContentSchema missing new required fields"
	FAIL=$((FAIL + 1))
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
if [ "$FAIL" -eq 0 ]; then
	echo "All ISSUE-027 (Phase 6 content volume) acceptance criteria validated."
	exit 0
fi
exit 1
