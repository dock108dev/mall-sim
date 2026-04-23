#!/usr/bin/env bash
# Validates ISSUE-014 (.aidlc/issues): Boot → MainMenu → New Game →
# MallHub routes via SceneRouter and emits the entry-flow audit checkpoints.
#
# Note: tests/validate_issue_014.sh exists for an unrelated legacy issue
# (Phase-12 CI/Export Readiness). This script covers the aidlc-tracked
# ISSUE-014 specifically.
set -u

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

BOOT="$ROOT/game/scripts/core/boot.gd"
MAIN_MENU="$ROOT/game/scenes/ui/main_menu.gd"
MALL_HUB="$ROOT/game/scenes/mall/mall_hub.gd"
GAME_MANAGER="$ROOT/game/autoload/game_manager.gd"
REQUIRED="$ROOT/tests/audit_required_checkpoints.txt"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-014 (aidlc): Boot → MainMenu → New Game → MallHub ==="

# AC1: boot.gd emits boot_scene_ready and routes to main_menu via GameManager
if grep -q 'pass_check(&"boot_scene_ready"' "$BOOT"; then
	pass "boot.gd emits AuditLog boot_scene_ready"
else
	fail "boot.gd missing AuditLog.pass_check(&\"boot_scene_ready\", ...)"
fi

if grep -q '_transition_to_main_menu' "$BOOT" \
	&& grep -q 'GameManager.transition_to' "$BOOT"; then
	pass "boot.gd routes to main_menu via GameManager.transition_to"
else
	fail "boot.gd missing GameManager.transition_to(MAIN_MENU) handoff"
fi

# AC2: MainMenu has New Game button wired to start_new_game (no direct
# change_scene_to_file calls).
if grep -q '_on_play_pressed' "$MAIN_MENU" \
	&& grep -q '_start_new_game' "$MAIN_MENU"; then
	pass "main_menu.gd: New Game (PlayButton) → _start_new_game"
else
	fail "main_menu.gd missing _on_play_pressed → _start_new_game wiring"
fi

if grep -q 'GameManager.start_new_game' "$MAIN_MENU"; then
	pass "main_menu.gd routes New Game through GameManager.start_new_game"
else
	fail "main_menu.gd missing GameManager.start_new_game() call"
fi

# AC3: GameManager.begin_new_run() exists, sets day=1, runs before scene swap
if grep -q 'func begin_new_run' "$GAME_MANAGER"; then
	pass "GameManager.begin_new_run() defined"
else
	fail "GameManager.begin_new_run() missing"
fi

if grep -A 20 'func begin_new_run' "$GAME_MANAGER" \
	| grep -q 'set_current_day(1)'; then
	pass "begin_new_run() sets day to 1"
else
	fail "begin_new_run() does not set day to 1"
fi

if grep -A 30 'func begin_new_run' "$GAME_MANAGER" \
	| tr -d '[:space:]' | grep -q 'pass_check(&"new_game_clicked"'; then
	pass "begin_new_run() emits AuditLog new_game_clicked"
else
	fail "begin_new_run() missing AuditLog.pass_check(&\"new_game_clicked\", ...)"
fi

# Verify begin_new_run is invoked before the scene change in start_new_game
if awk '
	/^func start_new_game/ { in_fn = 1; next }
	in_fn && /^func / { exit }
	in_fn && /begin_new_run/ { seen = 1 }
	in_fn && /change_scene\(/ && seen { print "OK"; exit }
' "$GAME_MANAGER" | grep -q OK; then
	pass "start_new_game() calls begin_new_run() before change_scene()"
else
	fail "start_new_game() does not call begin_new_run() before change_scene()"
fi

# AC4: AuditLog emissions for the chain
if grep -q 'pass_check(&"main_menu_ready"' "$MAIN_MENU"; then
	pass "main_menu.gd emits AuditLog main_menu_ready"
else
	fail "main_menu.gd missing AuditLog.pass_check(&\"main_menu_ready\", ...)"
fi

if grep -q 'pass_check(&"mall_hub_ready"' "$MALL_HUB"; then
	pass "mall_hub.gd emits AuditLog mall_hub_ready"
else
	fail "mall_hub.gd missing AuditLog.pass_check(&\"mall_hub_ready\", ...)"
fi

# Required-checkpoint manifest registers new_game_clicked
if grep -Eq '^new_game_clicked\b' "$REQUIRED"; then
	pass "audit_required_checkpoints.txt lists new_game_clicked"
else
	fail "new_game_clicked not registered in audit_required_checkpoints.txt"
fi

# AC5: No scene in this chain calls change_scene_to_file / _packed directly.
LEAKS=0
for f in "$BOOT" "$MAIN_MENU" "$MALL_HUB"; do
	if grep -E 'get_tree\(\)\.change_scene_to_(file|packed)' "$f" >/dev/null 2>&1; then
		fail "$(basename "$f") calls get_tree().change_scene_to_* directly"
		LEAKS=$((LEAKS + 1))
	fi
done
if [ "$LEAKS" -eq 0 ]; then
	pass "no direct change_scene_to_file/_packed in entry-chain scenes"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
