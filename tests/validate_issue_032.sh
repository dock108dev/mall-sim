#!/usr/bin/env bash
# Validates ISSUE-032: custom shaders for interaction highlighting.
set -euo pipefail

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
echo "=== ISSUE-032: Interaction Highlight Shader ==="
echo ""

SHADER="game/assets/shaders/outline_highlight.gdshader"
MATERIAL="game/assets/shaders/mat_outline_highlight.tres"
INTERACTABLE="game/scripts/components/interactable.gd"
ROADMAP="docs/roadmap.md"

echo "[AC1] Shader assets are versioned"
check "outline_highlight.gdshader is tracked" \
	git ls-files --error-unmatch "$SHADER"
check "mat_outline_highlight.tres is tracked" \
	git ls-files --error-unmatch "$MATERIAL"

echo ""
echo "[AC2] Shader provides visible pulsing outline defaults"
check "shader is spatial" grep -q "shader_type spatial" "$SHADER"
check "shader renders front-face culled outline shell" \
	grep -q "render_mode unshaded, cull_front" "$SHADER"
check "outline_width uniform defaults to 0.012" \
	grep -q "uniform float outline_width.*= 0.012" "$SHADER"
check "pulse_speed uniform defaults to 1.5" \
	grep -q "uniform float pulse_speed.*= 1.5" "$SHADER"
check "vertex shader expands along normals" \
	grep -q "VERTEX += NORMAL \\* width" "$SHADER"

echo ""
echo "[AC3] Material is configured for runtime use"
check "material references outline shader" \
	grep -q 'path="res://game/assets/shaders/outline_highlight.gdshader"' "$MATERIAL"
check "material enables local-to-scene duplication" \
	grep -q "resource_local_to_scene = true" "$MATERIAL"
check "material outline_width matches shader default" \
	grep -q "shader_parameter/outline_width = 0.012" "$MATERIAL"
check "material pulse_speed matches shader default" \
	grep -q "shader_parameter/pulse_speed = 1.5" "$MATERIAL"
check "material pulse_intensity is subtle" \
	grep -q "shader_parameter/pulse_intensity = 0.15" "$MATERIAL"

echo ""
echo "[AC4] Interactable hover path uses the material"
check "Interactable preloads outline material" \
	grep -q "mat_outline_highlight.tres" "$INTERACTABLE"
check "highlight attaches outline material as next_pass" \
	grep -q "next_pass = _OUTLINE_MATERIAL.duplicate()" "$INTERACTABLE"
check "unhighlight restores original materials" \
	grep -q "set_surface_override_material(i, _original_materials\\[i\\])" "$INTERACTABLE"

echo ""
echo "[AC5] Placeholder removed"
check ".gdkeep absent from shader directory" \
	bash -c 'test ! -e game/assets/shaders/.gdkeep'

echo ""
echo "[AC6] Roadmap is current"
check "roadmap marks Custom shaders complete" \
	grep -q "\[x\] Custom shaders (outline highlight shader for interactable objects)" "$ROADMAP"

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""
if [ "$FAIL" -eq 0 ]; then
	echo "All ISSUE-032 acceptance criteria validated."
else
	echo "Some ISSUE-032 checks failed."
	exit 1
fi
