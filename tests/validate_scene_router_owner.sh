#!/usr/bin/env bash
# ISSUE-009: SceneRouter is the SOLE owner of `get_tree().change_scene_to_*`.
#
# Fails CI if any file under game/ outside scene_router.gd calls
# change_scene_to_file / change_scene_to_packed directly.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROUTER_REL="game/autoload/scene_router.gd"

echo "=== ISSUE-009: SceneRouter sole-owner check ==="

if [ ! -f "$ROOT/$ROUTER_REL" ]; then
	echo "  FAIL: missing $ROUTER_REL"
	exit 1
fi

# Find any callers under game/ outside the router itself. Comments and the
# autoload script are excluded.
violations=$(
	grep -RIn --include='*.gd' \
		-E 'get_tree\(\)\.change_scene_to_(file|packed)' \
		"$ROOT/game" \
		| grep -v "^${ROOT}/${ROUTER_REL}:" \
		| grep -vE ':\s*#' \
		|| true
)

if [ -n "$violations" ]; then
	echo "  FAIL: change_scene_to_* called outside SceneRouter:"
	echo "$violations" | sed 's|^|    |'
	exit 1
fi

echo "  PASS: zero bypasses of SceneRouter found"
exit 0
