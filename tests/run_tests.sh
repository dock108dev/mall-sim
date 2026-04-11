#!/usr/bin/env bash
# Test runner that uses Godot when available, falls back to static validation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TESTS_DIR="$ROOT/tests"
EXIT_CODE=0

# Check if Godot is available
if command -v godot &>/dev/null; then
    echo "Godot found — running GDScript tests..."
    godot --headless --script res://addons/gut/gut_cmdln.gd || EXIT_CODE=$?
    if [ -f "$ROOT/game/tests/run_tests.gd" ]; then
        godot --headless --script res://game/tests/run_tests.gd || EXIT_CODE=$?
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
