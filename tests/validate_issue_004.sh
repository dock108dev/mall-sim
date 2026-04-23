#!/usr/bin/env bash
# Validates ISSUE-004: audit_run.sh emits `AUDIT: N/M verified` and gates CI.
#
# Drives tests/audit_run.sh against synthetic logs via AUDIT_SKIP_RUN=1
# and AUDIT_LOG=<tmp>. Verifies:
#   - exactly one `AUDIT: N/M verified` line on every run
#   - exit 1 when N < M (and no known-fail covers the gap)
#   - exit 1 when AUDIT: FAIL <ck> appears for a non-whitelisted checkpoint
#   - exit 1 when a checkpoint outside the manifest is added to known-fail
#   - exit 1 when a known-fail entry actually emitted PASS (stale whitelist)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/tests/audit_run.sh"
REQUIRED_FILE="$ROOT/tests/audit_required_checkpoints.txt"
KNOWN_FAIL_FILE="$ROOT/tests/audit_known_fail.txt"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-004: Runtime Truth audit gate ==="

# AC: manifests exist and are non-empty
if [ -s "$REQUIRED_FILE" ]; then
	pass "required-checkpoint manifest present and non-empty"
else
	fail "required-checkpoint manifest missing/empty: $REQUIRED_FILE"
fi

if [ -f "$KNOWN_FAIL_FILE" ]; then
	pass "known-fail manifest present"
else
	fail "known-fail manifest missing: $KNOWN_FAIL_FILE"
fi

# Helper — run the script with a synthetic log + supporting fixtures.
# Args: <log-content> [extra known-fail entries appended to defaults] -> stdout
_run_gate() {
	local log_content="$1"
	local log_file="$TMP_DIR/audit_$RANDOM.log"
	printf '%s\n' "$log_content" > "$log_file"

	# Synthesize the legacy [AUDIT] PASS lines so the legacy gate passes —
	# we only care about the new manifest gate here.
	{
		echo "[AUDIT] boot_complete: PASS"
		echo "[AUDIT] store_entered: PASS"
		echo "[AUDIT] refurb_completed: PASS"
		echo "[AUDIT] transaction_completed: PASS"
		echo "[AUDIT] day_closed: PASS"
	} >> "$log_file"

	AUDIT_SKIP_RUN=1 AUDIT_LOG="$log_file" bash "$SCRIPT" 2>&1
}

# Count required + known-fail counts for assertions.
_strip() {
	sed -e 's/#.*$//' -e 's/[[:space:]]\+$//' -e 's/^[[:space:]]\+//' \
		| grep -v '^$' || true
}
M_TOTAL=$(_strip < "$REQUIRED_FILE" | wc -l | tr -d ' ')
KF_TOTAL=$(_strip < "$KNOWN_FAIL_FILE" | wc -l | tr -d ' ')

# Sanity: every required checkpoint either has an emitter (none yet) or is
# whitelisted in known-fail. Phase-0 invariant: KF_TOTAL == M_TOTAL means
# baseline gate passes with N=0.
if [ "$KF_TOTAL" -le "$M_TOTAL" ]; then
	pass "known-fail count ($KF_TOTAL) does not exceed required count ($M_TOTAL)"
else
	fail "known-fail count ($KF_TOTAL) exceeds required count ($M_TOTAL)"
fi

# ── Case 1: baseline run (no AUDIT lines at all) — all gaps covered by KF ──
OUT="$(_run_gate "")"
RC=$?
SUMMARY=$(echo "$OUT" | grep -c '^AUDIT: [0-9]\+/[0-9]\+ verified$' || true)
if [ "$SUMMARY" -eq 1 ]; then
	pass "baseline: exactly one AUDIT: N/M verified line"
else
	fail "baseline: expected exactly one summary line, got $SUMMARY"
	echo "$OUT"
fi
if echo "$OUT" | grep -q "^AUDIT: 0/$M_TOTAL verified$"; then
	pass "baseline: summary reads 0/$M_TOTAL when nothing emits"
else
	fail "baseline: expected 'AUDIT: 0/$M_TOTAL verified'"
	echo "$OUT"
fi
if [ "$RC" -eq 0 ]; then
	pass "baseline: exit 0 when all gaps whitelisted"
