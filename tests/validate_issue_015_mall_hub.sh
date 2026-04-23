#!/usr/bin/env bash
# Validates ISSUE-015 (.aidlc/issues): MallHub scene contains a clickable
# Sneaker Citadel tile that invokes StoreDirector.enter_store(&"sneaker_citadel")
# directly (NOT SceneRouter — DESIGN.md §2.1 designates the director as the
# sole owner of the store lifecycle), pushes the mall_hub InputFocus context,
# asserts CameraAuthority single-active, and shows the fail card on FAIL.
#
# Note: tests/validate_issue_015.sh exists for an unrelated legacy issue
# (Phase-12 gameplay feedback animations). This script covers the
# aidlc-tracked ISSUE-015 specifically.
set -u

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

HUB_GD="$ROOT/game/scenes/mall/mall_hub.gd"
HUB_TSCN="$ROOT/game/scenes/mall/mall_hub.tscn"
TEST="$ROOT/tests/gut/test_mall_hub_issue_015.gd"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-015 (aidlc): MallHub Sneaker Citadel tile ==="

# AC1: tile exists in the scene with the expected unique-name node and label.
if grep -q '^\[node name="SneakerCitadelTile" type="Button"' "$HUB_TSCN"; then
	pass "mall_hub.tscn declares SneakerCitadelTile Button node"
else
	fail "mall_hub.tscn missing SneakerCitadelTile Button node"
fi

if grep -A 12 '^\[node name="SneakerCitadelTile" type="Button"' "$HUB_TSCN" \
	| grep -q 'unique_name_in_owner = true'; then
	pass "SneakerCitadelTile is unique-name addressable (%SneakerCitadelTile)"
else
	fail "SneakerCitadelTile must set unique_name_in_owner = true"
fi

if grep -A 12 '^\[node name="SneakerCitadelTile" type="Button"' "$HUB_TSCN" \
	| grep -q 'text = "Sneaker Citadel"'; then
	pass "SneakerCitadelTile label is 'Sneaker Citadel'"
else
	fail "SneakerCitadelTile must display text 'Sneaker Citadel'"
fi

if grep -A 12 '^\[node name="SneakerCitadelTile" type="Button"' "$HUB_TSCN" \
	| grep -q 'focus_mode = 2'; then
	pass "SneakerCitadelTile is keyboard-focusable (focus_mode = 2 = ALL)"
else
	fail "SneakerCitadelTile must set focus_mode = 2 for keyboard activation"
fi

# AC2: activation invokes StoreDirector.enter_store with sneaker_citadel id —
# NOT SceneRouter directly. DESIGN.md §2.1.
if grep -q 'SNEAKER_CITADEL_ID: StringName = &"sneaker_citadel"' "$HUB_GD"; then
	pass "mall_hub.gd defines SNEAKER_CITADEL_ID = &\"sneaker_citadel\""
else
	fail "mall_hub.gd missing SNEAKER_CITADEL_ID const"
fi

if grep -q 'func activate_sneaker_citadel' "$HUB_GD"; then
	pass "mall_hub.gd exposes activate_sneaker_citadel() entry point"
else
	fail "mall_hub.gd missing activate_sneaker_citadel() function"
fi

if awk '
	/^func activate_sneaker_citadel/ { in_fn = 1; next }
	in_fn && /^func / { exit }
	in_fn && /enter_store/ && /SNEAKER_CITADEL_ID/ { print "OK"; exit }
' "$HUB_GD" | grep -q OK; then
	pass "activate_sneaker_citadel() calls enter_store(SNEAKER_CITADEL_ID)"
else
	fail "activate_sneaker_citadel() must call director.enter_store(SNEAKER_CITADEL_ID)"
fi

# Hub must NOT bypass StoreDirector by calling SceneRouter / change_scene_to_*
# for the Sneaker Citadel handoff (DESIGN.md §2.1).
if grep -E 'get_tree\(\)\.change_scene_to_(file|packed)' "$HUB_GD" >/dev/null; then
	fail "mall_hub.gd calls get_tree().change_scene_to_* directly (must route via StoreDirector)"
else
	pass "mall_hub.gd does not call change_scene_to_* directly"
fi

if grep -q 'SceneRouter\.route_to_path' "$HUB_GD"; then
	fail "mall_hub.gd calls SceneRouter.route_to_path directly (must route via StoreDirector)"
else
	pass "mall_hub.gd does not call SceneRouter.route_to_path for store entry"
fi

# AC2 (cont): unit test exists and exercises the mocked-director path.
if [ -f "$TEST" ] \
	&& grep -q 'set_director_for_tests' "$TEST" \
	&& grep -q 'enter_store_calls' "$TEST"; then
	pass "unit test (test_mall_hub_issue_015.gd) verifies activation via mocked director"
else
	fail "missing unit test that mocks StoreDirector and asserts enter_store call"
fi

# AC3: hub pushes InputFocus.CTX_MALL_HUB on _ready and pops on exit_tree.
if grep -q '_push_mall_hub_input_focus' "$HUB_GD" \
	&& grep -q 'InputFocus.push_context(InputFocus.CTX_MALL_HUB)' "$HUB_GD"; then
	pass "_ready pushes InputFocus.CTX_MALL_HUB"
else
	fail "_ready must push InputFocus.CTX_MALL_HUB"
fi

if grep -q '^func _exit_tree' "$HUB_GD" \
	&& grep -q '_pop_mall_hub_input_focus' "$HUB_GD"; then
	pass "_exit_tree pops mall_hub InputFocus context"
else
	fail "_exit_tree must pop the mall_hub InputFocus context"
fi

# AC4: CameraAuthority assertion + MALL_HUB_CAMERA_OK audit emission.
if grep -q 'CameraAuthority.assert_single_active' "$HUB_GD"; then
	pass "hub calls CameraAuthority.assert_single_active()"
else
	fail "hub must call CameraAuthority.assert_single_active()"
fi

if grep -q 'mall_hub_camera_ok' "$HUB_GD"; then
	pass "hub emits AuditLog mall_hub_camera_ok checkpoint on success"
else
	fail "hub must emit AuditLog mall_hub_camera_ok checkpoint"
fi

# AC5: on store_failed, hub shows the fail card and stays interactive.
if grep -q 'store_failed.connect' "$HUB_GD" \
	&& grep -q '_on_store_director_failed' "$HUB_GD"; then
	pass "hub connects to StoreDirector.store_failed"
else
	fail "hub must connect to StoreDirector.store_failed"
fi

if grep -q 'ErrorBanner.show_failure' "$HUB_GD"; then
	pass "hub surfaces FAIL via ErrorBanner.show_failure (fail card)"
else
	fail "hub must call ErrorBanner.show_failure on store_failed"
fi

# Hub does NOT free itself / change scene on FAIL — interactivity is preserved.
if awk '
	/^func _on_store_director_failed/ { in_fn = 1; next }
	in_fn && /^func / { exit }
	in_fn && /(queue_free|change_scene)/ { print "BAD"; exit }
' "$HUB_GD" | grep -q BAD; then
	fail "_on_store_director_failed must not queue_free / change_scene (soft-lock risk)"
else
	pass "_on_store_director_failed leaves hub in tree (no soft-lock)"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
