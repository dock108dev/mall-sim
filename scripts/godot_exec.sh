#!/usr/bin/env bash
## Resolve a Godot editor binary and execute it with the provided arguments.
set -euo pipefail

CONFIGURED_GODOT="${GODOT:-${GODOT_EXECUTABLE:-godot}}"

_resolve_godot() {
	local candidates=(
		"$CONFIGURED_GODOT"
		"/Applications/Godot.app/Contents/MacOS/Godot"
		"$HOME/Applications/Godot.app/Contents/MacOS/Godot"
	)
	local candidate=""
	for candidate in "${candidates[@]}"; do
		if [ -x "$candidate" ]; then
			echo "$candidate"
			return 0
		fi
		if command -v "$candidate" >/dev/null 2>&1; then
			command -v "$candidate"
			return 0
		fi
	done
	return 1
}

if ! GODOT_BIN="$(_resolve_godot)"; then
	echo "ERROR: Godot not found (tried: $CONFIGURED_GODOT). Set GODOT to your 4.x editor binary." >&2
	exit 1
fi

exec "$GODOT_BIN" "$@"
