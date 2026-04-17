#!/usr/bin/env bash
# Validate ISSUE-025: reputation HUD flash and arrow animation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HUD="$ROOT/game/scenes/ui/hud.gd"
TEST="$ROOT/tests/gut/test_hud.gd"

pass() {
	echo "PASS: $1"
}

fail() {
	echo "FAIL: $1"
	exit 1
}

grep -q 'EventBus.reputation_changed.connect(_on_reputation_changed)' "$HUD" \
	&& pass "HUD connects EventBus.reputation_changed" \
	|| fail "HUD must connect EventBus.reputation_changed"

grep -q 'PanelAnimator.kill_tween(_rep_arrow_tween)' "$HUD" \
	&& pass "HUD kills existing reputation tween" \
	|| fail "HUD must kill existing reputation tween"

grep -q 'const _REP_ARROW_FADE_IN: float = 0.1' "$HUD" \
	&& pass "reputation flash-in is 0.1s" \
	|| fail "reputation flash-in must be 0.1s"

grep -q 'const _REP_ARROW_HOLD: float = 1.0' "$HUD" \
	&& pass "reputation arrow hold is 1.0s" \
	|| fail "reputation arrow hold must be 1.0s"

grep -q 'const _REP_ARROW_FADE_OUT: float = 0.4' "$HUD" \
	&& pass "reputation fade-out is 0.4s" \
	|| fail "reputation fade-out must be 0.4s"

grep -q 'UIThemeConstants.get_positive_color() if increased' "$HUD" \
	&& pass "increase uses positive color" \
	|| fail "increase must use positive color"

grep -q 'UIThemeConstants.get_negative_color()' "$HUD" \
	&& pass "decrease uses negative color" \
	|| fail "decrease must use negative color"

grep -q 'var arrow: String = " \\u25B2" if increased else " \\u25BC"' "$HUD" \
	&& pass "directional arrow text is appended" \
	|| fail "HUD must append up/down arrows"

grep -q '_reputation_label.text = label_text$' "$HUD" \
	&& pass "arrow text is removed after hold" \
	|| fail "HUD must remove arrow text after hold"

grep -q 'UIThemeConstants.BODY_FONT_COLOR' "$HUD" \
	&& pass "fade returns to body font color" \
	|| fail "fade must return to BODY_FONT_COLOR"

grep -q 'test_reputation_arrow_removed_after_hold' "$TEST" \
	&& grep -q 'test_reputation_color_fades_to_body_font_color' "$TEST" \
	&& pass "GUT coverage added for arrow removal and body color fade" \
	|| fail "GUT coverage missing for ISSUE-025"
