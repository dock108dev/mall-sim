#!/usr/bin/env bash
# ISSUE-010: CameraAuthority is the SOLE writer of `camera.current = true` /
# `make_current()` in production game code.
#
# Fails CI if any *.gd under game/ (excluding game/autoload/camera_authority.gd
# and game/tests/**, which exercise cameras directly for unit setup) sets
# `.current = true` or calls `make_current()` outside the authority.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUTHORITY_REL="game/autoload/camera_authority.gd"

echo "=== ISSUE-010: CameraAuthority sole-owner check ==="

if [ ! -f "$ROOT/$AUTHORITY_REL" ]; then
	echo "  FAIL: missing $AUTHORITY_REL"
	exit 1
fi

violations=$(
	grep -RIn --include='*.gd' \
		-E '\.current[[:space:]]*=[[:space:]]*true|\.make_current\(\)' \
		"$ROOT/game" \
		| grep -v "^${ROOT}/${AUTHORITY_REL}:" \
		| grep -v "^${ROOT}/game/tests/" \
		| grep -vE ':\s*#' \
		|| true
)

if [ -n "$violations" ]; then
	echo "  FAIL: camera activation outside CameraAuthority:"
	echo "$violations" | sed 's|^|    |'
	exit 1
fi

echo "  PASS: zero direct camera.current writes in game/ source"
exit 0
