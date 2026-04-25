#!/usr/bin/env bash
# Validates AIDLC ISSUE-014: Consolidate duplicate store controllers —
# no hollow scene-side .gd files exist alongside authoritative controllers.
set -u

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo ""
echo "=== ISSUE-014 (controllers): Store controller consolidation ==="
echo ""

STORES_DIR="$ROOT/game/scripts/stores"

# AC1: Each of the 5 stores has exactly one authoritative script.
# Orphan candidates identified in docs/research/duplicate-store-scripts.md
# must not exist on disk.
echo "[AC1] No orphan store scripts alongside canonical controllers"
for orphan in \
  "$STORES_DIR/retro_games_store_controller.gd" \
  "$STORES_DIR/video_rental.gd" \
  "$STORES_DIR/consumer_electronics.gd" \
  "$STORES_DIR/sports_memorabilia.gd" \
  "$STORES_DIR/pocket_creatures.gd"
do
  name="$(basename "$orphan")"
  if [ -f "$orphan" ]; then
    fail "$name orphan exists and must be deleted"
  else
    pass "$name orphan absent"
  fi
done

echo ""
echo "[AC1b] All 5 canonical controllers exist"
_check_canonical() {
  local store="$1" path="$2"
  if [ -f "$path" ]; then
    pass "$store canonical controller present"
  else
    fail "$store canonical controller MISSING: $path"
  fi
}
_check_canonical "retro_games"          "$STORES_DIR/retro_games.gd"
_check_canonical "video_rental"         "$STORES_DIR/video_rental_store_controller.gd"
_check_canonical "sports_memorabilia"   "$STORES_DIR/sports_memorabilia_controller.gd"
_check_canonical "consumer_electronics" "$STORES_DIR/electronics_store_controller.gd"
_check_canonical "pocket_creatures"     "$STORES_DIR/pocket_creatures_store_controller.gd"

echo ""
echo "[AC1c] Each .tscn references the canonical controller and not an orphan"

SCENES_DIR="$ROOT/game/scenes/stores"

_check_tscn_script() {
  local store="$1"
  local tscn="$SCENES_DIR/${store}.tscn"
  local expected="$2"
  if [ ! -f "$tscn" ]; then
    fail "$store.tscn not found"
    return
  fi
  if grep -q "\"${expected}\"" "$tscn" 2>/dev/null || \
     grep -q "path=\"res://game/scripts/stores/${expected}\"" "$tscn" 2>/dev/null || \
     grep "type=\"Script\"" "$tscn" | grep -q "$expected"; then
    pass "$store.tscn references $expected"
  else
    fail "$store.tscn does not reference $expected (check ext_resource)"
  fi
}

_check_tscn_script "retro_games" "retro_games.gd"
_check_tscn_script "video_rental" "video_rental_store_controller.gd"
_check_tscn_script "sports_memorabilia" "sports_memorabilia_controller.gd"
_check_tscn_script "consumer_electronics" "electronics_store_controller.gd"
_check_tscn_script "pocket_creatures" "pocket_creatures_store_controller.gd"

echo ""
echo "[AC2] game_world.gd has no deleted-script file-path references"

GAME_WORLD="$ROOT/game/scenes/world/game_world.gd"
FORBIDDEN_PATHS=(
  "scene_side_retro_games"
  "game/scenes/stores/retro_games.gd"
  "scene_side_video_rental"
  "scene_side_consumer_electronics"
  "scene_side_sports_memorabilia"
  "scene_side_pocket_creatures"
)
LEAKS=0
for pat in "${FORBIDDEN_PATHS[@]}"; do
  if grep -q "$pat" "$GAME_WORLD" 2>/dev/null; then
    fail "game_world.gd references forbidden path/pattern: $pat"
    LEAKS=$((LEAKS + 1))
  fi
done
if [ "$LEAKS" -eq 0 ]; then
  pass "game_world.gd has no forbidden scene-side script path refs"
fi

# Confirm game_world.gd wires stores via class names (not file paths)
if grep -q "is RetroGames" "$GAME_WORLD" && \
   grep -q "is VideoRentalStoreController" "$GAME_WORLD" && \
   grep -q "is ElectronicsStoreController" "$GAME_WORLD" && \
   grep -q "is SportsMemorabiliaController" "$GAME_WORLD" && \
   grep -q "is PocketCreaturesStoreController" "$GAME_WORLD"; then
  pass "game_world.gd wires all 5 controllers via class-name type checks"
else
  fail "game_world.gd missing expected class-name type checks for one or more stores"
fi

echo ""
echo "[AC3] electronics_lifecycle_manager.gd is a used helper (not an orphan)"
if grep -q "ElectronicsLifecycleManager" "$STORES_DIR/electronics_store_controller.gd" 2>/dev/null; then
  pass "electronics_lifecycle_manager.gd referenced by electronics_store_controller.gd"
else
  fail "electronics_lifecycle_manager.gd not referenced by electronics_store_controller.gd"
fi

echo ""
echo "[AC4] docs/research/duplicate-store-scripts.md exists with findings"
RESEARCH_DOC="$ROOT/docs/research/duplicate-store-scripts.md"
if [ -f "$RESEARCH_DOC" ]; then
  pass "duplicate-store-scripts.md research doc exists"
  if grep -q "no true duplication\|canonical\|orphan" "$RESEARCH_DOC"; then
    pass "duplicate-store-scripts.md contains findings summary"
  else
    fail "duplicate-store-scripts.md appears empty or missing expected content"
  fi
else
  fail "duplicate-store-scripts.md research doc missing"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "All ISSUE-014 controller-consolidation acceptance criteria validated."
  exit 0
else
  echo "One or more checks failed."
  exit 1
fi
