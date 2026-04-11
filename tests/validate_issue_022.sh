#!/usr/bin/env bash
# Validate ISSUE-022: PanelAnimator extension methods and constants
set -euo pipefail

FILE="game/scripts/ui/panel_animator.gd"
EXIT_CODE=0

echo "=== ISSUE-022: PanelAnimator Extensions ==="

if [ ! -f "$FILE" ]; then
    echo "FAIL: $FILE not found"
    exit 1
fi

# Check new constants
for const in FEEDBACK_FLOAT_DURATION FEEDBACK_PULSE_DURATION FEEDBACK_SHAKE_DURATION \
    BANNER_SLIDE_DURATION BANNER_HOLD_DURATION BUILD_MODE_TRANSITION; do
    if grep -q "const ${const}:" "$FILE"; then
        echo "PASS: Constant $const exists"
    else
        echo "FAIL: Constant $const missing"
        EXIT_CODE=1
    fi
done

# Check constant values
check_const_value() {
    local name="$1" expected="$2"
    if grep -q "const ${name}:.*=.*${expected}" "$FILE"; then
        echo "PASS: $name = $expected"
    else
        echo "FAIL: $name should be $expected"
        EXIT_CODE=1
    fi
}

check_const_value FEEDBACK_FLOAT_DURATION "0.8"
check_const_value FEEDBACK_PULSE_DURATION "0.3"
check_const_value FEEDBACK_SHAKE_DURATION "0.2"
check_const_value BANNER_SLIDE_DURATION "0.3"
check_const_value BANNER_HOLD_DURATION "3.0"
check_const_value BUILD_MODE_TRANSITION "0.25"

# Check new methods exist and return Tween
check_method() {
    local name="$1"
    if grep -q "static func ${name}(" "$FILE"; then
        echo "PASS: Method $name exists"
    else
        echo "FAIL: Method $name missing"
        EXIT_CODE=1
        return
    fi
    if grep -A5 "static func ${name}(" "$FILE" | grep -qF -- "-> Tween"; then
        echo "PASS: Method $name returns Tween"
    else
        echo "FAIL: Method $name should return Tween"
        EXIT_CODE=1
    fi
}

check_method "shake"
check_method "pulse_scale"
check_method "flash_color"
check_method "fade_out"
check_method "stagger_fade_in"

# Check shake parameters match spec
if grep -A3 "static func shake(" "$FILE" | grep -q "duration: float"; then
    echo "PASS: shake() has duration parameter"
else
    echo "FAIL: shake() missing duration parameter"
    EXIT_CODE=1
fi

if grep -A3 "static func shake(" "$FILE" | grep -q "magnitude: float"; then
    echo "PASS: shake() has magnitude parameter"
else
    echo "FAIL: shake() missing magnitude parameter"
    EXIT_CODE=1
fi

# Check pulse_scale does scale punch (scale up then back to ONE)
if grep -A20 "static func pulse_scale(" "$FILE" | grep -q "Vector2.ONE"; then
    echo "PASS: pulse_scale() returns to Vector2.ONE"
else
    echo "FAIL: pulse_scale() should return scale to Vector2.ONE"
    EXIT_CODE=1
fi

# Check flash_color returns modulate to WHITE
if grep -A20 "static func flash_color(" "$FILE" | grep -q "Color.WHITE"; then
    echo "PASS: flash_color() returns to Color.WHITE"
else
    echo "FAIL: flash_color() should return modulate to Color.WHITE"
    EXIT_CODE=1
fi

# Check fade_out hides panel after fading
if grep -A20 "static func fade_out(" "$FILE" | grep -q "visible = false"; then
    echo "PASS: fade_out() hides panel on completion"
else
    echo "FAIL: fade_out() should set visible = false on completion"
    EXIT_CODE=1
fi

# Check stagger_fade_in accepts typed array
if grep -qF "nodes: Array[Control]" "$FILE"; then
    echo "PASS: stagger_fade_in() uses typed Array[Control]"
else
    echo "FAIL: stagger_fade_in() should use typed Array[Control]"
    EXIT_CODE=1
fi

# Check file stays under 300 lines
LINE_COUNT=$(wc -l < "$FILE" | tr -d ' ')
if [ "$LINE_COUNT" -le 300 ]; then
    echo "PASS: File is $LINE_COUNT lines (under 300 limit)"
else
    echo "FAIL: File is $LINE_COUNT lines (exceeds 300 limit)"
    EXIT_CODE=1
fi

# Verify existing methods still present
for method in kill_tween slide_open slide_close modal_open modal_close fade_in; do
    if grep -q "static func ${method}(" "$FILE"; then
        echo "PASS: Existing method $method preserved"
    else
        echo "FAIL: Existing method $method missing"
        EXIT_CODE=1
    fi
done

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "All ISSUE-022 checks passed."
else
    echo "Some ISSUE-022 checks failed."
fi

exit $EXIT_CODE
