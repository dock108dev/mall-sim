#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

check() {
  local label="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== ISSUE-003: Create placeholder 3D product models per store type ==="
echo ""

echo "[AC1] At least 6 placeholder .tscn model scenes in game/assets/models/"
MODEL_DIR="game/assets/models/props"
check "Props directory exists" test -d "$MODEL_DIR"
check "placeholder_prop_shelf_product.tscn exists" test -f "$MODEL_DIR/placeholder_prop_shelf_product.tscn"
check "placeholder_prop_sports_memorabilia.tscn exists" test -f "$MODEL_DIR/placeholder_prop_sports_memorabilia.tscn"
check "placeholder_prop_game_cartridge.tscn exists" test -f "$MODEL_DIR/placeholder_prop_game_cartridge.tscn"
check "placeholder_prop_vhs_tape.tscn exists" test -f "$MODEL_DIR/placeholder_prop_vhs_tape.tscn"
check "placeholder_prop_card_pack.tscn exists" test -f "$MODEL_DIR/placeholder_prop_card_pack.tscn"
check "placeholder_prop_electronics_device.tscn exists" test -f "$MODEL_DIR/placeholder_prop_electronics_device.tscn"
COUNT=$(find "$MODEL_DIR" -name "placeholder_*.tscn" | wc -l | tr -d ' ')
check "At least 6 placeholder scenes ($COUNT found)" test "$COUNT" -ge 6

echo ""
echo "[AC2] Models follow polygon budget (use primitive meshes, well under 2000 tris)"
check "Shelf product uses BoxMesh" grep -q "BoxMesh" "$MODEL_DIR/placeholder_prop_shelf_product.tscn"
check "Sports memorabilia uses BoxMesh" grep -q "BoxMesh" "$MODEL_DIR/placeholder_prop_sports_memorabilia.tscn"
check "Game cartridge uses BoxMesh" grep -q "BoxMesh" "$MODEL_DIR/placeholder_prop_game_cartridge.tscn"
check "VHS tape uses BoxMesh" grep -q "BoxMesh" "$MODEL_DIR/placeholder_prop_vhs_tape.tscn"
check "Card pack uses BoxMesh" grep -q "BoxMesh" "$MODEL_DIR/placeholder_prop_card_pack.tscn"
check "Electronics device uses BoxMesh" grep -q "BoxMesh" "$MODEL_DIR/placeholder_prop_electronics_device.tscn"

echo ""
echo "[AC3] Models have distinct silhouettes (multi-mesh composition)"
MEMORABILIA_MESHES=$(grep -c 'type="MeshInstance3D"' "$MODEL_DIR/placeholder_prop_sports_memorabilia.tscn")
check "Sports memorabilia has 2+ mesh nodes ($MEMORABILIA_MESHES)" test "$MEMORABILIA_MESHES" -ge 2
CARTRIDGE_MESHES=$(grep -c 'type="MeshInstance3D"' "$MODEL_DIR/placeholder_prop_game_cartridge.tscn")
check "Game cartridge has 2+ mesh nodes ($CARTRIDGE_MESHES)" test "$CARTRIDGE_MESHES" -ge 2
VHS_MESHES=$(grep -c 'type="MeshInstance3D"' "$MODEL_DIR/placeholder_prop_vhs_tape.tscn")
check "VHS tape has 3+ mesh nodes ($VHS_MESHES)" test "$VHS_MESHES" -ge 3
CARD_MESHES=$(grep -c 'type="MeshInstance3D"' "$MODEL_DIR/placeholder_prop_card_pack.tscn")
check "Card pack has 2+ mesh nodes ($CARD_MESHES)" test "$CARD_MESHES" -ge 2
ELEC_MESHES=$(grep -c 'type="MeshInstance3D"' "$MODEL_DIR/placeholder_prop_electronics_device.tscn")
check "Electronics device has 2+ mesh nodes ($ELEC_MESHES)" test "$ELEC_MESHES" -ge 2

echo ""
echo "[AC4] Models use StandardMaterial3D with category-appropriate albedo colors"
for f in "$MODEL_DIR"/placeholder_*.tscn; do
  NAME=$(basename "$f" .tscn)
  check "$NAME has StandardMaterial3D" grep -q "StandardMaterial3D" "$f"
  check "$NAME has albedo_color" grep -q "albedo_color" "$f"
done

echo ""
echo "[AC5] Files prefixed with placeholder_ per NAMING_CONVENTIONS.md"
NON_PREFIXED=$(find "$MODEL_DIR" -name "*.tscn" ! -name "placeholder_*" | wc -l | tr -d ' ')
check "All .tscn files use placeholder_ prefix ($NON_PREFIXED non-prefixed)" test "$NON_PREFIXED" -eq 0

echo ""
echo "[AC6] Models load in store scenes (shelf_slot.gd references them)"
check "shelf_slot.gd has CATEGORY_SCENES mapping" grep -q "CATEGORY_SCENES" game/scripts/stores/shelf_slot.gd
check "shelf_slot.gd preloads placeholder scenes" grep -q "placeholder_prop_" game/scripts/stores/shelf_slot.gd
check "shelf_slot.gd instantiates scenes" grep -q "scene.instantiate()" game/scripts/stores/shelf_slot.gd
check "All 6 scenes referenced in shelf_slot.gd" \
  bash -c 'for s in shelf_product sports_memorabilia game_cartridge vhs_tape card_pack electronics_device; do grep -q "placeholder_prop_${s}" game/scripts/stores/shelf_slot.gd || exit 1; done'

echo ""
echo "=== Results: $PASS/$((PASS + FAIL)) passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
  echo "ISSUE-003 validation FAILED"
  exit 1
else
  echo "All ISSUE-003 acceptance criteria validated."
fi
