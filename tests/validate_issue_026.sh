#!/usr/bin/env bash
# Validate ISSUE-026: Placement and haggle/trade result feedback animations
set -euo pipefail

FIXTURE_CATALOG="game/scenes/ui/fixture_catalog.gd"
HAGGLE_PANEL="game/scenes/ui/haggle_panel.gd"
TRADE_PANEL="game/scripts/ui/trade_panel.gd"
EXIT_CODE=0

echo "=== ISSUE-026: Placement & Haggle/Trade Feedback Animations ==="

for f in "$FIXTURE_CATALOG" "$HAGGLE_PANEL" "$TRADE_PANEL"; do
    if [ ! -f "$f" ]; then
        echo "FAIL: $f not found"
        EXIT_CODE=1
    fi
done

echo ""
echo "[Fixture Placement Success - Scale Punch]"

if grep -q "EventBus.fixture_placed.connect" "$FIXTURE_CATALOG"; then
    echo "PASS: fixture_catalog connects to EventBus.fixture_placed"
else
    echo "FAIL: fixture_catalog should connect to EventBus.fixture_placed"
    EXIT_CODE=1
fi

if grep -q "PLACEMENT_PUNCH_SCALE.*1.08" "$FIXTURE_CATALOG"; then
    echo "PASS: PLACEMENT_PUNCH_SCALE = 1.08"
else
    echo "FAIL: PLACEMENT_PUNCH_SCALE should be 1.08"
    EXIT_CODE=1
fi

if grep -q "PLACEMENT_PUNCH_DURATION.*0.2" "$FIXTURE_CATALOG"; then
    echo "PASS: PLACEMENT_PUNCH_DURATION = 0.2"
else
    echo "FAIL: PLACEMENT_PUNCH_DURATION should be 0.2"
    EXIT_CODE=1
fi

if grep -q "PanelAnimator.pulse_scale" "$FIXTURE_CATALOG"; then
    echo "PASS: fixture_catalog uses PanelAnimator.pulse_scale for success"
else
    echo "FAIL: fixture_catalog should use PanelAnimator.pulse_scale"
    EXIT_CODE=1
fi

echo ""
echo "[Fixture Placement Failure - Shake + Red Flash]"

if grep -q "EventBus.fixture_placement_invalid.connect" "$FIXTURE_CATALOG"; then
    echo "PASS: fixture_catalog connects to EventBus.fixture_placement_invalid"
else
    echo "FAIL: fixture_catalog should connect to EventBus.fixture_placement_invalid"
    EXIT_CODE=1
fi

if grep -q "PanelAnimator.shake" "$FIXTURE_CATALOG"; then
    echo "PASS: fixture_catalog uses PanelAnimator.shake for failure"
else
    echo "FAIL: fixture_catalog should use PanelAnimator.shake"
    EXIT_CODE=1
fi

if grep -q "PanelAnimator.flash_color" "$FIXTURE_CATALOG"; then
    echo "PASS: fixture_catalog uses PanelAnimator.flash_color for failure"
else
    echo "FAIL: fixture_catalog should use PanelAnimator.flash_color"
    EXIT_CODE=1
fi

if grep -q "get_negative_color" "$FIXTURE_CATALOG"; then
    echo "PASS: fixture_catalog uses negative color for failure flash"
else
    echo "FAIL: fixture_catalog should use negative color for failure flash"
    EXIT_CODE=1
fi

echo ""
echo "[Haggle Accepted - Green Flash]"

if grep -q "get_positive_color" "$HAGGLE_PANEL"; then
    echo "PASS: haggle_panel uses positive color for accept flash"
else
    echo "FAIL: haggle_panel should use positive color for accept flash"
    EXIT_CODE=1
fi

if grep -q "PanelAnimator.flash_color" "$HAGGLE_PANEL"; then
    echo "PASS: haggle_panel uses PanelAnimator.flash_color"
else
    echo "FAIL: haggle_panel should use PanelAnimator.flash_color"
    EXIT_CODE=1
fi

echo ""
echo "[Haggle Declined - Red Flash + Shake]"

if grep -q "get_negative_color" "$HAGGLE_PANEL"; then
    echo "PASS: haggle_panel uses negative color for decline flash"
