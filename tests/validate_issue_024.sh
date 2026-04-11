#!/usr/bin/env bash
# Validate ISSUE-024: Modal animations on 7 dialog panels
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXIT_CODE=0

echo "=== ISSUE-024: Modal Animations on 7 Dialog Panels ==="

PANELS=(
    "game/scenes/ui/haggle_panel.gd"
    "game/scenes/ui/trade_panel.gd"
    "game/scenes/ui/save_load_panel.gd"
    "game/scenes/ui/settings_panel.gd"
    "game/scenes/ui/authentication_dialog.gd"
    "game/scenes/ui/refurbishment_dialog.gd"
    "game/scenes/ui/pack_opening_panel.gd"
)

for panel in "${PANELS[@]}"; do
    FILE="$ROOT/$panel"
    NAME=$(basename "$panel" .gd)

    if [ ! -f "$FILE" ]; then
        echo "FAIL: $panel not found"
        EXIT_CODE=1
        continue
    fi

    # Check _anim_tween variable
    if grep -q "var _anim_tween: Tween" "$FILE"; then
        echo "PASS: $NAME has _anim_tween: Tween"
    else
        echo "FAIL: $NAME missing _anim_tween: Tween"
        EXIT_CODE=1
    fi

    # Check PanelAnimator.kill_tween usage
    if grep -q "PanelAnimator.kill_tween(_anim_tween)" "$FILE"; then
        echo "PASS: $NAME calls PanelAnimator.kill_tween()"
    else
        echo "FAIL: $NAME missing PanelAnimator.kill_tween() call"
        EXIT_CODE=1
    fi

    # Check PanelAnimator.modal_open usage
    if grep -q "PanelAnimator.modal_open(" "$FILE"; then
        echo "PASS: $NAME calls PanelAnimator.modal_open()"
    else
        echo "FAIL: $NAME missing PanelAnimator.modal_open() call"
        EXIT_CODE=1
    fi

    # Check PanelAnimator.modal_close usage
    if grep -q "PanelAnimator.modal_close(" "$FILE"; then
        echo "PASS: $NAME calls PanelAnimator.modal_close()"
    else
        echo "FAIL: $NAME missing PanelAnimator.modal_close() call"
        EXIT_CODE=1
    fi

    # Check kill_tween is called at least twice (before open AND close)
    KILL_COUNT=$(grep -c "PanelAnimator.kill_tween(_anim_tween)" "$FILE" || true)
    if [ "$KILL_COUNT" -ge 2 ]; then
        echo "PASS: $NAME calls kill_tween before both open and close ($KILL_COUNT calls)"
    else
        echo "FAIL: $NAME should call kill_tween before both open and close (found $KILL_COUNT)"
        EXIT_CODE=1
    fi

    # Check no raw 'visible = true' in open methods (should use modal_open)
    # Exclude _ready() which legitimately sets visible = false
    VISIBLE_TRUE=$(grep -c "visible = true" "$FILE" || true)
    if [ "$VISIBLE_TRUE" -eq 0 ]; then
        echo "PASS: $NAME has no raw 'visible = true' (uses modal_open)"
    else
        echo "WARN: $NAME has $VISIBLE_TRUE 'visible = true' statements (verify not in open path)"
    fi
done

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "All ISSUE-024 checks passed."
else
    echo "Some ISSUE-024 checks failed."
fi

exit $EXIT_CODE
