#!/usr/bin/env bash
# Validates ISSUE-009: Product highlight outline shader for interactable items
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

echo ""
echo "=== ISSUE-009: Product Highlight Outline Shader ==="
echo ""

# AC1: Shader file exists
echo "[AC1] outline_highlight.gdshader exists"
check "Shader file exists" test -f game/assets/shaders/outline_highlight.gdshader
check "Shader is spatial type" grep -q "shader_type spatial" game/assets/shaders/outline_highlight.gdshader
check "Shader uses cull_front (inverted hull)" grep -q "cull_front" game/assets/shaders/outline_highlight.gdshader
check "Shader has outline_color uniform" grep -q "uniform.*outline_color" game/assets/shaders/outline_highlight.gdshader
check "Shader expands vertices along normals" grep -q "VERTEX.*NORMAL" game/assets/shaders/outline_highlight.gdshader
check "Shader has pulse animation" grep -q "pulse_speed\|pulse_intensity" game/assets/shaders/outline_highlight.gdshader

echo ""
echo "[AC2] ShaderMaterial resource exists"
check "Material .tres file exists" test -f game/assets/shaders/mat_outline_highlight.tres
check "Material references shader" grep -q "outline_highlight.gdshader" game/assets/shaders/mat_outline_highlight.tres
check "Material type is ShaderMaterial" grep -q "ShaderMaterial" game/assets/shaders/mat_outline_highlight.tres

echo ""
echo "[AC3] Outline color matches art direction (teal accent)"
check "Shader default is teal" grep -q "0.0.*0.737\|0.0, 0.737" game/assets/shaders/outline_highlight.gdshader
check "Material uses teal color" grep -q "0, 0.737, 0.725" game/assets/shaders/mat_outline_highlight.tres

echo ""
echo "[AC4] Interactable uses outline shader via next_pass"
check "Interactable references outline material" grep -q "mat_outline_highlight" game/scripts/components/interactable.gd
check "Interactable uses preload" grep -q "preload" game/scripts/components/interactable.gd
check "highlight() sets next_pass" grep -q "next_pass" game/scripts/components/interactable.gd
if grep -q "emission_energy_multiplier" game/scripts/components/interactable.gd; then
  echo "  FAIL: No old emission highlight in highlight()"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: No old emission highlight in highlight()"
  PASS=$((PASS + 1))
fi
check "unhighlight() restores original materials" grep -q "_original_materials\[i\]" game/scripts/components/interactable.gd

echo ""
echo "[AC5] Outline removes cleanly when raycast moves away"
check "unhighlight clears _original_materials" grep -q "_original_materials.clear()" game/scripts/components/interactable.gd
check "unhighlight checks _highlight_active guard" grep -q "not _highlight_active" game/scripts/components/interactable.gd

echo ""
echo "[AC6] ShelfSlot placement highlight still works independently"
check "ShelfSlot still has placement highlight" grep -q "_apply_placement_highlight" game/scripts/stores/shelf_slot.gd
check "ShelfSlot calls super.highlight()" grep -q "super.highlight()" game/scripts/stores/shelf_slot.gd
check "ShelfSlot has HIGHLIGHT_EMPTY" grep -q "HIGHLIGHT_EMPTY" game/scripts/stores/shelf_slot.gd
check "ShelfSlot has HIGHLIGHT_OCCUPIED" grep -q "HIGHLIGHT_OCCUPIED" game/scripts/stores/shelf_slot.gd

echo ""
echo "[AC7] Performance: shader is lightweight"
check "Shader is unshaded (no lighting calculations)" grep -q "unshaded" game/assets/shaders/outline_highlight.gdshader
check "Material is resource_local_to_scene" grep -q "resource_local_to_scene = true" game/assets/shaders/mat_outline_highlight.tres

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "All ISSUE-009 acceptance criteria validated."
else
  echo "Some checks failed."
  exit 1
fi