else
    echo "FAIL: haggle_panel should use negative color for decline flash"
    EXIT_CODE=1
fi

if grep -q "PanelAnimator.shake" "$HAGGLE_PANEL"; then
    echo "PASS: haggle_panel uses PanelAnimator.shake for decline"
else
    echo "FAIL: haggle_panel should use PanelAnimator.shake for decline"
    EXIT_CODE=1
fi

echo ""
echo "[Trade Accepted - Green Flash]"

if grep -q "get_positive_color" "$TRADE_PANEL"; then
    echo "PASS: trade_panel uses positive color for accept flash"
else
    echo "FAIL: trade_panel should use positive color for accept flash"
    EXIT_CODE=1
fi

if grep -q "PanelAnimator.flash_color" "$TRADE_PANEL"; then
    echo "PASS: trade_panel uses PanelAnimator.flash_color"
else
    echo "FAIL: trade_panel should use PanelAnimator.flash_color"
    EXIT_CODE=1
fi

echo ""
echo "[Trade Declined - Red Flash + Shake]"

if grep -q "get_negative_color" "$TRADE_PANEL"; then
    echo "PASS: trade_panel uses negative color for decline flash"
else
    echo "FAIL: trade_panel should use negative color for decline flash"
    EXIT_CODE=1
fi

if grep -q "PanelAnimator.shake" "$TRADE_PANEL"; then
    echo "PASS: trade_panel uses PanelAnimator.shake for decline"
else
    echo "FAIL: trade_panel should use PanelAnimator.shake for decline"
    EXIT_CODE=1
fi

echo ""
echo "[Feedback Tween Management]"

if grep -q "_feedback_tween: Tween" "$HAGGLE_PANEL"; then
    echo "PASS: haggle_panel has _feedback_tween variable"
else
    echo "FAIL: haggle_panel should have _feedback_tween variable"
    EXIT_CODE=1
fi

if grep -q "_feedback_tween: Tween" "$TRADE_PANEL"; then
    echo "PASS: trade_panel has _feedback_tween variable"
else
    echo "FAIL: trade_panel should have _feedback_tween variable"
    EXIT_CODE=1
fi

if grep -q "_feedback_tween: Tween" "$FIXTURE_CATALOG"; then
    echo "PASS: fixture_catalog has _feedback_tween variable"
else
    echo "FAIL: fixture_catalog should have _feedback_tween variable"
    EXIT_CODE=1
fi

if grep -q "PanelAnimator.kill_tween(_feedback_tween)" "$HAGGLE_PANEL"; then
    echo "PASS: haggle_panel kills feedback tween before new animation"
else
    echo "FAIL: haggle_panel should kill feedback tween before new animation"
    EXIT_CODE=1
fi

if grep -q "PanelAnimator.kill_tween(_feedback_tween)" "$TRADE_PANEL"; then
    echo "PASS: trade_panel kills feedback tween before new animation"
else
    echo "FAIL: trade_panel should kill feedback tween before new animation"
    EXIT_CODE=1
fi

if grep -q "PanelAnimator.kill_tween(_feedback_tween)" "$FIXTURE_CATALOG"; then
    echo "PASS: fixture_catalog kills feedback tween before new animation"
else
    echo "FAIL: fixture_catalog should kill feedback tween before new animation"
    EXIT_CODE=1
fi

echo ""
echo "[Animation Duration - 0.2s]"

if grep -q "FEEDBACK_SHAKE_DURATION" "$HAGGLE_PANEL"; then
    echo "PASS: haggle_panel uses FEEDBACK_SHAKE_DURATION (0.2s)"
else
    echo "FAIL: haggle_panel should use FEEDBACK_SHAKE_DURATION"
    EXIT_CODE=1
fi

if grep -q "FEEDBACK_SHAKE_DURATION" "$TRADE_PANEL"; then
    echo "PASS: trade_panel uses FEEDBACK_SHAKE_DURATION (0.2s)"
else
    echo "FAIL: trade_panel should use FEEDBACK_SHAKE_DURATION"
    EXIT_CODE=1
fi

echo ""
echo "=== Results ==="
if [ $EXIT_CODE -eq 0 ]; then
    echo "All ISSUE-026 checks passed."
else
    echo "Some ISSUE-026 checks failed."
fi

exit $EXIT_CODE
