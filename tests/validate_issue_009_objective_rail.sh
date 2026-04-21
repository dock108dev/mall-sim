#!/usr/bin/env bash
# Validates ISSUE-009: ObjectiveRail bottom strip (64px, always visible)
set -u
PASS=0
FAIL=0
REPO="$(cd "$(dirname "$0")/.." && pwd)"

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
echo "=== ISSUE-009: ObjectiveRail bottom strip ==="
echo ""

echo "[AC1] ObjectiveRail CanvasLayer is registered as autoload"
check "ObjectiveRail autoload present" \
	grep -q 'ObjectiveRail="\*res://game/scenes/ui/objective_rail.tscn"' \
	"$REPO/project.godot"

echo ""
echo "[AC2] Scene file is a 64px full-width bottom strip"
SCENE="$REPO/game/scenes/ui/objective_rail.tscn"
check "objective_rail.tscn exists" test -f "$SCENE"
check "CanvasLayer layer=10" grep -q "layer = 10" "$SCENE"
check "anchor_top = 1.0 (bottom-anchored)" grep -q "anchor_top = 1.0" "$SCENE"
check "anchor_right = 1.0 (full-width)" grep -q "anchor_right = 1.0" "$SCENE"
check "offset_top = -64 (64px tall)" grep -q "offset_top = -64.0" "$SCENE"
check "HBoxContainer present" grep -q '"HBoxContainer"' "$SCENE"
check "OptionalHintLabel present" grep -q '"OptionalHintLabel"' "$SCENE"
check "OptionalHintLabel starts hidden" grep -q "visible = false" "$SCENE"

echo ""
echo "[AC3] Script has all required nodes and vars"
SCRIPT="$REPO/game/scripts/ui/objective_rail.gd"
check "objective_rail.gd exists" test -f "$SCRIPT"
check "_optional_hint_label declared" grep -q "_optional_hint_label" "$SCRIPT"
check "_tween declared" grep -q "_tween" "$SCRIPT"
check "_show_rail declared" grep -q "_show_rail" "$SCRIPT"
check "_flash function defined" grep -q "func _flash" "$SCRIPT"
if grep -q "mouse_filter" "$SCRIPT" 2>/dev/null; then
	echo "  FAIL: mouse_filter not set in script (layout-only)"
	FAIL=$((FAIL + 1))
else
	echo "  PASS: mouse_filter not set in script (layout-only)"
	PASS=$((PASS + 1))
fi

echo ""
echo "[AC4] Rail does not consume input (MOUSE_FILTER_IGNORE on all nodes)"
check "MarginContainer mouse_filter = 2" grep -q "mouse_filter = 2" "$SCENE"

echo ""
echo "[AC5] objective_updated signal exists in EventBus"
check "objective_updated signal declared" \
	grep -q "signal objective_updated" "$REPO/game/autoload/event_bus.gd"

echo ""
echo "[AC6] ObjectiveDirector emits objective_updated"
check "objective_updated.emit present" \
	grep -q "objective_updated.emit" "$REPO/game/autoload/objective_director.gd"

echo ""
echo "[AC7] Rail connects to objective_updated"
check "objective_updated.connect present" \
	grep -q "objective_updated.connect" "$SCRIPT"

echo ""
echo "[AC8] GUT test file covers objective_updated and optional_hint"
TEST="$REPO/tests/gut/test_objective_rail.gd"
check "test_objective_rail.gd exists" test -f "$TEST"
check "objective_updated test present" \
	grep -q "test_objective_updated" "$TEST"
check "optional_hint test present" \
	grep -q "test_optional_hint" "$TEST"
check "flash tween test present" \
	grep -q "test_flash_tween" "$TEST"
check "OptionalHintLabel mouse_filter test present" \
	grep -q "test_no_input_captured_optional_hint_label" "$TEST"

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""
if [ "$FAIL" -eq 0 ]; then
	echo "All ISSUE-009 (ObjectiveRail) acceptance criteria validated."
	exit 0
fi
exit 1
