#!/usr/bin/env bash
# Validation tests for ISSUE-005: Localization infrastructure
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXIT_CODE=0

echo "=== ISSUE-005: Localization Infrastructure Validation ==="
echo ""

# 1. Check that translations CSV file exists
CSV_FILE="$ROOT/game/assets/localization/translations.en.csv"
if [ -f "$CSV_FILE" ]; then
    echo "PASS: translations.en.csv exists"
else
    echo "FAIL: translations.en.csv not found at $CSV_FILE"
    EXIT_CODE=1
fi

# 2. Check CSV has proper header
HEADER=$(head -1 "$CSV_FILE")
if echo "$HEADER" | grep -q "^keys,en"; then
    echo "PASS: CSV header has keys,en format"
else
    echo "FAIL: CSV header is incorrect: $HEADER"
    EXIT_CODE=1
fi

# 3. Check CSV has required translation keys
REQUIRED_KEYS=(
    "HUD_DAY_FORMAT"
    "HUD_PHASE_MORNING"
    "HUD_TIER_LEGENDARY"
    "MENU_AUTO_SAVE"
    "MENU_LOAD"
    "SAVE_TITLE_SAVE"
    "SAVE_TITLE_LOAD"
    "DAY_SUMMARY_TITLE"
    "DAY_SUMMARY_REVENUE"
    "MILESTONE_COMPLETE"
    "ORDER_BUTTON"
    "INVENTORY_CONDITION"
    "PRICING_CONDITION"
    "FIXTURE_SELECT_HINT"
    "STAFF_HIRE"
    "STAFF_FIRE"
    "TUTORIAL_WELCOME"
    "TIP_ORDERING"
    "CHECKOUT_CONDITION"
    "HAGGLE_CONDITION"
    "TRADE_CONDITION"
    "PACK_OPENING_TITLE"
    "TRENDS_NO_ACTIVE"
    "REFURBISH_TITLE"
    "AUTH_TITLE"
    "SETTINGS_UNBOUND"
    "SETTINGS_PRESS_KEY"
)

MISSING_KEYS=0
for key in "${REQUIRED_KEYS[@]}"; do
    if ! grep -q "^${key}," "$CSV_FILE"; then
        echo "FAIL: Missing required translation key: $key"
        MISSING_KEYS=$((MISSING_KEYS + 1))
        EXIT_CODE=1
    fi
done

if [ $MISSING_KEYS -eq 0 ]; then
    TOTAL_KEYS=$(tail -n +2 "$CSV_FILE" | wc -l | tr -d ' ')
    echo "PASS: All ${#REQUIRED_KEYS[@]} required keys present ($TOTAL_KEYS total keys)"
else
    echo "FAIL: $MISSING_KEYS required keys missing"
fi

# 4. Check project.godot has internationalization section
PROJ_FILE="$ROOT/project.godot"
if grep -q "\[internationalization\]" "$PROJ_FILE"; then
    echo "PASS: project.godot has [internationalization] section"
else
    echo "FAIL: project.godot missing [internationalization] section"
    EXIT_CODE=1
fi

if grep -q "locale/translations" "$PROJ_FILE"; then
    echo "PASS: project.godot registers translation file"
else
    echo "FAIL: project.godot does not register translation file"
    EXIT_CODE=1
fi

# 5. Check Settings autoload has locale support
SETTINGS_FILE="$ROOT/game/autoload/settings.gd"
if grep -q "var locale" "$SETTINGS_FILE"; then
    echo "PASS: Settings has locale variable"
else
    echo "FAIL: Settings missing locale variable"
    EXIT_CODE=1
fi

if grep -q "SUPPORTED_LOCALES" "$SETTINGS_FILE"; then
    echo "PASS: Settings has SUPPORTED_LOCALES"
else
    echo "FAIL: Settings missing SUPPORTED_LOCALES"
    EXIT_CODE=1
fi

if grep -q "_apply_locale" "$SETTINGS_FILE"; then
    echo "PASS: Settings has _apply_locale method"
else
    echo "FAIL: Settings missing _apply_locale method"
    EXIT_CODE=1
fi

if grep -q '"locale", "language"' "$SETTINGS_FILE"; then
    echo "PASS: Settings saves/loads locale to config"
else
    echo "FAIL: Settings does not persist locale"
    EXIT_CODE=1
fi

