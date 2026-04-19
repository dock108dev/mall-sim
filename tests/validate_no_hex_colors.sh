#!/usr/bin/env bash
# Validates that no .tscn file contains a bare hex color string.
# Bare hex strings look like: = "#RRGGBB" or = "#RRGGBBAA"
# Godot's native Color(r,g,b,a) float format is allowed.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCENES_DIR="$REPO_ROOT/game/scenes"

# Pattern: a quoted hex color value assigned to any property
HEX_PATTERN='= "#[0-9a-fA-F]\{6,8\}"'

found=0
while IFS= read -r -d '' tscn_file; do
    if grep -qP '= "#[0-9a-fA-F]{6,8}"' "$tscn_file" 2>/dev/null \
        || grep -q '= "#[0-9a-fA-F]\{6,8\}"' "$tscn_file" 2>/dev/null; then
        echo "FAIL: bare hex color in $tscn_file"
        grep -nP '= "#[0-9a-fA-F]{6,8}"' "$tscn_file" 2>/dev/null \
            || grep -n '= "#[0-9a-fA-F]\{6,8\}"' "$tscn_file" 2>/dev/null || true
        found=1
    fi
done < <(find "$SCENES_DIR" -name "*.tscn" -print0)

if [ "$found" -eq 0 ]; then
    echo "OK: no bare hex color strings found in .tscn files"
    exit 0
else
    exit 1
fi
