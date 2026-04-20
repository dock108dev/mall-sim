#!/usr/bin/env bash
# Headless interaction audit runner.
# Runs AuditOverlay checkpoint tests, parses [AUDIT] lines,
# writes a Markdown PASS/FAIL table to docs/audits/, exits non-zero on any FAIL.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT_LOG="$ROOT/tests/audit.log"
AUDITS_DIR="$ROOT/docs/audits"
DATE_STAMP="$(date -u +%Y-%m-%d)"
AUDIT_TABLE="$AUDITS_DIR/${DATE_STAMP}-audit.md"
EXIT_CODE=0

# ── Resolve Godot binary ──────────────────────────────────────────────────────
_resolve_godot_bin() {
	local configured="${GODOT:-${GODOT_EXECUTABLE:-godot}}"
	local candidates=(
		"$configured"
		"/Applications/Godot.app/Contents/MacOS/Godot"
		"$HOME/Applications/Godot.app/Contents/MacOS/Godot"
	)
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

mkdir -p "$AUDITS_DIR"

if ! GODOT_BIN="$(_resolve_godot_bin)"; then
	if [ -n "${GODOT:-}" ] || [ -n "${GODOT_EXECUTABLE:-}" ]; then
		echo "ERROR: GODOT/GODOT_EXECUTABLE is set but no executable binary found." >&2
		exit 1
	fi
	echo "WARNING: Godot not found — skipping headless audit run." >&2
	echo "Install Godot 4.6.2 and set GODOT to run the full audit." >&2
	exit 0
fi

echo "=== Interaction Audit ==="
echo "Importing project assets..."
"$GODOT_BIN" --path "$ROOT" --headless --import 2>/dev/null || true

echo "Running audit checkpoint tests..."
"$GODOT_BIN" --path "$ROOT" --headless \
	--script res://addons/gut/gut_cmdln.gd -- \
	-gconfig=res://.gutconfig.json \
	-ginclude_subdirs \
	-gdir=res://tests/gut \
	-gprefix=test_audit \
	-gexit \
	2>&1 | tee "$AUDIT_LOG" || true

# ── Parse [AUDIT] lines ───────────────────────────────────────────────────────
CHECKPOINTS=("boot_complete" "store_entered" "refurb_completed" "transaction_completed" "day_closed")
declare -A RESULTS

for key in "${CHECKPOINTS[@]}"; do
	RESULTS[$key]="PENDING"
done

while IFS= read -r line; do
	if [[ "$line" =~ \[AUDIT\]\ ([^:]+):\ (PASS|FAIL)(.*)?$ ]]; then
		key="${BASH_REMATCH[1]}"
		status="${BASH_REMATCH[2]}"
		RESULTS[$key]="$status"
	fi
done < "$AUDIT_LOG"

# Also count GUT failures
GUT_FAIL_COUNT=$(grep -c "^FAILED\b\|^ *[0-9]* failed\b\|Tests: [0-9]*, Passing: [0-9]*, Failing: [1-9]" "$AUDIT_LOG" 2>/dev/null || true)

# ── Generate Markdown table ───────────────────────────────────────────────────
{
	echo "# Interaction Audit — ${DATE_STAMP}"
	echo ""
	echo "| Checkpoint | Result |"
	echo "|---|---|"
	for key in "${CHECKPOINTS[@]}"; do
		status="${RESULTS[$key]:-PENDING}"
		icon="⏳"
		[ "$status" = "PASS" ] && icon="✅"
		[ "$status" = "FAIL" ] && icon="❌"
		echo "| \`${key}\` | ${icon} ${status} |"
	done
	echo ""
	echo "_Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")_"
} > "$AUDIT_TABLE"

echo ""
echo "Audit table written to: $AUDIT_TABLE"
echo ""

# ── Print summary ─────────────────────────────────────────────────────────────
echo "| Checkpoint | Result |"
echo "|---|---|"
for key in "${CHECKPOINTS[@]}"; do
	status="${RESULTS[$key]:-PENDING}"
	echo "| $key | $status |"
done
echo ""

# ── Exit code ─────────────────────────────────────────────────────────────────
for key in "${CHECKPOINTS[@]}"; do
	if [ "${RESULTS[$key]:-PENDING}" = "FAIL" ]; then
		echo "AUDIT FAILED: checkpoint '$key' did not pass." >&2
		EXIT_CODE=1
	fi
done

if [ "$GUT_FAIL_COUNT" -gt 0 ]; then
	echo "AUDIT FAILED: $GUT_FAIL_COUNT GUT test failure(s)." >&2
	EXIT_CODE=1
fi

if [ "$EXIT_CODE" -eq 0 ]; then
	echo "AUDIT PASSED"
fi

exit $EXIT_CODE