else
	fail "baseline: expected exit 0, got $RC"
fi

# ── Case 2: a required checkpoint emitted PASS that's still in known-fail ─
FIRST_KF=$(_strip < "$KNOWN_FAIL_FILE" | head -n1)
OUT="$(_run_gate "AUDIT: PASS $FIRST_KF")"
RC=$?
if [ "$RC" -ne 0 ]; then
	pass "stale whitelist: exit non-zero when known-fail entry actually passed"
else
	fail "stale whitelist: expected non-zero exit, got 0"
	echo "$OUT"
fi
if echo "$OUT" | grep -q "still listed in tests/audit_known_fail.txt"; then
	pass "stale whitelist: clear error message about removing entry"
else
	fail "stale whitelist: missing actionable error message"
fi

# ── Case 3: AUDIT: FAIL <ck> for a non-whitelisted checkpoint ─────────────
OUT="$(_run_gate "AUDIT: FAIL bogus_checkpoint_xyz")"
RC=$?
if [ "$RC" -ne 0 ]; then
	pass "audit fail: exit non-zero on AUDIT: FAIL line"
else
	fail "audit fail: expected non-zero exit, got 0"
fi

# ── Case 4: known-fail contains an unknown checkpoint (orphan) ────────────
ORIG_KF=$(cat "$KNOWN_FAIL_FILE")
{
	echo "$ORIG_KF"
	echo "totally_made_up_checkpoint"
} > "$KNOWN_FAIL_FILE"
OUT="$(_run_gate "")"
RC=$?
# restore immediately
echo "$ORIG_KF" > "$KNOWN_FAIL_FILE"
if [ "$RC" -ne 0 ]; then
	pass "orphan known-fail: exit non-zero when entry not in required manifest"
else
	fail "orphan known-fail: expected non-zero exit, got 0"
	echo "$OUT"
fi
if echo "$OUT" | grep -q "is not in required manifest"; then
	pass "orphan known-fail: clear error message"
else
	fail "orphan known-fail: missing diagnostic message"
fi

# ── Case 5: required checkpoint added without emitter or whitelist ────────
ORIG_REQ=$(cat "$REQUIRED_FILE")
ORIG_KF=$(cat "$KNOWN_FAIL_FILE")
{
	echo "$ORIG_REQ"
	echo "brand_new_unimplemented_checkpoint"
} > "$REQUIRED_FILE"
# Note: deliberately NOT adding to known-fail.
OUT="$(_run_gate "")"
RC=$?
echo "$ORIG_REQ" > "$REQUIRED_FILE"
echo "$ORIG_KF" > "$KNOWN_FAIL_FILE"
if [ "$RC" -ne 0 ]; then
	pass "missing emitter: exit non-zero when new required ck has no emitter"
else
	fail "missing emitter: expected non-zero exit, got 0"
	echo "$OUT"
fi
if echo "$OUT" | grep -q "produced no AUDIT: PASS line and is not in tests/audit_known_fail.txt"; then
	pass "missing emitter: clear actionable diagnostic"
else
	fail "missing emitter: diagnostic missing"
	echo "$OUT"
fi

# ── Case 6: real PASS replaces whitelist entry → N increments ─────────────
ORIG_KF=$(cat "$KNOWN_FAIL_FILE")
# Drop FIRST_KF from known-fail so a real PASS counts toward N.
grep -v "^${FIRST_KF}$" "$KNOWN_FAIL_FILE" > "$TMP_DIR/kf_minus.txt"
cp "$TMP_DIR/kf_minus.txt" "$KNOWN_FAIL_FILE"
OUT="$(_run_gate "AUDIT: PASS $FIRST_KF")"
RC=$?
echo "$ORIG_KF" > "$KNOWN_FAIL_FILE"
if echo "$OUT" | grep -q "^AUDIT: 1/$M_TOTAL verified$"; then
	pass "increment: AUDIT: 1/$M_TOTAL verified after one real PASS"
else
	fail "increment: expected '1/$M_TOTAL', got summary:"
	echo "$OUT" | grep '^AUDIT:' || true
fi
if [ "$RC" -eq 0 ]; then
	pass "increment: exit 0 when remaining gaps still whitelisted"
else
	fail "increment: expected exit 0, got $RC"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