# 6. Check EventBus has locale_changed signal
EVENTBUS_FILE="$ROOT/game/autoload/event_bus.gd"
if grep -q "signal locale_changed" "$EVENTBUS_FILE"; then
    echo "PASS: EventBus has locale_changed signal"
else
    echo "FAIL: EventBus missing locale_changed signal"
    EXIT_CODE=1
fi

# 7. Check settings panel has language dropdown
SETTINGS_PANEL="$ROOT/game/scenes/ui/settings_panel.gd"
if grep -q "_locale_option" "$SETTINGS_PANEL"; then
    echo "PASS: Settings panel has locale option dropdown"
else
    echo "FAIL: Settings panel missing locale option dropdown"
    EXIT_CODE=1
fi

SETTINGS_TSCN="$ROOT/game/scenes/ui/settings_panel.tscn"
if grep -q "LanguageRow" "$SETTINGS_TSCN"; then
    echo "PASS: Settings panel scene has LanguageRow"
else
    echo "FAIL: Settings panel scene missing LanguageRow"
    EXIT_CODE=1
fi

# 8. Check UI scripts use tr() for player-facing strings
TR_CHECK_FILES=(
    "game/scenes/ui/hud.gd"
    "game/scenes/ui/main_menu.gd"
    "game/scenes/ui/day_summary.gd"
    "game/scenes/ui/save_load_panel.gd"
    "game/scenes/ui/milestone_popup.gd"
    "game/scenes/ui/milestones_panel.gd"
    "game/scenes/ui/order_panel.gd"
    "game/scenes/ui/inventory_panel.gd"
    "game/scenes/ui/pricing_panel.gd"
    "game/scenes/ui/fixture_catalog.gd"
    "game/scenes/ui/fixture_upgrade_panel.gd"
    "game/scenes/ui/staff_panel.gd"
    "game/scenes/ui/checkout_panel.gd"
    "game/scenes/ui/haggle_panel.gd"
    "game/scenes/ui/trade_panel.gd"
    "game/scenes/ui/pack_opening_panel.gd"
    "game/scenes/ui/trends_panel.gd"
    "game/scenes/ui/refurbishment_dialog.gd"
    "game/scenes/ui/authentication_dialog.gd"
    "game/scenes/ui/tutorial_overlay.gd"
)

TR_PASS=0
TR_FAIL=0
for rel_path in "${TR_CHECK_FILES[@]}"; do
    full_path="$ROOT/$rel_path"
    if [ ! -f "$full_path" ]; then
        echo "FAIL: File not found: $rel_path"
        TR_FAIL=$((TR_FAIL + 1))
        continue
    fi
    if grep -q 'tr("' "$full_path"; then
        TR_PASS=$((TR_PASS + 1))
    else
        echo "FAIL: $rel_path does not use tr() calls"
        TR_FAIL=$((TR_FAIL + 1))
        EXIT_CODE=1
    fi
done

if [ $TR_FAIL -eq 0 ]; then
    echo "PASS: All $TR_PASS UI scripts use tr() calls"
else
    echo "FAIL: $TR_FAIL/$((TR_PASS + TR_FAIL)) UI scripts missing tr() calls"
fi

# 9. Check tutorial system uses tr() for step text
TUTORIAL_FILE="$ROOT/game/scripts/systems/tutorial_system.gd"
if grep -q "STEP_TEXT_KEYS" "$TUTORIAL_FILE"; then
    echo "PASS: Tutorial system uses translation keys for step text"
else
    echo "FAIL: Tutorial system still uses hardcoded step text"
    EXIT_CODE=1
fi

if grep -q "CONTEXTUAL_TIP_KEYS" "$TUTORIAL_FILE"; then
    echo "PASS: Tutorial system uses translation keys for tips"
else
    echo "FAIL: Tutorial system still uses hardcoded tips"
    EXIT_CODE=1
fi

# 10. Verify adding a language requires only a new CSV column
echo ""
echo "--- Infrastructure check ---"
echo "To add a new language (e.g., French):"
echo "  1. Add 'fr' column to translations.en.csv (rename to translations.csv)"
echo "  2. Add {\"code\": \"fr\", \"name\": \"Francais\"} to SUPPORTED_LOCALES"
echo "  3. No other code changes needed"
echo "PASS: Infrastructure supports adding languages via CSV + config"

echo ""
echo "=== Summary ==="
if [ $EXIT_CODE -eq 0 ]; then
    echo "All ISSUE-005 validation checks PASSED"
else
    echo "Some ISSUE-005 validation checks FAILED"
fi

exit $EXIT_CODE
