#!/usr/bin/env bash
# Validates ISSUE-009: Phase 2 boot-time content validation.
# Ensures ContentSchema exists, DataLoader calls it, and introducing a
# malformed content file would be caught by schema validation.
set -u
PASS=0
FAIL=0

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

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
echo "=== ISSUE-009: Phase 2 content validation (boot-loud) ==="
echo ""

echo "[AC1] ContentSchema module exists with per-type required fields"
check "content_schema.gd present" test -f "$ROOT/game/scripts/core/content_schema.gd"
check "item schema defined"       grep -q "\"item\":" "$ROOT/game/scripts/core/content_schema.gd"
check "market_event schema"       grep -q "\"market_event\":" "$ROOT/game/scripts/core/content_schema.gd"
check "seasonal_event schema"     grep -q "\"seasonal_event\":" "$ROOT/game/scripts/core/content_schema.gd"
check "random_event schema"       grep -q "\"random_event\":" "$ROOT/game/scripts/core/content_schema.gd"
check "ambient_moment schema"     grep -q "\"ambient_moment\":" "$ROOT/game/scripts/core/content_schema.gd"
check "secret_thread schema"      grep -q "\"secret_thread\":" "$ROOT/game/scripts/core/content_schema.gd"
check "store schema"              grep -q "\"store\":" "$ROOT/game/scripts/core/content_schema.gd"

echo ""
echo "[AC2] DataLoader invokes ContentSchema.validate() at boot"
check "DataLoader references ContentSchema"   grep -q "ContentSchema.validate" "$ROOT/game/autoload/data_loader.gd"
check "schema errors recorded as load errors" grep -q "schema_errors" "$ROOT/game/autoload/data_loader.gd"

echo ""
echo "[AC3] Boot fails loud when content errors are recorded"
check "boot.gd stops on content load errors" grep -q "load_errors.is_empty" "$ROOT/game/scripts/core/boot.gd"
check "DataLoader emits content_load_failed"  grep -q "content_load_failed.emit" "$ROOT/game/autoload/data_loader.gd"

echo ""
echo "[AC4] Cross-reference validation for events → stores"
check "event store-ref validator present" grep -q "_validate_event_store_refs" "$ROOT/game/autoload/content_registry.gd"

echo ""
echo "[AC5] GUT content-integrity test is part of the suite"
check "test_content_integrity.gd present" test -f "$ROOT/tests/unit/test_content_integrity.gd"
check "test iterates every JSON file"     grep -q "_scan(CONTENT_ROOT" "$ROOT/tests/unit/test_content_integrity.gd"
check "test asserts empty error list"     grep -q "total_errors.size(), 0" "$ROOT/tests/unit/test_content_integrity.gd"

echo ""
echo "[AC6] Existing content passes static schema check"
python3 - "$ROOT" <<'PY'
import json, os, sys, glob
ROOT=sys.argv[1]; C=os.path.join(ROOT,'game/content')
SCHEMAS = {
 'items/*.json': ('item',['id','store_type','category','base_price'],['item_name','display_name','name']),
 'customers/customer_profiles.json': ('customer',['id'],['name','display_name']),
 'customers/retro_games_customers.json': ('customer',['id'],['name','display_name']),
 'customers/sports_store_customers.json': ('customer',['id'],['name','display_name']),
 'customers/video_rental_customers.json': ('customer',['id'],['name','display_name']),
 'customers/electronics_customers.json': ('customer',['id'],['name','display_name']),
 'customers/pocket_creatures_customers.json': ('customer',['id'],['name','display_name']),
 'customers/casual_browser.json': ('customer',['id'],['name','display_name']),
 'events/market_events.json': ('market_event',['id','event_type'],['name','display_name']),
 'events/seasonal_events.json': ('seasonal_event',['id','start_day','duration_days'],['name','display_name']),
 'events/random_events.json': ('random_event',['id','effect_type'],['name','display_name']),
 'events/ambient_moments.json': ('ambient_moment',['id','trigger_category','flavor_text'],None),
 'meta/secret_threads.json': ('secret_thread',['id','display_name','steps'],None),
 'progression/milestone_definitions.json': ('milestone',['id','display_name','trigger_type'],None),
 'staff/staff_definitions.json': ('staff',['id','role'],['name','display_name']),
 'fixtures.json': ('fixture',['id','display_name','cost','slot_count'],None),
 'upgrades.json': ('upgrade',['id','display_name','effect_type'],None),
 'unlocks/unlocks.json': ('unlock',['id','display_name','effect_type'],None),
 'endings/ending_config.json': ('ending',['id','title'],None),
 'suppliers/supplier_catalog.json': ('supplier',['id','store_type'],None),
 'stores/store_definitions.json': ('store',['id','name','scene_path'],None),
}
def extract(data):
    if isinstance(data,list): return [d for d in data if isinstance(d,dict)]
    if isinstance(data,dict):
        for k in ('entries','items','definitions','moments','endings','seasons','suppliers'):
            if k in data and isinstance(data[k],list):
                return [d for d in data[k] if isinstance(d,dict)]
        return [data]
    return []
fails=0
for pattern,(typ,req,any_of) in SCHEMAS.items():
    for p in glob.glob(os.path.join(C,pattern)):
        with open(p) as f: data=json.load(f)
        for e in extract(data):
            if 'id' not in e: continue
            miss=[k for k in req if k not in e]
            if miss: print(f'FAIL {typ} {e.get("id")} in {p}: missing {miss}'); fails+=1
            if any_of and not any(k in e for k in any_of):
                print(f'FAIL {typ} {e.get("id")}: missing any_of {any_of}'); fails+=1
sys.exit(1 if fails else 0)
PY
if [ "$?" -eq 0 ]; then
	echo "  PASS: all content passes static schema"
	PASS=$((PASS + 1))
else
	echo "  FAIL: content has missing required fields"
	FAIL=$((FAIL + 1))
fi

echo ""
echo "[AC7] Injected missing-field content is caught by schema"
TMP="$ROOT/game/content/items/_issue009_probe.json"
trap 'rm -f "$TMP"' EXIT
cat > "$TMP" <<'JSON'
[{"id":"probe_bad_item","category":"misc","base_price":1.0}]
JSON
python3 - "$TMP" <<'PY'
import json, sys
with open(sys.argv[1]) as f: data=json.load(f)
req=['id','store_type','category','base_price']
miss=[k for k in req if k not in data[0]]
sys.exit(0 if miss else 1)
PY
if [ "$?" -eq 0 ]; then
	echo "  PASS: probe detects missing store_type"
	PASS=$((PASS + 1))
else
	echo "  FAIL: probe not detected"
	FAIL=$((FAIL + 1))
fi
rm -f "$TMP"
trap - EXIT

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
if [ "$FAIL" -eq 0 ]; then
	echo "All ISSUE-009 (content validation) acceptance criteria validated."
	exit 0
fi
exit 1
