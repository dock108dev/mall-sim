#!/usr/bin/env bash
# Original-content guard (ISSUE-012 AC6).
#
# Greps authored store content (scenes + store scripts) for a denylist of
# real-world trademarks that would leak the parody framing. This is a
# string-level guard — anything that slips through must be added here.
#
# Scope: game/scenes/stores/**, game/scripts/stores/**. Test fixtures and
# docs are excluded; those reference real brands in audit notes and are not
# shipped content.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCENES_DIR="$ROOT/game/scenes/stores"
SCRIPTS_DIR="$ROOT/game/scripts/stores"

# Denylist of real brand / trademarked terms. Case-insensitive. Keep this
# tight — false positives force contributors to rename legitimate things.
DENY=(
	"Nike"
	"Adidas"
	"Reebok"
	"Puma"
	"Jordan Brand"
	"Air Jordan"
	"Converse"
	"Foot Locker"
	"Footlocker"
	"New Balance"
	"Under Armour"
	"Yeezy"
)

FAIL=0
TOTAL=0

echo ""
echo "=== Original-content guard (no real brand names in store content) ==="
echo ""

for term in "${DENY[@]}"; do
	TOTAL=$((TOTAL + 1))
	# -r recursive, -i case-insensitive, -I skip binary, -n line number,
	# --include limits to authored files; the scripts/scenes dirs are text.
	hits=$(grep -rIni --include='*.tscn' --include='*.gd' \
		-- "$term" "$SCENES_DIR" "$SCRIPTS_DIR" 2>/dev/null || true)
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
	echo "All authored store content is clear of denylisted trademarks."
	exit 0
fi
echo "Denylisted trademarks detected. Rename the offending content."
exit 1
