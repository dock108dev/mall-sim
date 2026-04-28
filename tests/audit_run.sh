#!/usr/bin/env bash
# Headless interaction audit runner + Runtime Truth gate.
#
# Two parsing passes:
#   1. Legacy `[AUDIT] <key>: PASS|FAIL` lines emitted by AuditOverlay
#      (issue 002). Drives the per-day Markdown summary table.
#   2. Structured `AUDIT: PASS <name>` / `AUDIT: FAIL <name>` lines emitted
#      by AuditLog (issue 001). Compared against the required-checkpoint
#      manifest derived from docs/audit/pass-fail-matrix.md, with optional
#      whitelisting via tests/audit_known_fail.txt.
#
# Final summary line is exactly one `AUDIT: N/M verified`. Exit 1 if any
# required checkpoint is unaccounted for, or any AUDIT: FAIL line appears
# for a checkpoint not whitelisted in known-fail.
#
# Test hook: set AUDIT_SKIP_RUN=1 and AUDIT_LOG=<path> to skip the headless
# Godot run and gate against an existing log file (used by
# tests/validate_issue_004.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT_LOG="${AUDIT_LOG:-$ROOT/tests/audit.log}"
AUDITS_DIR="$ROOT/docs/audits"
DATE_STAMP="$(date -u +%Y-%m-%d)"
AUDIT_TABLE="$AUDITS_DIR/${DATE_STAMP}-audit.md"
REQUIRED_FILE="$ROOT/tests/audit_required_checkpoints.txt"
KNOWN_FAIL_FILE="$ROOT/tests/audit_known_fail.txt"
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

# ── Run headless audit (unless test hook bypassed) ────────────────────────────
if [ "${AUDIT_SKIP_RUN:-0}" != "1" ]; then
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

	echo "Seeding GUT editor environment..."
	"$GODOT_BIN" --path "$ROOT" --headless \
		--script res://tests/setup_gut_env.gd 2>/dev/null || true

	echo "Running audit checkpoint tests..."
	"$GODOT_BIN" --path "$ROOT" --headless \
		--script res://addons/gut/gut_cmdln.gd -- \
		-gconfig=res://.gutconfig.json \
		-ginclude_subdirs \
		-gdir=res://tests/gut \
		-gprefix=test_audit \
		-gexit \
		2>&1 | tee "$AUDIT_LOG" || true
fi

if [ ! -f "$AUDIT_LOG" ]; then
	echo "ERROR: audit log not found at $AUDIT_LOG" >&2
	exit 1
fi

# ── Load required + known-fail manifests ──────────────────────────────────────
_strip_manifest() {
	# stdin: file with comments/blank lines; stdout: bare entries.
	sed -e 's/#.*$//' -e 's/[[:space:]]\+$//' -e 's/^[[:space:]]\+//' \
		| grep -v '^$' || true
}

if [ ! -f "$REQUIRED_FILE" ]; then
	echo "ERROR: required-checkpoint manifest missing: $REQUIRED_FILE" >&2
	exit 1
fi

REQUIRED_LIST=()
while IFS= read -r ck; do
	REQUIRED_LIST+=("$ck")
done < <(_strip_manifest < "$REQUIRED_FILE")

KNOWN_FAIL_LIST=()
if [ -f "$KNOWN_FAIL_FILE" ]; then
	while IFS= read -r ck; do
		KNOWN_FAIL_LIST+=("$ck")
	done < <(_strip_manifest < "$KNOWN_FAIL_FILE")
fi

declare -A REQUIRED_SET
for ck in "${REQUIRED_LIST[@]}"; do
	REQUIRED_SET[$ck]=1
done

declare -A KNOWN_FAIL_SET
for ck in "${KNOWN_FAIL_LIST[@]}"; do
	KNOWN_FAIL_SET[$ck]=1
done

# Orphan check: known-fail entries must reference a required checkpoint.
for ck in "${KNOWN_FAIL_LIST[@]}"; do
	if [ -z "${REQUIRED_SET[$ck]:-}" ]; then
		echo "AUDIT FAILED: known-fail entry '$ck' is not in required manifest." >&2
		EXIT_CODE=1
	fi
done

# ── Parse legacy [AUDIT] lines (AuditOverlay) ─────────────────────────────────
LEGACY_CHECKPOINTS=("boot_complete" "store_entered" "refurb_completed" "transaction_completed" "day_closed")
declare -A LEGACY_RESULTS
for key in "${LEGACY_CHECKPOINTS[@]}"; do
	LEGACY_RESULTS[$key]="PENDING"
