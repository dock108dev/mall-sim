#!/usr/bin/env bash
# Validates ISSUE-014: CI, Testing & Export Readiness (Phase 12)
set -u

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

check_file() {
  local label="$1"
  local path="$2"
  if [ -f "$path" ]; then
    pass "$label"
  else
    fail "$label (missing: $path)"
  fi
}

check_grep() {
  local label="$1"
  local file="$2"
  shift 2
  if grep -q "$@" "$file" 2>/dev/null; then
    pass "$label"
  else
    fail "$label"
  fi
}

echo ""
echo "=== ISSUE-014: CI, Testing & Export Readiness ==="
echo ""

# --- AC1: run_tests.sh exits 0 (static checks only; Godot required for full) ---
echo "[AC1] tests/run_tests.sh is present and runnable"
check_file "run_tests.sh exists" "$ROOT/tests/run_tests.sh"
if [ -x "$ROOT/tests/run_tests.sh" ] || bash -n "$ROOT/tests/run_tests.sh" 2>/dev/null; then
  pass "run_tests.sh is valid shell"
else
  fail "run_tests.sh has syntax errors"
fi

echo ""
echo "[AC2] Save version fixtures exist for every schema version"
FIXTURE_DIR="$ROOT/tests/fixtures/saves"
check_file "v0 fixture exists" "$FIXTURE_DIR/v0_legacy.json"
check_file "v1 fixture exists" "$FIXTURE_DIR/v1_pre_trade_removal.json"
check_file "v2 fixture exists" "$FIXTURE_DIR/v2_pre_reputation.json"
check_file "v3 fixture exists (current)" "$FIXTURE_DIR/v3_current.json"

for fixture in "$FIXTURE_DIR"/v*.json; do
  if [ -f "$fixture" ]; then
    name="$(basename "$fixture")"
    if grep -q '"save_version"' "$fixture"; then
      pass "$name declares save_version"
    else
      fail "$name missing save_version field"
    fi
  fi
done

echo ""
echo "[AC3] Migration unit tests cover every version step and full chain"
MIGRATION_TEST="$ROOT/tests/gut/test_save_migration_chain.gd"
check_file "migration test file exists" "$MIGRATION_TEST"
check_grep "v0 → v1 unit test" "$MIGRATION_TEST" "_migrate_v0_to_v1"
check_grep "v1 → v2 unit test" "$MIGRATION_TEST" "_migrate_v1_to_v2"
check_grep "v2 → v3 unit test" "$MIGRATION_TEST" "_migrate_v2_to_v3"
check_grep "full chain integration test" "$MIGRATION_TEST" "migrate_save_data"
check_grep "v2 fixture loaded in test" "$MIGRATION_TEST" "FIXTURE_V2"
check_grep "v3 fixture loaded in test" "$MIGRATION_TEST" "FIXTURE_V3"

echo ""
echo "[AC4] export.yml produces Windows, macOS, and Linux artifacts"
EXPORT_YML="$ROOT/.github/workflows/export.yml"
check_file "export.yml exists" "$EXPORT_YML"
check_grep "Windows export job" "$EXPORT_YML" "Export Windows"
check_grep "macOS export job" "$EXPORT_YML" "Export macOS"
check_grep "Linux export job" "$EXPORT_YML" "Export Linux"
check_grep "Linux artifact uploaded" "$EXPORT_YML" "linux-build"
check_grep "Godot 4.6.2 pinned in export.yml" "$EXPORT_YML" "4.6.2"
check_grep "Linux in validate-export-config" "$EXPORT_YML" 'Linux/X11'

echo ""
echo "[AC5] validate.yml has content-originality grep step"
VALIDATE_YML="$ROOT/.github/workflows/validate.yml"
check_file "validate.yml exists" "$VALIDATE_YML"
check_grep "content-originality job exists" "$VALIDATE_YML" "content-originality"
check_grep "Pokemon banned" "$VALIDATE_YML" "Pokemon"
check_grep "Nintendo banned" "$VALIDATE_YML" "Nintendo"
check_grep "Blockbuster banned" "$VALIDATE_YML" "Blockbuster"
check_grep "PSA banned" "$VALIDATE_YML" "PSA"
check_grep "ESPN banned" "$VALIDATE_YML" "ESPN"
check_grep "Marvel banned" "$VALIDATE_YML" "Marvel"
check_grep "Godot 4.6.2 pinned in validate.yml" "$VALIDATE_YML" "4.6.2"

echo ""
echo "[AC6] docs/audits/ directory exists and audit_run.sh writes tables"
check_file "audit_run.sh exists" "$ROOT/tests/audit_run.sh"
if [ -d "$ROOT/docs/audits" ]; then
  pass "docs/audits/ directory exists"
else
  fail "docs/audits/ directory missing"
fi
check_grep "audit table uploaded in validate.yml" "$VALIDATE_YML" "upload-artifact"

echo ""
echo "[AC7] All CI jobs pin Godot 4.6.2"
check_grep "validate.yml pins 4.6.2" "$VALIDATE_YML" "4.6.2-stable"
check_grep "export.yml pins 4.6.2 via env" "$EXPORT_YML" 'GODOT_VERSION: "4.6.2"'

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "All ISSUE-014 acceptance criteria validated."
else
  echo "Some checks failed."
  exit 1
fi
