#!/usr/bin/env bash
# Validates ISSUE-012: Build Sneaker Citadel — first real store scene
# satisfying StoreReadyContract.
set -u

PASS=0
FAIL=0

check() {
	local label="$1"
	shift
	if "$@" >/dev/null 2>&1; then
		echo "  PASS: $label"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $label"
		FAIL=$((FAIL + 1))
	fi
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCENE="$ROOT/game/scenes/stores/sneaker_citadel/store_sneaker_citadel.tscn"
CTRL="$ROOT/game/scripts/stores/store_sneaker_citadel_controller.gd"
REGISTRY="$ROOT/game/autoload/store_registry.gd"
GUT_TEST="$ROOT/tests/gut/test_sneaker_citadel_issue_012.gd"
ORIG_GUARD="$ROOT/tests/validate_original_content.sh"

echo ""
echo "=== ISSUE-012: Build Sneaker Citadel — StoreReadyContract scene ==="
echo ""

echo "[AC1] Scene file + required unique-name nodes"
check "scene file exists" test -f "$SCENE"
check "root node SneakerCitadel" grep -q '\[node name="SneakerCitadel"' "$SCENE"
check "%StoreContent node" grep -q '\[node name="StoreContent"' "$SCENE"
check "%StoreCamera node" grep -q '\[node name="StoreCamera"' "$SCENE"
check "%Player node" grep -q '\[node name="Player"' "$SCENE"
check "%EntryMarker node" grep -q '\[node name="EntryMarker"' "$SCENE"
check "StoreContent unique-named" bash -c "grep -A1 'name=\"StoreContent\" type=' '$SCENE' | grep -q 'unique_name_in_owner = true'"
check "StoreCamera unique-named" bash -c "grep -A1 'name=\"StoreCamera\" type=' '$SCENE' | grep -q 'unique_name_in_owner = true'"
check "Player unique-named" bash -c "grep -A1 'name=\"Player\" parent=' '$SCENE' | grep -q 'unique_name_in_owner = true'"
check "EntryMarker unique-named" bash -c "grep -A1 'name=\"EntryMarker\" type=' '$SCENE' | grep -q 'unique_name_in_owner = true'"
check "counter child" grep -q '\[node name="Counter"' "$SCENE"
check "Shelf1 child" grep -q '\[node name="Shelf1"' "$SCENE"
check "Shelf2 child" grep -q '\[node name="Shelf2"' "$SCENE"
check "Shelf3 child" grep -q '\[node name="Shelf3"' "$SCENE"
check "InteractableShelf child" grep -q '\[node name="InteractableShelf"' "$SCENE"
check "StoreCamera marked current" grep -q '^current = true' "$SCENE"
check "objective text present" grep -q 'Interact with the shelf' "$SCENE"

echo ""
echo "[AC2] StoreRegistry resolves sneaker_citadel to this path"
check "registry seeds sneaker_citadel" grep -q 'sneaker_citadel' "$REGISTRY"
check "registry points at nested path" grep -q 'sneaker_citadel/store_sneaker_citadel.tscn' "$REGISTRY"
check "resolve_scene() convenience exists" grep -q '^func resolve_scene' "$REGISTRY"

echo ""
echo "[AC3] Controller exposes StoreReadyContract duck-typed methods"
check "controller file exists" test -f "$CTRL"
check "class_name SneakerCitadelStoreController" grep -q '^class_name SneakerCitadelStoreController' "$CTRL"
check "extends StoreController" grep -q '^extends StoreController' "$CTRL"
check "get_store_id() -> StringName" grep -q '^func get_store_id' "$CTRL"
check "is_controller_initialized() -> bool" grep -q '^func is_controller_initialized' "$CTRL"
check "get_input_context() -> StringName" grep -q '^func get_input_context' "$CTRL"
check "has_blocking_modal() -> bool" grep -q '^func has_blocking_modal' "$CTRL"
check "returns store_gameplay context" grep -q 'store_gameplay' "$CTRL"
check "returns &\"sneaker_citadel\" id" grep -q '&"sneaker_citadel"' "$CTRL"
check "sets objective text on ready" grep -q 'set_objective_text' "$CTRL"
check "requests current camera" grep -q 'request_current' "$CTRL"

echo ""
echo "[AC4] GUT integration test asserts contract + shelf signal"
check "GUT test file exists" test -f "$GUT_TEST"
check "asserts StoreReadyContract.check ok" grep -q 'StoreReadyContract.check' "$GUT_TEST"
check "watches shelf signals" grep -q 'watch_signals' "$GUT_TEST"
check "asserts 'interacted' signal" grep -q "assert_signal_emitted.*interacted" "$GUT_TEST"
check "asserts objective_matches_action" grep -q 'objective_matches_action' "$GUT_TEST"

echo ""
echo "[AC5] Original-content guard exists + passes"
check "original-content guard exists" test -x "$ORIG_GUARD"
check "original-content guard passes" bash "$ORIG_GUARD"

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""
if [ "$FAIL" -eq 0 ]; then
	echo "All ISSUE-012 acceptance criteria validated."
else
	echo "Some checks failed."
	exit 1
fi
