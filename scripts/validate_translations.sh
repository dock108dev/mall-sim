#!/usr/bin/env bash
# Tripwire for Phase 0.1 P2.1. Walks every `tr("KEY")` / `tr(&"KEY")` call
# site in game/**/*.gd and asserts KEY exists as a row in
# game/assets/localization/translations.en.csv. A missing row is what caused
# "TUTORIAL_WALK_TO_STORE" to render on-screen as the raw key — this script
# catches that regression at CI time.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CSV="$ROOT/game/assets/localization/translations.en.csv"
CODE_DIR="$ROOT/game"

if [ ! -f "$CSV" ]; then
	echo "ERROR: $CSV not found" >&2
	exit 1
fi

# Extract declared keys from the CSV (column 1, skip header).
declared="$(tail -n +2 "$CSV" | awk -F, '{print $1}' | sed 's/"//g' | sort -u)"

# Scan .gd files for tr("KEY") and tr(&"KEY") usages. Capture the key.
found_keys="$(grep -rhoE 'tr\(&?"[A-Z_][A-Z0-9_]*"' "$CODE_DIR" --include='*.gd' \
	| sed -E 's/tr\(&?"([A-Z0-9_]+)".*/\1/' \
	| sort -u || true)"

missing=()
while IFS= read -r key; do
	[ -z "$key" ] && continue
	if ! grep -Fxq "$key" <<<"$declared"; then
		missing+=("$key")
	fi
done <<<"$found_keys"

if [ "${#missing[@]}" -eq 0 ]; then
	echo "PASS: validate_translations.sh — every tr() key resolves to a CSV row"
	exit 0
fi

echo "FAIL: validate_translations.sh — ${#missing[@]} tr() key(s) missing from $CSV:"
for k in "${missing[@]}"; do
	echo "  - $k"
done
exit 1
