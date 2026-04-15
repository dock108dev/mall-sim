#!/usr/bin/env bash
# Test runner that uses Godot when available, falls back to static validation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$ROOT/tests"
EXIT_CODE=0

# Resolve Godot binary (PATH, GODOT, or GODOT_EXECUTABLE).
_resolve_godot_bin() {
	local g="${GODOT:-${GODOT_EXECUTABLE:-godot}}"
	if [ -x "$g" ]; then
		echo "$g"
		return 0
	fi
	if command -v "$g" &>/dev/null; then
		command -v "$g"
		return 0
	fi
	return 1
}

# Check if Godot is available
if GODOT_BIN="$(_resolve_godot_bin)"; then
    LOG_FILE="$ROOT/tests/test_run.log"

    echo "Godot found — importing project assets (addons/GUT textures, etc.)..."
    "$GODOT_BIN" --path "$ROOT" --headless --import 2>/dev/null

    echo "Running GDScript tests... (full output → $LOG_FILE)"
    # Redirect stderr (Godot engine warnings/errors) to the log file only.
    # Stdout (GUT results) is tee'd so the terminal shows the pass/fail summary
    # without being flooded by thousands of push_warning lines.
    "$GODOT_BIN" --path "$ROOT" --headless --script res://addons/gut/gut_cmdln.gd \
        2>>"$LOG_FILE" | tee -a "$LOG_FILE" | grep -E "^\*|passed\.|failed\.|Passing|Failing|Run Summary|Scripts|Tests|Time|Risky"
    EXIT_CODE="${PIPESTATUS[0]}"

    if [ -f "$ROOT/game/tests/run_tests.gd" ]; then
        "$GODOT_BIN" --path "$ROOT" --headless --script res://game/tests/run_tests.gd \
            2>>"$LOG_FILE" | tee -a "$LOG_FILE" | grep -E "^\*|passed\.|failed\.|Passing|Failing|Run Summary|Scripts|Tests|Time|Risky"
        [ "${PIPESTATUS[0]}" -ne 0 ] && EXIT_CODE="${PIPESTATUS[0]}"
    fi
else
    echo "Godot not found — running static validation tests..."
    echo ""
fi

# Always run shell-based validation scripts
for test_script in "$TESTS_DIR"/validate_*.sh; do
    if [ -f "$test_script" ]; then
        echo ""
        bash "$test_script" || EXIT_CODE=$?
    fi
done

exit $EXIT_CODE
