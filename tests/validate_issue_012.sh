#!/usr/bin/env bash
# Validates ISSUE-012: Retro Games — refurbishment quality assessment mechanic.
set -u

PASS=0
FAIL=0

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RETRO_GD="$ROOT/game/scripts/stores/retro_games.gd"
REFURB_GD="$ROOT/game/scripts/systems/refurbishment_system.gd"
TESTING_GD="$ROOT/game/scripts/systems/testing_system.gd"
EVENT_BUS="$ROOT/game/autoload/event_bus.gd"
GRADES_JSON="$ROOT/game/content/stores/retro_games/grades.json"

echo ""
echo "=== ISSUE-012: Retro Games — refurbishment quality assessment mechanic ==="
echo ""

echo "[AC1] grades.json content file"
check "grades.json exists" test -f "$GRADES_JSON"
check "grades array present" grep -q '"grades"' "$GRADES_JSON"
check "grade: mint" grep -q '"id": "mint"' "$GRADES_JSON"
check "grade: near_mint" grep -q '"id": "near_mint"' "$GRADES_JSON"
check "grade: good" grep -q '"id": "good"' "$GRADES_JSON"
check "grade: fair" grep -q '"id": "fair"' "$GRADES_JSON"
check "grade: poor" grep -q '"id": "poor"' "$GRADES_JSON"
check "grades have price_multiplier" grep -q '"price_multiplier"' "$GRADES_JSON"

echo ""
echo "[AC2] EventBus signals for inspection flow"
check "inspection_ready signal declared" grep -q "signal inspection_ready" "$EVENT_BUS"
check "grade_assigned signal declared" grep -q "signal grade_assigned" "$EVENT_BUS"
check "item_priced signal declared" grep -q "signal item_priced" "$EVENT_BUS"

echo ""
echo "[AC3] RetroGames controller — quality assessment methods"
check "RetroGames class exists" test -f "$RETRO_GD"
check "class_name RetroGames declared" grep -q "^class_name RetroGames" "$RETRO_GD"
check "inspect_item() method" grep -q "^func inspect_item" "$RETRO_GD"
check "assign_grade() method" grep -q "^func assign_grade" "$RETRO_GD"
check "get_item_price() method" grep -q "^func get_item_price" "$RETRO_GD"
check "can_test_item() method" grep -q "^func can_test_item" "$RETRO_GD"
check "test_item() method" grep -q "^func test_item" "$RETRO_GD"
check "emits inspection_ready signal" grep -q "inspection_ready.emit" "$RETRO_GD"
check "emits grade_assigned signal" grep -q "grade_assigned.emit" "$RETRO_GD"
check "emits item_priced signal" grep -q "item_priced.emit" "$RETRO_GD"

echo ""
echo "[AC4] Price routing through PriceResolver"
check "get_item_price uses PriceResolver.resolve_for_item" grep -q "PriceResolver.resolve_for_item" "$RETRO_GD"
check "grade multiplier passed to PriceResolver" grep -q "price_multiplier" "$RETRO_GD"

echo ""
echo "[AC5] RefurbishmentSystem"
check "refurbishment_system.gd exists" test -f "$REFURB_GD"
check "class_name RefurbishmentSystem" grep -q "^class_name RefurbishmentSystem" "$REFURB_GD"
check "can_refurbish() method" grep -q "^func can_refurbish" "$REFURB_GD"
check "start_refurbishment() method" grep -q "^func start_refurbishment" "$REFURB_GD"
check "get_save_data() on RefurbishmentSystem" grep -q "^func get_save_data" "$REFURB_GD"
check "load_save_data() on RefurbishmentSystem" grep -q "^func load_save_data" "$REFURB_GD"

echo ""
echo "[AC6] TestingSystem"
check "testing_system.gd exists" test -f "$TESTING_GD"
check "class_name TestingSystem" grep -q "^class_name TestingSystem" "$TESTING_GD"
check "can_test() method" grep -q "^func can_test" "$TESTING_GD"
check "start_test() method" grep -q "^func start_test" "$TESTING_GD"

echo ""
echo "[AC7] Dependency injection setters"
check "set_refurbishment_system() setter" grep -q "^func set_refurbishment_system" "$RETRO_GD"
check "set_testing_system() setter" grep -q "^func set_testing_system" "$RETRO_GD"
check "get_refurbishment_system() getter" grep -q "^func get_refurbishment_system" "$RETRO_GD"
check "get_testing_system() getter" grep -q "^func get_testing_system" "$RETRO_GD"

echo ""
echo "[AC8] Save/load persistence"
check "get_save_data() on RetroGames" grep -q "^func get_save_data" "$RETRO_GD"
check "load_save_data() on RetroGames" grep -q "^func load_save_data" "$RETRO_GD"
check "item_grades persisted in get_save_data" grep -q '"item_grades"' "$RETRO_GD"

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "All ISSUE-012 acceptance criteria validated."
else
  echo "Some checks failed."
  exit 1
fi
