#!/usr/bin/env bash
# Tripwire for Phase 0.1 P1.1 + P1.2. The SSOT for the mall's store-card UI
# is `MallOverview` (data-driven from ContentRegistry); `StorefrontCard` and
# `SneakerCitadel` are removed per ADR 0007 and must not regress into the
# game tree.
#
# Flags ANY reintroduction of those tokens inside `game/scenes/`,
# `game/scripts/`, or `game/autoload/`. The `StoreCard` / `StoreSlotCard`
# tokens (the kept SSOT) are allowed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

hits="$(grep -rnE 'StorefrontCard|SneakerCitadel|sneaker_citadel' \
	"$ROOT/game/scenes/" "$ROOT/game/scripts/" "$ROOT/game/autoload/" \
	2>/dev/null || true)"

# Filter out ADR-era comments: the validator script itself lives under
# tests/ and should not flag it. Production code under game/** has zero
# allowed matches.

if [ -z "$hits" ]; then
	echo "PASS: validate_single_store_ui.sh — no StorefrontCard or SneakerCitadel residue"
	exit 0
fi

echo "FAIL: validate_single_store_ui.sh — removed tokens reintroduced in game/:"
echo "$hits"
exit 1
