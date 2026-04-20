#!/usr/bin/env bash
# Structural validator for ISSUE-034: Persistent Objective Rail
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

check() {
    local desc="$1"; local result="$2"
    if [ "$result" = "pass" ]; then
        echo "  PASS: $desc"; PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
    fi
}

echo "=== ObjectiveRail (ISSUE-034) ==="

echo ""
echo "[AC1] objectives.json content file exists and is valid"
OJSON="$REPO/game/content/objectives.json"
[ -f "$OJSON" ] && check "objectives.json exists" pass || check "objectives.json exists" fail
python3 -c "import json,sys; d=json.load(open('$OJSON')); assert 'objectives' in d and isinstance(d['objectives'],list); assert 'default_text' in d and isinstance(d['default_text'],str); assert len(d['objectives'])>0" 2>/dev/null \
    && check "objectives.json has 'objectives' array and 'default_text' string" pass \
    || check "objectives.json has 'objectives' array and 'default_text' string" fail
python3 -c "import json; d=json.load(open('$OJSON')); [(__import__('sys').exit(1) if not ('day' in e and 'text' in e) else None) for e in d['objectives']]" 2>/dev/null \
    && check "every entry has 'day' and 'text' keys" pass \
    || check "every entry has 'day' and 'text' keys" fail

echo ""
echo "[AC2] ObjectiveRail script exists"
SCRIPT="$REPO/game/scripts/ui/objective_rail.gd"
[ -f "$SCRIPT" ] && check "objective_rail.gd exists" pass || check "objective_rail.gd exists" fail
grep -q "class_name ObjectiveRail" "$SCRIPT" 2>/dev/null && check "class_name ObjectiveRail declared" pass || check "class_name ObjectiveRail declared" fail
grep -q "extends CanvasLayer" "$SCRIPT" 2>/dev/null && check "extends CanvasLayer" pass || check "extends CanvasLayer" fail
grep -q "day_started.connect" "$SCRIPT" 2>/dev/null && check "connects to day_started" pass || check "connects to day_started" fail
grep -q "arc_unlock_triggered.connect" "$SCRIPT" 2>/dev/null && check "connects to arc_unlock_triggered" pass || check "connects to arc_unlock_triggered" fail
grep -q "MOUSE_FILTER_IGNORE\|mouse_filter" "$SCRIPT" 2>/dev/null || true  # filter set in scene, not script

echo ""
echo "[AC3] ObjectiveRail scene file exists with correct structure"
SCENE="$REPO/game/scenes/ui/objective_rail.tscn"
[ -f "$SCENE" ] && check "objective_rail.tscn exists" pass || check "objective_rail.tscn exists" fail
grep -q 'type="CanvasLayer"' "$SCENE" 2>/dev/null && check "root node is CanvasLayer" pass || check "root node is CanvasLayer" fail
grep -q 'type="MarginContainer"' "$SCENE" 2>/dev/null && check "MarginContainer present" pass || check "MarginContainer present" fail
grep -q 'type="Label"' "$SCENE" 2>/dev/null && check "Label present" pass || check "Label present" fail
# mouse_filter = 2 means IGNORE; check both containers
FILTER_COUNT=$(grep -c "mouse_filter = 2" "$SCENE" 2>/dev/null || echo 0)
[ "$FILTER_COUNT" -ge 2 ] && check "mouse_filter=IGNORE on >= 2 nodes" pass || check "mouse_filter=IGNORE on >= 2 nodes" fail

echo ""
echo "[AC4] ObjectiveRail registered as autoload in project.godot"
grep -q 'ObjectiveRail="\*res://game/scenes/ui/objective_rail.tscn"' "$REPO/project.godot" 2>/dev/null \
    && check "ObjectiveRail autoload registered" pass \
    || check "ObjectiveRail autoload registered" fail
# Must appear after TooltipManager (tier 4)
TOOLTIP_LINE=$(grep -n "TooltipManager" "$REPO/project.godot" | head -1 | cut -d: -f1)
RAIL_LINE=$(grep -n "ObjectiveRail" "$REPO/project.godot" | head -1 | cut -d: -f1)
[ -n "$TOOLTIP_LINE" ] && [ -n "$RAIL_LINE" ] && [ "$RAIL_LINE" -gt "$TOOLTIP_LINE" ] \
    && check "ObjectiveRail declared after TooltipManager" pass \
    || check "ObjectiveRail declared after TooltipManager" fail

echo ""
echo "[AC5] Boot validates objectives.json schema"
BOOT="$REPO/game/scripts/core/boot.gd"
grep -q "_validate_objectives" "$BOOT" 2>/dev/null && check "boot.gd calls _validate_objectives()" pass || check "boot.gd calls _validate_objectives()" fail
grep -q "objectives.json" "$BOOT" 2>/dev/null && check "boot.gd references objectives.json path" pass || check "boot.gd references objectives.json path" fail

echo ""
echo "[AC6] GUT test file exists"
TEST="$REPO/tests/gut/test_objective_rail.gd"
[ -f "$TEST" ] && check "test_objective_rail.gd exists" pass || check "test_objective_rail.gd exists" fail
grep -q "day_started.emit" "$TEST" 2>/dev/null && check "test emits day_started signal" pass || check "test emits day_started signal" fail
grep -q "arc_unlock_triggered.emit" "$TEST" 2>/dev/null && check "test emits arc_unlock_triggered signal" pass || check "test emits arc_unlock_triggered signal" fail
grep -q "MOUSE_FILTER_IGNORE" "$TEST" 2>/dev/null && check "test asserts MOUSE_FILTER_IGNORE" pass || check "test asserts MOUSE_FILTER_IGNORE" fail

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && echo "All ISSUE-034 checks passed." || { echo "ISSUE-034 checks FAILED."; exit 1; }
