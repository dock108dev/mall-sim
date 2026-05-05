#!/usr/bin/env bash
# Content-originality guard. Greps authored game content (JSON catalogs and
# scenes) for a denylist of real-world platform / publisher / franchise
# trademarks that would break the parody framing if they leaked into
# shipping content. This is a string-level guard — anything that slips
# through must be added to the DENY array below.
#
# Scope: game/content/**/*.json, game/scenes/**, game/scripts/stores/**.
# Test fixtures and audit notes under tests/, docs/, and .aidlc/ are
# excluded; those reference real brands for context and are not shipped.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTENT_DIR="$ROOT/game/content"
SCENES_DIR="$ROOT/game/scenes"
STORE_SCRIPTS_DIR="$ROOT/game/scripts/stores"

# Denylist of real-world trademarks. Case-insensitive whole-word match.
# Keep tight to avoid false positives; add new terms only when a real
# trademark slips through.
DENY=(
	"Nintendo"
	"PlayStation"
	"PS2"
	"PS3"
	"PSP"
	"GameCube"
	"GameBoy"
	"Game Boy"
	"Xbox"
	"Sega"
	"Dreamcast"
	"Atari"
	"Wii"
	"Nintendo DS"
	"Mario"
	"Zelda"
	"Pokemon"
	"Pokémon"
	"Halo"
	"Final Fantasy"
	"Metal Gear"
	"Resident Evil"
	"Madden"
	"FIFA"
	"Gran Turismo"
	"Grand Theft Auto"
	"Tetris"
	"Sonic the Hedgehog"
)

FAIL=0
TOTAL=0

echo ""
echo "=== Content originality guard (no real trademarks in shipped content) ==="
echo ""

for term in "${DENY[@]}"; do
	TOTAL=$((TOTAL + 1))
	hits=$(grep -rIni \
		--include='*.json' --include='*.tscn' --include='*.gd' \
		-w -- "$term" \
		"$CONTENT_DIR" "$SCENES_DIR" "$STORE_SCRIPTS_DIR" 2>/dev/null || true)
	if [ -n "$hits" ]; then
		echo "  FAIL: denylisted term '$term' found:"
		echo "$hits" | sed 's/^/    /'
		FAIL=$((FAIL + 1))
	else
		echo "  PASS: no hits for '$term'"
	fi
done

echo ""
echo "=== Results: $((TOTAL - FAIL))/${TOTAL} terms clean, ${FAIL} violations ==="
echo ""
if [ "$FAIL" -eq 0 ]; then
	echo "All shipped content is clear of denylisted trademarks."
	exit 0
fi
echo "Denylisted trademarks detected. Rename the offending content."
exit 1
