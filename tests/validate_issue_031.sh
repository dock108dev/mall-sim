#!/usr/bin/env bash
# Validate ISSUE-031: GitHub Actions export workflow and export presets.
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKFLOW="$ROOT/.github/workflows/export.yml"
PRESETS="$ROOT/export_presets.cfg"
PROJECT="$ROOT/project.godot"

pass() {
	PASS=$((PASS + 1))
	echo "  PASS: $1"
}

fail() {
	FAIL=$((FAIL + 1))
	echo "  FAIL: $1"
}

check_grep() {
	local label="$1"
	local pattern="$2"
	local file="$3"
	if grep -Fq -- "$pattern" "$file"; then
		pass "$label"
	else
		fail "$label"
	fi
}

check_regex_absent() {
	local label="$1"
	local pattern="$2"
	local file="$3"
	if grep -Eq "$pattern" "$file"; then
		fail "$label"
	else
		pass "$label"
	fi
}

echo "=== ISSUE-031: Export workflow and presets ==="
echo ""

echo "[AC1] Workflow file exists and is configured for tag pushes"
if [ -f "$WORKFLOW" ]; then
	pass "export.yml exists"
else
	fail "export.yml is missing"
fi
check_grep "workflow name is Export" 'name: Export' "$WORKFLOW"
check_grep "workflow triggers on tag pushes" 'tags:' "$WORKFLOW"
check_grep "workflow matches v* tags" '- "v*"' "$WORKFLOW"

echo ""
echo "[AC2] Workflow installs Godot 4.6.2 with export templates"
check_grep "setup-godot action used" 'uses: chickensoft-games/setup-godot@v2' "$WORKFLOW"
check_grep "Godot version pinned to 4.6.2" 'GODOT_VERSION: "4.6.2"' "$WORKFLOW"
check_grep "export templates requested" 'include-templates: true' "$WORKFLOW"
check_grep "Windows rcedit installed for icon metadata" 'npm install --global rcedit' "$WORKFLOW"

echo ""
echo "[AC3] Workflow imports assets and exports both platforms"
check_grep "import script runs before export" 'bash scripts/godot_import.sh' "$WORKFLOW"
check_grep "Windows preset name matches export command" '"Windows Desktop"' "$WORKFLOW"
check_grep "macOS preset exported" '"macOS"' "$WORKFLOW"
check_grep "Windows artifact uploaded" 'name: windows-build' "$WORKFLOW"
check_grep "macOS artifact uploaded" 'name: macos-build' "$WORKFLOW"
check_grep "Windows zip produced" 'mallcore-sim-windows.zip' "$WORKFLOW"
check_grep "macOS zip produced" 'mallcore-sim-macos.zip' "$WORKFLOW"

echo ""
echo "[AC4] Release job publishes both platform zips"
check_grep "release job exists" 'release:' "$WORKFLOW"
check_grep "release uses action-gh-release" 'uses: softprops/action-gh-release@v2' "$WORKFLOW"
check_grep "release attaches macOS zip" 'artifacts/macos/mallcore-sim-macos.zip' "$WORKFLOW"
check_grep "release attaches Windows zip" 'artifacts/windows/mallcore-sim-windows.zip' "$WORKFLOW"

echo ""
echo "[AC5] export_presets.cfg has safe Windows and macOS presets"
if [ -f "$PRESETS" ]; then
	pass "export_presets.cfg exists"
else
	fail "export_presets.cfg is missing"
fi
check_grep "Windows preset exists" 'name="Windows Desktop"' "$PRESETS"
check_grep "macOS preset exists" 'name="macOS"' "$PRESETS"
check_grep "Windows export path is relative" 'export_path="exports/windows/MallcoreSim.exe"' "$PRESETS"
check_grep "macOS export path is relative" 'export_path="exports/macos/MallcoreSim.zip"' "$PRESETS"
check_grep "export excludes repo tests and GUT addons" \
	'exclude_filter=".aidlc/*,docs/*,tests/*,game/tests/*,addons/gut/*,game/addons/gut/*,.godot/*,*.md,*.txt,.gitignore,.gutconfig.json"' "$PRESETS"
check_grep "Windows preset targets x86_64 templates" 'binary_format/architecture="x86_64"' "$PRESETS"
check_grep "Windows icon configured" 'application/icon="res://icon.svg"' "$PRESETS"
check_grep "macOS icon configured" 'application/icon="res://icon.svg"' "$PRESETS"
check_grep "Windows built-in code signing disabled" 'codesign/enable=false' "$PRESETS"
check_grep "macOS built-in code signing disabled" 'codesign/codesign=0' "$PRESETS"

echo ""
echo "[AC5b] project.godot enables universal macOS export prerequisites"
if [ -f "$PROJECT" ]; then
	pass "project.godot exists"
else
	fail "project.godot is missing"
fi
check_grep "ETC2 ASTC import enabled for universal macOS export" \
	'textures/vram_compression/import_etc2_astc=true' "$PROJECT"

echo ""
echo "[AC6] export_presets.cfg contains no hardcoded local paths or credentials"
check_regex_absent "no absolute export paths" 'export_path="([A-Za-z]:|/|~)' "$PRESETS"
check_regex_absent "no embedded Windows cert identity" '^codesign/identity="[^"]+"' "$PRESETS"
check_regex_absent "no embedded code signing password" '^codesign/password="[^"]+"' "$PRESETS"
check_regex_absent "no exported secrets or tokens" '(secret|token|apikey|api_key)' "$PRESETS"
check_regex_absent "no /Users local paths" '/Users/' "$PRESETS"

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""

if [ "$FAIL" -ne 0 ]; then
	exit 1
fi

echo "All ISSUE-031 acceptance criteria validated."