done

# ── Parse structured AUDIT: PASS|FAIL <name> lines (AuditLog) ─────────────────
declare -A AUDIT_PASS
declare -A AUDIT_FAIL

while IFS= read -r line; do
	if [[ "$line" =~ \[AUDIT\]\ ([^:]+):\ (PASS|FAIL)(.*)?$ ]]; then
		LEGACY_RESULTS[${BASH_REMATCH[1]}]="${BASH_REMATCH[2]}"
		continue
	fi
	if [[ "$line" =~ ^AUDIT:\ PASS\ ([A-Za-z0-9_]+) ]]; then
		AUDIT_PASS[${BASH_REMATCH[1]}]=1
		continue
	fi
	if [[ "$line" =~ ^AUDIT:\ FAIL\ ([A-Za-z0-9_]+) ]]; then
		AUDIT_FAIL[${BASH_REMATCH[1]}]=1
		continue
	fi
done < "$AUDIT_LOG"

# Also count GUT failures
GUT_FAIL_COUNT=$(grep -c "^FAILED\b\|^ *[0-9]* failed\b\|Tests: [0-9]*, Passing: [0-9]*, Failing: [1-9]" "$AUDIT_LOG" 2>/dev/null || true)

# ── Generate Markdown table for legacy checkpoints ────────────────────────────
{
	echo "# Interaction Audit — ${DATE_STAMP}"
	echo ""
	echo "| Checkpoint | Result |"
	echo "|---|---|"
	for key in "${LEGACY_CHECKPOINTS[@]}"; do
		status="${LEGACY_RESULTS[$key]:-PENDING}"
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

# ── Print legacy summary ──────────────────────────────────────────────────────
echo "| Checkpoint | Result |"
echo "|---|---|"
for key in "${LEGACY_CHECKPOINTS[@]}"; do
	status="${LEGACY_RESULTS[$key]:-PENDING}"
	echo "| $key | $status |"
done
echo ""

# Legacy gating: PENDING == failure (silent instrumentation regression).
for key in "${LEGACY_CHECKPOINTS[@]}"; do
	status="${LEGACY_RESULTS[$key]:-PENDING}"
	if [ "$status" != "PASS" ]; then
		echo "AUDIT FAILED: checkpoint '$key' status is $status (expected PASS)." >&2
		EXIT_CODE=1
	fi
done

if [ "$GUT_FAIL_COUNT" -gt 0 ]; then
	echo "AUDIT FAILED: $GUT_FAIL_COUNT GUT test failure(s)." >&2
	EXIT_CODE=1
fi

# ── Runtime Truth gate (matrix-derived manifest) ──────────────────────────────
M=${#REQUIRED_LIST[@]}
N=0
MISSING=()
for ck in "${REQUIRED_LIST[@]}"; do
	if [ -n "${AUDIT_PASS[$ck]:-}" ]; then
		N=$((N + 1))
	elif [ -n "${KNOWN_FAIL_SET[$ck]:-}" ]; then
		: # whitelisted — counted toward M but not toward N
	else
		MISSING+=("$ck")
	fi
done

# Surface unexpected AUDIT: FAIL lines (real runtime failures).
for ck in "${!AUDIT_FAIL[@]}"; do
	if [ -z "${KNOWN_FAIL_SET[$ck]:-}" ]; then
		echo "AUDIT FAILED: AUDIT: FAIL '$ck' emitted (not whitelisted)." >&2
		EXIT_CODE=1
	fi
done

# Surface required checkpoints that have neither PASS nor known-fail entry.
for ck in "${MISSING[@]}"; do
	echo "AUDIT FAILED: required checkpoint '$ck' produced no AUDIT: PASS line and is not in tests/audit_known_fail.txt." >&2
	echo "              Either implement the emitter or whitelist it explicitly." >&2
	EXIT_CODE=1
done

# Detect stale known-fail entries (whitelisted but actually emitted PASS).
for ck in "${KNOWN_FAIL_LIST[@]}"; do
	if [ -n "${AUDIT_PASS[$ck]:-}" ]; then
		echo "AUDIT FAILED: '$ck' emitted PASS but is still listed in tests/audit_known_fail.txt — remove it." >&2
		EXIT_CODE=1
	fi
done

# Single canonical summary line — parsed by CI.
echo "AUDIT: $N/$M verified"

if [ "$EXIT_CODE" -eq 0 ]; then
	echo "AUDIT PASSED"
fi

exit $EXIT_CODE
