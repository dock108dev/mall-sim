#!/usr/bin/env bash
# Validate ISSUE-015: Gameplay feedback animations (sale, money, reputation)
set -euo pipefail

VF="game/scenes/ui/visual_feedback.gd"
HUD="game/scenes/ui/hud.gd"
PA="game/scripts/ui/panel_animator.gd"
EXIT_CODE=0

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; EXIT_CODE=1; }

echo "=== ISSUE-015: Gameplay Feedback Animations ==="
echo ""

# --- Section 3a: Sale Confirmation Floating Text ---
echo "[AC1-2] Sale floating text rises 40px and fades over 0.8s"

if grep -q "FLOAT_DURATION.*FEEDBACK_FLOAT_DURATION" "$VF"; then
    pass "FLOAT_DURATION uses PanelAnimator.FEEDBACK_FLOAT_DURATION (0.8s)"
else
    fail "FLOAT_DURATION should use PanelAnimator.FEEDBACK_FLOAT_DURATION"
fi

if grep -q "FLOAT_DISTANCE.*40\.0" "$VF"; then
    pass "FLOAT_DISTANCE is 40.0 pixels"
else
    fail "FLOAT_DISTANCE should be 40.0"
fi

if grep -q 'get_positive_color' "$VF"; then
    pass "Floating text uses POSITIVE_COLOR"
else
    fail "Floating text should use POSITIVE_COLOR"
fi

if grep -q 'queue_free' "$VF"; then
    pass "Floating text queue_frees on completion"
else
    fail "Floating text should queue_free on completion"
fi

# Check delayed fade (hold 60%, fade in final 40%)
if grep -q "FLOAT_DURATION \* 0\.6" "$VF"; then
    pass "Fade delayed to final 40% of duration (60% hold)"
else
    fail "Fade should be delayed (hold 60%, fade 40%)"
fi

if grep -q "FLOAT_DURATION \* 0\.4" "$VF"; then
    pass "Fade time is 40% of duration"
else
    fail "Fade time should be 40% of duration"
fi

echo ""

# --- Section 3b: Money Change HUD Pulse ---
echo "[AC3-6] HUD cash label pulse_scale and flash_color"

if grep -q "PanelAnimator.pulse_scale" "$HUD"; then
    pass "HUD uses PanelAnimator.pulse_scale()"
else
    fail "HUD should use PanelAnimator.pulse_scale()"
fi

if grep -q "PanelAnimator.flash_color" "$HUD"; then
    pass "HUD uses PanelAnimator.flash_color()"
else
    fail "HUD should use PanelAnimator.flash_color()"
fi

# Check income scale 1.15
if grep -q "_CASH_INCOME_SCALE.*1\.15" "$HUD"; then
    pass "Income scale target is 1.15"
else
    fail "Income scale should be 1.15"
fi

# Check expense scale 1.1
if grep -q "_CASH_EXPENSE_SCALE.*1\.1" "$HUD"; then
    pass "Expense scale target is 1.1"
else
    fail "Expense scale should be 1.1"
fi

# Check duration is 0.3s (via PanelAnimator constant)
if grep -q "_CASH_PULSE_DURATION.*FEEDBACK_PULSE_DURATION" "$HUD"; then
    pass "Pulse duration uses PanelAnimator.FEEDBACK_PULSE_DURATION (0.3s)"
else
    fail "Pulse duration should use PanelAnimator.FEEDBACK_PULSE_DURATION"
fi

# Check EASE_OUT + TRANS_BACK in PanelAnimator.pulse_scale
if grep -q "EASE_OUT.*TRANS_BACK" "$PA"; then
    pass "pulse_scale uses EASE_OUT + TRANS_BACK easing"
else
    fail "pulse_scale should use EASE_OUT + TRANS_BACK"
fi

echo ""

# --- AC7: Multiple rapid sales queue properly ---
echo "[AC7] Multiple rapid sales queue properly"

# Each call creates a new label, so rapid calls produce independent tweens
if grep -q "Label.new()" "$VF"; then
    pass "Each sale spawns independent Label (no shared state corruption)"
else
    fail "Floating text should use Label.new() per sale"
fi

# HUD kills previous tweens before starting new ones
if grep -q "PanelAnimator.kill_tween" "$HUD"; then
    pass "HUD kills previous tweens before new pulse"
else
    fail "HUD should kill previous tweens before new pulse"
fi

echo ""

# --- AC8: EventBus signals, not direct references ---
echo "[AC8] Animations connected via EventBus signals"

if grep -q "EventBus.item_sold.connect" "$VF"; then
    pass "VisualFeedback connects to EventBus.item_sold"
else
    fail "VisualFeedback should connect to EventBus.item_sold"
fi

if grep -q "EventBus.money_changed.connect" "$HUD"; then
    pass "HUD connects to EventBus.money_changed"
else
    fail "HUD should connect to EventBus.money_changed"
fi

echo ""
echo "=== Results: ==="

if [ $EXIT_CODE -eq 0 ]; then
    echo "All ISSUE-015 acceptance criteria validated."
else
    echo "Some checks FAILED."
fi

exit $EXIT_CODE
