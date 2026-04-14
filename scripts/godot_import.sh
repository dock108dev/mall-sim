#!/usr/bin/env bash
## Run Godot editor import so `.godot/imported/` exists (addons, textures, etc.).
## Use before GUT or headless runs on a fresh clone. Requires Godot 4.x editor build.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
G="${GODOT:-${GODOT_EXECUTABLE:-godot}}"

_resolve_godot() {
	if [ -x "$G" ]; then
		echo "$G"
		return 0
	fi
	if command -v "$G" >/dev/null 2>&1; then
		command -v "$G"
		return 0
	fi
	return 1
}

if ! GODOT_BIN="$(_resolve_godot)"; then
	echo "ERROR: Godot not found (tried: $G). Set GODOT to your 4.x editor binary." >&2
	exit 1
fi

echo "Godot import: project=$ROOT binary=$GODOT_BIN"
exec "$GODOT_BIN" --path "$ROOT" --headless --import
