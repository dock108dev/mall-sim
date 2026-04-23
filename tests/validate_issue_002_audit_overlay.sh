#!/usr/bin/env bash
# Validates ISSUE-002: F3 debug overlay (scene/camera/input/player/store + AuditLog tail)
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OVERLAY="$ROOT/game/autoload/audit_overlay.gd"
PROJECT="$ROOT/project.godot"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-002: AuditOverlay F3 debug HUD ==="

# Autoload registered
if grep -q '^AuditOverlay="\*res://game/autoload/audit_overlay\.gd"' "$PROJECT"; then
	pass "AuditOverlay autoload registered"
else
	fail "AuditOverlay autoload not registered"
fi

# F3 binding present
if grep -q 'physical_keycode":4194334' "$PROJECT"; then
	pass "toggle_debug bound to F3 (4194334)"
else
	fail "toggle_debug F3 binding missing"
fi

# Source exists
if [ -f "$OVERLAY" ]; then
	pass "audit_overlay.gd exists"
else
	fail "audit_overlay.gd missing"
	echo ""
	echo "=== Results: $PASS passed, $FAIL failed ==="
	exit 1
fi

# Hidden by default + debug-only
if grep -q 'visible = false' "$OVERLAY"; then
	pass "overlay hidden by default"
else
	fail "overlay not hidden by default"
fi

if grep -q 'OS.is_debug_build()' "$OVERLAY"; then
	pass "overlay stripped in release builds"
else
	fail "overlay not gated to debug builds"
fi

# Renders above ModalStack (high CanvasLayer)
if grep -qE 'layer = (12[0-9]|1[3-9][0-9]|[2-9][0-9]{2,})' "$OVERLAY"; then
	pass "overlay layer > 100 (above modals)"
else
	fail "overlay layer not above modal layers"
fi

# Required field labels
for field in _label_scene_path _label_camera_path _label_input_focus _label_player_path _label_store_id; do
	if grep -q "$field" "$OVERLAY"; then
		pass "$field declared"
	else
		fail "$field missing"
	fi
done

# Toggle handler + input not stolen for non-toggle keys
if grep -q 'is_action_pressed(&"toggle_debug")' "$OVERLAY"; then
	pass "F3 toggle handler present"
else
	fail "F3 toggle handler missing"
fi

# Last 10 audit entries via AuditLog.recent
if grep -q 'AuditLog.recent' "$OVERLAY"; then
	pass "overlay reads AuditLog.recent()"
else
	fail "overlay does not read AuditLog.recent()"
fi

if grep -q '_ENTRY_ROWS: int = 10' "$OVERLAY"; then
	pass "overlay shows 10 recent entries"
else
	fail "overlay row count != 10"
fi

# No bare hex color literals in overlay source
if grep -qE '"#[0-9a-fA-F]{6,8}"' "$OVERLAY"; then
	fail "bare hex color string found in overlay"
else
	pass "no bare hex colors in overlay source"
fi

# GUT test exists
if [ -f "$ROOT/tests/gut/test_audit_overlay_issue_002.gd" ]; then
	pass "GUT test test_audit_overlay_issue_002.gd present"
else
	fail "GUT test test_audit_overlay_issue_002.gd missing"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
