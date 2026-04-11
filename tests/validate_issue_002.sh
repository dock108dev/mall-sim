#!/usr/bin/env bash
# Validates ISSUE-002: Complete localization infrastructure with language switching
# Checks acceptance criteria via static analysis when Godot is unavailable.
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-002: Complete localization infrastructure ==="
echo ""

# --- AC1: project.godot configured to import CSV translations ---
echo "[AC1] project.godot configured to import CSV translations"

if grep -q 'locale/translations' "$ROOT/project.godot"; then
    pass "locale/translations key exists in project.godot"
else
    fail "locale/translations key missing from project.godot"
fi

if grep -q 'translations\.en\.csv' "$ROOT/project.godot"; then
    pass "English CSV registered in project.godot"
else
    fail "English CSV not registered in project.godot"
fi

if grep -q 'translations\.es\.csv' "$ROOT/project.godot"; then
    pass "Spanish CSV registered in project.godot"
else
    fail "Spanish CSV not registered in project.godot"
fi

# --- AC2: TranslationServer loads en translations — 150+ keys resolve ---
echo ""
echo "[AC2] English translations CSV has 150+ keys"

EN_CSV="$ROOT/game/assets/localization/translations.en.csv"
if [ -f "$EN_CSV" ]; then
    # Count non-empty, non-header lines
    KEY_COUNT=$(tail -n +2 "$EN_CSV" | grep -c '.' || true)
    if [ "$KEY_COUNT" -ge 150 ]; then
        pass "English CSV has $KEY_COUNT keys (>= 150)"
    else
        fail "English CSV has only $KEY_COUNT keys (need >= 150)"
    fi
else
    fail "translations.en.csv not found"
fi

# Verify TranslationServer is used in settings.gd
if grep -q 'TranslationServer\.set_locale' "$ROOT/game/autoload/settings.gd"; then
    pass "TranslationServer.set_locale() called in settings.gd"
else
    fail "TranslationServer.set_locale() not called in settings.gd"
fi

# --- AC3: Settings panel has language dropdown (English + placeholder language) ---
echo ""
echo "[AC3] Settings panel has language dropdown with multiple locales"

if grep -q '_locale_option' "$ROOT/game/scenes/ui/settings_panel.gd"; then
    pass "Locale option button exists in settings_panel.gd"
else
    fail "Locale option button missing from settings_panel.gd"
fi

if grep -q '_populate_locales' "$ROOT/game/scenes/ui/settings_panel.gd"; then
    pass "_populate_locales() method exists"
else
    fail "_populate_locales() method missing"
fi

# Check SUPPORTED_LOCALES has at least 2 entries
LOCALE_COUNT=$(grep -c '"code"' "$ROOT/game/autoload/settings.gd" || true)
if [ "$LOCALE_COUNT" -ge 2 ]; then
    pass "SUPPORTED_LOCALES has $LOCALE_COUNT entries (>= 2)"
else
    fail "SUPPORTED_LOCALES has only $LOCALE_COUNT entry (need >= 2)"
fi

if grep -q '"es"' "$ROOT/game/autoload/settings.gd"; then
    pass "Spanish locale code 'es' found in SUPPORTED_LOCALES"
else
    fail "Spanish locale code 'es' not found in SUPPORTED_LOCALES"
fi

# --- AC4: Language selection persists across sessions via settings.cfg ---
echo ""
echo "[AC4] Language selection persists via settings.cfg"

if grep -q 'config\.set_value.*"locale".*"language".*locale' \
    "$ROOT/game/autoload/settings.gd"; then
    pass "Locale saved to settings.cfg"
else
    fail "Locale not saved to settings.cfg"
fi

if grep -q 'config\.get_value.*"locale".*"language"' \
    "$ROOT/game/autoload/settings.gd"; then
    pass "Locale loaded from settings.cfg"
else
    fail "Locale not loaded from settings.cfg"
fi

# --- AC5: Switching language updates visible UI text in real-time ---
echo ""
echo "[AC5] Real-time locale switching support"

if grep -q 'locale_changed' "$ROOT/game/autoload/event_bus.gd"; then
    pass "locale_changed signal declared in EventBus"
else
    fail "locale_changed signal missing from EventBus"
fi

if grep -q 'locale_changed\.emit' "$ROOT/game/autoload/settings.gd"; then
    pass "locale_changed signal emitted in settings.gd"
else
    fail "locale_changed signal not emitted in settings.gd"
fi

if grep -q 'locale_changed\.connect\|_on_locale_changed' \
    "$ROOT/game/scenes/ui/hud.gd"; then
    pass "HUD listens for locale changes"
else
    fail "HUD does not listen for locale changes"
fi

if grep -q 'locale_changed\.connect\|_on_locale_changed' \
    "$ROOT/game/scenes/ui/settings_panel.gd"; then
    pass "Settings panel listens for locale changes"
else
    fail "Settings panel does not listen for locale changes"
fi

# --- AC6: Template translations.es.csv exists with same keys ---
echo ""
echo "[AC6] Spanish template CSV exists with matching keys"

ES_CSV="$ROOT/game/assets/localization/translations.es.csv"
if [ -f "$ES_CSV" ]; then
    pass "translations.es.csv exists"
else
    fail "translations.es.csv not found"
    echo ""
    TOTAL=$((PASS + FAIL))
    echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
    exit 1
fi

# Check header has 'es' column
if head -1 "$ES_CSV" | grep -q 'es'; then
    pass "Spanish CSV has 'es' column header"
else
    fail "Spanish CSV missing 'es' column header"
fi

# Count keys in Spanish CSV
ES_KEY_COUNT=$(tail -n +2 "$ES_CSV" | grep -c '.' || true)
if [ "$ES_KEY_COUNT" -ge 150 ]; then
    pass "Spanish CSV has $ES_KEY_COUNT keys (>= 150)"
else
    fail "Spanish CSV has only $ES_KEY_COUNT keys (need >= 150)"
fi

# Verify key sets match between en and es CSVs
EN_KEYS=$(tail -n +2 "$EN_CSV" | cut -d',' -f1 | sort)
ES_KEYS=$(tail -n +2 "$ES_CSV" | cut -d',' -f1 | sort)
MISSING_KEYS=$(comm -23 <(echo "$EN_KEYS") <(echo "$ES_KEYS") | head -5)
if [ -z "$MISSING_KEYS" ]; then
    pass "All English keys present in Spanish CSV"
else
    fail "Spanish CSV missing keys: $(echo "$MISSING_KEYS" | tr '\n' ', ')"
fi

# --- Summary ---
echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

echo ""
echo "All ISSUE-002 acceptance criteria validated."
exit 0
