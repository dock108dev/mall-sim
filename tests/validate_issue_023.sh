#!/usr/bin/env bash
# Validate ISSUE-023: Slide animations on 6 side panels
set -eo pipefail

EXIT_CODE=0
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); EXIT_CODE=1; }

echo "=== ISSUE-023: Slide Animations for 6 Side Panels ==="
echo ""

check_panel() {
    local FILE="$1"
    local FROM_LEFT="$2"
    local BASENAME
    BASENAME=$(basename "$FILE" .gd)
    echo "[$BASENAME]"

    if [ ! -f "$FILE" ]; then
        fail "$FILE not found"
        return
    fi

    # AC: _anim_tween var exists
    if grep -q "var _anim_tween: Tween" "$FILE"; then
        pass "_anim_tween variable declared"
    else
        fail "_anim_tween variable missing"
    fi

    # AC: _rest_x caching
    if grep -q "var _rest_x: float" "$FILE"; then
        pass "_rest_x variable declared"
    else
        fail "_rest_x variable missing"
    fi

    # AC: _rest_x initialized
    if grep -q "_rest_x = _panel.position.x" "$FILE"; then
        pass "_rest_x cached from panel position"
    else
        fail "_rest_x not cached from panel position"
    fi

    # AC: Uses PanelAnimator.slide_open
    if grep -q "PanelAnimator.slide_open(" "$FILE"; then
        pass "Uses PanelAnimator.slide_open()"
    else
        fail "Missing PanelAnimator.slide_open()"
    fi

    # AC: Uses PanelAnimator.slide_close
    if grep -q "PanelAnimator.slide_close(" "$FILE"; then
        pass "Uses PanelAnimator.slide_close()"
    else
        fail "Missing PanelAnimator.slide_close()"
    fi

    # AC: Calls PanelAnimator.kill_tween before animations
    if grep -q "PanelAnimator.kill_tween(_anim_tween)" "$FILE"; then
        pass "Calls PanelAnimator.kill_tween()"
    else
        fail "Missing PanelAnimator.kill_tween() call"
    fi

    # AC: Correct slide direction (args may span multiple lines)
    if tr '\n\t' '  ' < "$FILE" | grep -q "slide_open.*_rest_x, ${FROM_LEFT}"; then
        if [ "$FROM_LEFT" = "true" ]; then
            pass "Slides from left (store operation)"
        else
            pass "Slides from right (meta/management)"
        fi
    else
        fail "Wrong slide direction (expected from_left=$FROM_LEFT)"
    fi

    # AC: Emits panel_opened signal
    if grep -q "EventBus.panel_opened.emit(" "$FILE"; then
        pass "Emits EventBus.panel_opened"
    else
        fail "Missing EventBus.panel_opened emission"
    fi

    # AC: Emits panel_closed signal
    if grep -q "EventBus.panel_closed.emit(" "$FILE"; then
        pass "Emits EventBus.panel_closed"
    else
        fail "Missing EventBus.panel_closed emission"
    fi

    # AC: close() has immediate parameter for rapid close
    if grep -q "func close(immediate: bool = false)" "$FILE"; then
        pass "close() supports immediate parameter"
    else
        fail "close() missing immediate parameter"
    fi

    # AC: Immediate close resets position
    if grep -q "_panel.position.x = _rest_x" "$FILE"; then
        pass "Immediate close resets position to _rest_x"
    else
        fail "Immediate close missing position reset"
    fi

    # AC: Auto-close on other panel open uses immediate
    if grep -q 'close(true)' "$FILE"; then
        pass "Auto-close uses immediate mode"
    else
        fail "Auto-close should use immediate mode"
    fi

    echo ""
}

# OrderPanel slides from LEFT (store operation)
check_panel "game/scenes/ui/order_panel.gd" "true"

# Right-sliding panels (meta/management)
check_panel "game/scenes/ui/staff_panel.gd" "false"
check_panel "game/scenes/ui/trends_panel.gd" "false"
check_panel "game/scenes/ui/milestones_panel.gd" "false"
check_panel "game/scenes/ui/fixture_catalog.gd" "false"
check_panel "game/scenes/ui/fixture_upgrade_panel.gd" "false"

TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo "All ISSUE-023 acceptance criteria validated."
else
    echo "Some ISSUE-023 checks failed."
fi

exit $EXIT_CODE
