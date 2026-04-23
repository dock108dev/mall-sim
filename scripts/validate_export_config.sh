#!/usr/bin/env bash
## Validate export_presets.cfg and project.godot match required shipping config.
## Mirrors the .github/workflows/export.yml `validate-export-config` job so the
## same checks can run locally without needing the Godot binary or export templates.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
	echo "ERROR: $*" >&2
	exit 1
}

[ -f "export_presets.cfg" ] || fail "export_presets.cfg not found"
[ -f "project.godot" ] || fail "project.godot not found"

for preset in 'name="Windows Desktop"' 'name="macOS"' 'name="Linux/X11"'; do
	grep -q "$preset" export_presets.cfg || fail "Missing required preset: $preset"
done

ICON_COUNT="$(grep -c '^application/icon="res://icon.svg"$' export_presets.cfg || true)"
[ "$ICON_COUNT" -ge 2 ] || fail "Windows and macOS presets must both use res://icon.svg"

grep -q '^codesign/enable=false$' export_presets.cfg \
	|| fail "Windows preset must not enable built-in code signing"
grep -q '^codesign/codesign=0$' export_presets.cfg \
	|| fail "macOS preset must not enable built-in code signing"
grep -q '^binary_format/architecture="x86_64"$' export_presets.cfg \
	|| fail "Windows preset must target x86_64 for Godot export templates"

if grep -Eq 'export_path="([A-Za-z]:|/|~)' export_presets.cfg; then
	fail "export_presets.cfg contains an absolute export_path"
fi
if grep -q '/Users/' export_presets.cfg; then
	fail "export_presets.cfg contains a local macOS path"
fi
if grep -Eq '^codesign/identity="[^"]+"' export_presets.cfg; then
	fail "export_presets.cfg contains a hardcoded code signing identity"
fi
if grep -Eq '^codesign/password="[^"]+"' export_presets.cfg; then
	fail "export_presets.cfg contains a hardcoded code signing password"
fi
if grep -Eqi '(secret|token|apikey|api_key)' export_presets.cfg; then
	fail "export_presets.cfg appears to contain secret material"
fi

grep -q '^textures/vram_compression/import_etc2_astc=true$' project.godot \
	|| fail "Universal macOS export requires ETC2 ASTC import support in project.godot"

echo "Export config validation: OK"
