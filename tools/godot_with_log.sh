#!/usr/bin/env bash
## Launch Godot with all stdout/stderr mirrored to a plain-text log in the repo root.
## *.log is gitignored — open godot_capture.log in Cursor, search, copy in bulk.
##
## Usage:
##   ./tools/godot_with_log.sh              # open editor (default)
##   GODOT=/path/to/Godot ./tools/godot_with_log.sh
##
## Then use this Godot window to run the game (F5). The log file updates live.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
LOG="${ROOT}/godot_capture.log"

echo "Logging to: $LOG"
exec "$GODOT" --path "$ROOT" --log-file "$LOG" -e "$@"
