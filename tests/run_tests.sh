#!/usr/bin/env bash
# Test runner that uses Godot when available, falls back to static validation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$ROOT/tests"
EXIT_CODE=0

# Resolve Godot binary (PATH, GODOT, or GODOT_EXECUTABLE).
_resolve_godot_bin() {
	local configured="${GODOT:-${GODOT_EXECUTABLE:-godot}}"
	local candidates=(
		"$configured"
		"/Applications/Godot.app/Contents/MacOS/Godot"
		"$HOME/Applications/Godot.app/Contents/MacOS/Godot"
	)
	local candidate=""
	for candidate in "${candidates[@]}"; do
		if [ -x "$candidate" ]; then
			echo "$candidate"
			return 0
		fi
		if command -v "$candidate" &>/dev/null; then
			command -v "$candidate"
			return 0
		fi
	done
	return 1
}

# Check if Godot is available
if GODOT_BIN="$(_resolve_godot_bin)"; then
    LOG_FILE="$ROOT/tests/test_run.log"

    echo "Godot found — importing project assets (addons/GUT textures, etc.)..."
    "$GODOT_BIN" --path "$ROOT" --headless --import 2>/dev/null

    echo "Seeding GUT editor environment..."
    "$GODOT_BIN" --path "$ROOT" --headless \
        --script res://tests/setup_gut_env.gd 2>/dev/null || true

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
    if [ -n "${GODOT:-}" ] || [ -n "${GODOT_EXECUTABLE:-}" ]; then
        echo "ERROR: GODOT/GODOT_EXECUTABLE is set (\"${GODOT:-${GODOT_EXECUTABLE:-}}\") but no executable Godot binary was found." >&2
        echo "Install Godot 4.6.2 and point GODOT at it, then re-run." >&2
        exit 1
    fi
    echo "Godot not found — running static validation tests only (install Godot 4.6.2 for full suite)..."
    echo ""
fi

# Always run shell-based validation scripts
for test_script in "$TESTS_DIR"/validate_*.sh; do
    if [ -f "$test_script" ]; then
        echo ""
        bash "$test_script" || EXIT_CODE=$?
    fi
done

# Phase 0.1 SSOT tripwires (see docs/audits/phase0-ui-integrity.md P2.1).
SCRIPTS_DIR="$ROOT/scripts"
for tripwire in validate_translations.sh validate_single_store_ui.sh validate_tutorial_single_source.sh; do
    if [ -x "$SCRIPTS_DIR/$tripwire" ]; then
        echo ""
        bash "$SCRIPTS_DIR/$tripwire" || EXIT_CODE=$?
    fi
done

exit $EXIT_CODE
