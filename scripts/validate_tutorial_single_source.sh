#!/usr/bin/env bash
# Tripwire for Phase 0.1 P1.3. The SSOT for tutorial prompt text is
# `translations.en.csv` via `tr()` in `tutorial_overlay.gd`. The duplicate
# source (`game/content/tutorial_steps.json` consumed by `objective_director.gd`)
# is removed. This script fails if either re-appears.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0

if [ -f "$ROOT/game/content/tutorial_steps.json" ]; then
	echo "FAIL: game/content/tutorial_steps.json re-appeared (must be deleted per P1.3)"
	FAIL=1
fi

OBJECTIVE_DIRECTOR="$ROOT/game/autoload/objective_director.gd"
if [ -f "$OBJECTIVE_DIRECTOR" ]; then
	# The file docstring intentionally mentions tutorial to explain the removal.
	# Any non-comment "tutorial" token is a regression.
	residue="$(grep -nE '^[[:space:]]*[^#[:space:]].*\btutorial\b' "$OBJECTIVE_DIRECTOR" || true)"
	if [ -n "$residue" ]; then
		echo "FAIL: objective_director.gd has non-comment 'tutorial' tokens:"
		echo "$residue"
		FAIL=1
	fi
fi

HUD_TSCN="$ROOT/game/scenes/ui/hud.tscn"
if [ -f "$HUD_TSCN" ] && grep -q "ControlHintLabel" "$HUD_TSCN"; then
	echo "FAIL: ControlHintLabel re-appeared in hud.tscn (there is no walkable mall)"
	FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
	echo "PASS: validate_tutorial_single_source.sh — tutorial text has one source"
fi

exit "$FAIL"
