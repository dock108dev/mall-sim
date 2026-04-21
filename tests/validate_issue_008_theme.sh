#!/usr/bin/env bash
# Validation for ISSUE-008: Phase 2 — mallcore_theme.tres, global theme, visual grammar
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
check() { if eval "$1" 2>/dev/null; then pass "$2"; else fail "$2"; fi; }

echo "=== ISSUE-008 (Phase 2): mallcore_theme.tres and visual grammar ==="
echo ""

THEME="$ROOT/game/themes/mallcore_theme.tres"
PROJECT="$ROOT/project.godot"
DOC="$ROOT/docs/style/visual-grammar.md"
CONSTANTS="$ROOT/game/scripts/ui/ui_theme_constants.gd"

# AC1: mallcore_theme.tres exists with all font-size tokens
echo "[AC1] mallcore_theme.tres exists with font-size tokens"
check "[ -f '$THEME' ]" "game/themes/mallcore_theme.tres exists"
check "grep -q 'TitleLabel/font_sizes/font_size = 32' '$THEME'" "TitleLabel font_size = 32 (h1)"
check "grep -q 'HeaderLabel/font_sizes/font_size = 24' '$THEME'" "HeaderLabel font_size = 24 (h2)"
check "grep -q 'Label/font_sizes/font_size = 18' '$THEME'" "Label font_size = 18 (body)"
check "grep -q 'TooltipLabel/font_sizes/font_size = 14' '$THEME'" "TooltipLabel font_size = 14 (caption)"
check "grep -q 'CaptionLabel/base_type' '$THEME'" "CaptionLabel named type declared"

# AC2: Theme set as project-wide default in project.godot
echo ""
echo "[AC2] Theme set as project-wide default"
check "grep -q 'theme/custom.*mallcore_theme.tres' '$PROJECT'" "project.godot references mallcore_theme.tres"

# AC3: No per-scene StyleBoxFlat overrides in .tscn files
echo ""
echo "[AC3] No ad-hoc StyleBoxFlat in scene files"
SCENE_HITS=$(grep -rl 'StyleBoxFlat' "$ROOT/game/scenes" 2>/dev/null | wc -l | tr -d '[:space:]' || echo 0)
check "[ \"$SCENE_HITS\" -eq 0 ]" "Zero .tscn files contain inline StyleBoxFlat"

# AC4: Palette tokens embedded in mallcore_theme.tres
echo ""
echo "[AC4] Palette tokens in mallcore_theme.tres"
check "grep -q 'Palette/colors/panel_surface' '$THEME'" "panel_surface token present"
check "grep -q 'Palette/colors/text_primary' '$THEME'" "text_primary token present"
check "grep -q 'Palette/colors/accent_interact' '$THEME'" "accent_interact token present"
check "grep -q 'StoreAccents/colors/retro_games' '$THEME'" "store accent tokens present"

# UIThemeConstants font size constants updated
echo ""
echo "[AC4b] UIThemeConstants font size constants"
check "grep -q 'FONT_SIZE_H1.*32' '$CONSTANTS'" "FONT_SIZE_H1 = 32"
check "grep -q 'FONT_SIZE_H2.*24' '$CONSTANTS'" "FONT_SIZE_H2 = 24"
check "grep -q 'FONT_SIZE_BODY.*18' '$CONSTANTS'" "FONT_SIZE_BODY = 18"
check "grep -q 'FONT_SIZE_CAPTION.*14' '$CONSTANTS'" "FONT_SIZE_CAPTION = 14"

# AC5: docs/style/visual-grammar.md documents all 5 interactable states
echo ""
echo "[AC5] visual-grammar.md documents five interactable states"
check "[ -f '$DOC' ]" "docs/style/visual-grammar.md exists"
check "grep -qi 'idle' '$DOC'" "Idle state documented"
check "grep -qi 'hover' '$DOC'" "Hover state documented"
check "grep -qi 'active' '$DOC'" "Active state documented"
check "grep -qi 'disabled' '$DOC'" "Disabled state documented"
check "grep -qi 'warning' '$DOC'" "Warning state documented"
check "grep -q 'h1.*32' '$DOC'" "Typography scale: h1=32 documented"
check "grep -q 'h2.*24' '$DOC'" "Typography scale: h2=24 documented"
check "grep -q 'body.*18' '$DOC'" "Typography scale: body=18 documented"
check "grep -q 'caption.*14' '$DOC'" "Typography scale: caption=14 documented"
check "grep -q 'mallcore_theme.tres' '$DOC'" "Doc references mallcore_theme.tres"

echo ""
echo "=== Results: $PASS/$((PASS+FAIL)) passed, $FAIL failed ==="
echo ""
if [ $FAIL -eq 0 ]; then
    echo "All ISSUE-008 (Phase 2 theme) acceptance criteria validated."
else
    echo "Some checks failed."
    exit 1
fi
