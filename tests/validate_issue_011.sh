#!/usr/bin/env bash
# Validates ISSUE-011: Save file versioning and migration chain.
set -u

PASS=0
FAIL=0

check() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    FAIL=$((FAIL + 1))
  fi
}

SAVE_MANAGER="game/scripts/core/save_manager.gd"

echo ""
echo "=== ISSUE-011: Save file versioning and migration chain ==="
echo ""

echo "[AC1] save_version field is written at save root"
check "CURRENT_SAVE_VERSION constant declared" grep -q "^const CURRENT_SAVE_VERSION: int" "$SAVE_MANAGER"
check "save_version written to root of save dictionary" grep -q '"save_version": CURRENT_SAVE_VERSION' "$SAVE_MANAGER"

echo ""
echo "[AC2] Migration chain runs sequentially per version bump"
check "migrate_save_data orchestrator exists" grep -q "func migrate_save_data" "$SAVE_MANAGER"
check "v0 → v1 migration function exists" grep -q "func _migrate_v0_to_v1" "$SAVE_MANAGER"
check "v1 → v2 migration function exists" grep -q "func _migrate_v1_to_v2" "$SAVE_MANAGER"
check "load_game rejects newer-than-supported saves" grep -q "newer than supported version" "$SAVE_MANAGER"
check "load_game rejects older-than-minimum saves" grep -q "older than minimum supported version" "$SAVE_MANAGER"
check "migration failure surfaces through load_game" grep -q "Migration failed" "$SAVE_MANAGER"

echo ""
echo "[AC3] Migration functions are isolated Dictionary → Dictionary"
check "v0 → v1 is Dictionary → Dictionary" grep -q "func _migrate_v0_to_v1(data: Dictionary) -> Dictionary" "$SAVE_MANAGER"
check "v1 → v2 is Dictionary → Dictionary" grep -q "func _migrate_v1_to_v2(data: Dictionary) -> Dictionary" "$SAVE_MANAGER"

echo ""
echo "[AC4] GUT migration test covers at least two version bumps"
TEST_FILE="tests/gut/test_save_migration_chain.gd"
check "Migration test file exists" test -f "$TEST_FILE"
check "Test covers v0 → v1" grep -q "_migrate_v0_to_v1" "$TEST_FILE"
check "Test covers v1 → v2" grep -q "_migrate_v1_to_v2" "$TEST_FILE"
check "Test drives the full chain" grep -q "migrate_save_data" "$TEST_FILE"

echo ""
echo "[AC5] Migration does not overwrite original save (atomic on disk)"
check "load_game reads via _read_save_dictionary only" grep -q "_read_save_dictionary" "$SAVE_MANAGER"
check "save writes go through _write_save_file_atomic" grep -q "_write_save_file_atomic" "$SAVE_MANAGER"

echo ""
echo "[AC6] Any checked-in save fixture carries save_version"
FIXTURE_DIR="tests/fixtures/saves"
if [ -d "$FIXTURE_DIR" ]; then
  fixtures_found=0
  missing_field=0
  while IFS= read -r -d '' fixture; do
    fixtures_found=$((fixtures_found + 1))
    if ! grep -q '"save_version"' "$fixture"; then
      echo "  FAIL: save_version missing in $fixture"
      missing_field=$((missing_field + 1))
    fi
  done < <(find "$FIXTURE_DIR" -type f -name '*.json' -print0)
  if [ "$fixtures_found" -eq 0 ]; then
    echo "  FAIL: expected at least one fixture under $FIXTURE_DIR"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: inspected $fixtures_found fixture file(s)"
    PASS=$((PASS + 1))
    if [ "$missing_field" -eq 0 ]; then
      echo "  PASS: every fixture declares save_version"
      PASS=$((PASS + 1))
    else
      FAIL=$((FAIL + missing_field))
    fi
  fi
else
  echo "  FAIL: fixture directory $FIXTURE_DIR missing"
  FAIL=$((FAIL + 1))
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "All ISSUE-011 acceptance criteria validated."
else
  echo "Some checks failed."
  exit 1
fi
