#!/usr/bin/env bash
# Validate ISSUE-154: TradePanel UI — card trade offer display with accept/decline
set -euo pipefail

TRADE_PANEL="game/scripts/ui/trade_panel.gd"
TRADE_SCENE="game/scenes/ui/trade_panel.tscn"
EXIT_CODE=0

echo "=== ISSUE-154: TradePanel UI ==="

echo ""
echo "[File existence]"

if [ -f "$TRADE_PANEL" ]; then
    echo "PASS: trade_panel.gd exists at scripts/ui/"
else
    echo "FAIL: trade_panel.gd not found at $TRADE_PANEL"
    EXIT_CODE=1
fi

if [ -f "$TRADE_SCENE" ]; then
    echo "PASS: trade_panel.tscn exists"
else
    echo "FAIL: trade_panel.tscn not found"
    EXIT_CODE=1
fi

echo ""
echo "[Class and typing]"

if grep -q "class_name TradePanel" "$TRADE_PANEL"; then
    echo "PASS: class_name TradePanel declared"
else
    echo "FAIL: class_name TradePanel missing"
    EXIT_CODE=1
fi

if grep -q "extends PanelContainer" "$TRADE_PANEL"; then
    echo "PASS: extends PanelContainer"
else
    echo "FAIL: should extend PanelContainer"
    EXIT_CODE=1
fi

echo ""
echo "[Public API: show_trade]"

if grep -q "func show_trade(" "$TRADE_PANEL"; then
    echo "PASS: show_trade method exists"
else
    echo "FAIL: show_trade method missing"
    EXIT_CODE=1
fi

if grep -q "wanted_name: String" "$TRADE_PANEL"; then
    echo "PASS: wanted_name parameter typed"
else
    echo "FAIL: wanted_name parameter should be typed String"
    EXIT_CODE=1
fi

if grep -q "wanted_cond: String" "$TRADE_PANEL"; then
    echo "PASS: wanted_cond parameter typed"
else
    echo "FAIL: wanted_cond parameter should be typed String"
    EXIT_CODE=1
fi

if grep -q "wanted_val: float" "$TRADE_PANEL"; then
    echo "PASS: wanted_val parameter typed"
else
    echo "FAIL: wanted_val parameter should be typed float"
    EXIT_CODE=1
fi

echo ""
echo "[Public API: hide_trade and is_open]"

if grep -q "func hide_trade() -> void:" "$TRADE_PANEL"; then
    echo "PASS: hide_trade method exists with return type"
else
    echo "FAIL: hide_trade method missing or untyped"
    EXIT_CODE=1
fi

if grep -q "func is_open() -> bool:" "$TRADE_PANEL"; then
    echo "PASS: is_open method exists with return type"
else
    echo "FAIL: is_open method missing or untyped"
    EXIT_CODE=1
fi

echo ""
echo "[Signals]"

if grep -q "signal trade_accepted" "$TRADE_PANEL"; then
    echo "PASS: trade_accepted signal declared"
else
    echo "FAIL: trade_accepted signal missing"
    EXIT_CODE=1
fi

if grep -q "signal trade_declined" "$TRADE_PANEL"; then
    echo "PASS: trade_declined signal declared"
else
    echo "FAIL: trade_declined signal missing"
    EXIT_CODE=1
fi

if grep -q "trade_accepted.emit()" "$TRADE_PANEL"; then
    echo "PASS: trade_accepted emitted on accept"
else
    echo "FAIL: trade_accepted not emitted"
    EXIT_CODE=1
fi

if grep -q "trade_declined.emit()" "$TRADE_PANEL"; then
    echo "PASS: trade_declined emitted on decline"
else
    echo "FAIL: trade_declined not emitted"
    EXIT_CODE=1
fi

echo ""
echo "[Pending guard — double-click protection]"

if grep -q "_is_pending: bool" "$TRADE_PANEL"; then
    echo "PASS: _is_pending guard flag exists"
else
    echo "FAIL: _is_pending guard flag missing"
    EXIT_CODE=1
fi

if grep -q "_accept_button.disabled = pending" "$TRADE_PANEL"; then
    echo "PASS: accept button disabled when pending"
else
    echo "FAIL: accept button should be disabled when pending"
    EXIT_CODE=1
fi

if grep -q "_decline_button.disabled = pending" "$TRADE_PANEL"; then
    echo "PASS: decline button disabled when pending"
else
    echo "FAIL: decline button should be disabled when pending"
    EXIT_CODE=1
fi

echo ""
echo "[Fair-trade indicator]"

if grep -q "FAIR_TRADE_THRESHOLD" "$TRADE_PANEL"; then
    echo "PASS: fair-trade threshold constant exists"
else
    echo "FAIL: fair-trade threshold constant missing"
    EXIT_CODE=1
fi

if grep -q "get_positive_color" "$TRADE_PANEL"; then
    echo "PASS: uses positive (green) color for fair trade"
else
    echo "FAIL: should use positive color for fair trade"
    EXIT_CODE=1
fi

if grep -q "get_warning_color" "$TRADE_PANEL"; then
    echo "PASS: uses warning (amber) color for uneven trade"
else
    echo "FAIL: should use warning color for uneven trade"
    EXIT_CODE=1
fi

if grep -q "FairTradeIndicator" "$TRADE_SCENE"; then
    echo "PASS: FairTradeIndicator node in scene"
else
    echo "FAIL: FairTradeIndicator node missing from scene"
    EXIT_CODE=1
fi

echo ""
echo "[Slide animation from right]"

if grep -q "PanelAnimator.slide_in" "$TRADE_PANEL"; then
    echo "PASS: uses PanelAnimator.slide_in"
else
    echo "FAIL: should use PanelAnimator.slide_in"
    EXIT_CODE=1
fi

if grep -q "PanelAnimator.slide_out" "$TRADE_PANEL"; then
    echo "PASS: uses PanelAnimator.slide_out"
else
    echo "FAIL: should use PanelAnimator.slide_out"
    EXIT_CODE=1
fi

if grep -q "Vector2.RIGHT" "$TRADE_PANEL"; then
    echo "PASS: slides from right direction"
else
    echo "FAIL: should slide from right (Vector2.RIGHT)"
    EXIT_CODE=1
fi

echo ""
echo "[Scene layout]"

if grep -q "Card Trade Offer" "$TRADE_SCENE"; then
    echo "PASS: panel title is 'Card Trade Offer'"
else
    echo "FAIL: panel title should be 'Card Trade Offer'"
    EXIT_CODE=1
fi

if grep -q "scripts/ui/trade_panel.gd" "$TRADE_SCENE"; then
    echo "PASS: scene references scripts/ui/trade_panel.gd"
else
    echo "FAIL: scene should reference scripts/ui/trade_panel.gd"
    EXIT_CODE=1
fi

echo ""
echo "[Panel opened/closed wiring]"

if grep -q 'EventBus.panel_opened.connect' "$TRADE_PANEL"; then
    echo "PASS: connects to EventBus.panel_opened"
else
    echo "FAIL: should connect to EventBus.panel_opened"
    EXIT_CODE=1
fi

if grep -q 'PANEL_NAME.*"trade"' "$TRADE_PANEL" || grep -q "PANEL_NAME.*trade" "$TRADE_PANEL"; then
    echo "PASS: PANEL_NAME constant set to trade"
else
    echo "FAIL: PANEL_NAME should be set to trade"
    EXIT_CODE=1
fi

echo ""
echo "=== Results ==="
if [ $EXIT_CODE -eq 0 ]; then
    echo "All ISSUE-154 checks passed."
else
    echo "Some ISSUE-154 checks failed."
fi

exit $EXIT_CODE
