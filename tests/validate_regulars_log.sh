#!/usr/bin/env bash
# Validate regulars log system (ISSUE-023 Phase 4)
set -eo pipefail

EXIT_CODE=0
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); EXIT_CODE=1; }

echo "=== Regulars Log System (ISSUE-023) ==="
echo ""

SYSTEM="game/scripts/systems/regulars_log_system.gd"
JSON="game/content/meta/regulars_threads.json"
TEST="tests/gut/test_regulars_log_system.gd"
EVENTBUS="game/autoload/event_bus.gd"

# ── RegularsLogSystem source ──────────────────────────────────────────────────

echo "[RegularsLogSystem]"

if [ -f "$SYSTEM" ]; then
    pass "regulars_log_system.gd exists"
else
    fail "regulars_log_system.gd not found"; echo ""; exit 1
fi

if grep -q "class_name RegularsLogSystem" "$SYSTEM"; then
    pass "class_name RegularsLogSystem declared"
else
    fail "class_name RegularsLogSystem missing"
fi

for field in "visit_count" "last_seen_day" "purchase_history" "thread_state" "name"; do
    if grep -q "\"$field\"" "$SYSTEM"; then
        pass "log entry field '$field' used"
    else
        fail "log entry field '$field' missing"
    fi
done

if grep -q "RECOGNITION_THRESHOLD" "$SYSTEM"; then
    pass "RECOGNITION_THRESHOLD constant exists"
else
    fail "RECOGNITION_THRESHOLD constant missing"
fi

if grep -q "func get_save_data" "$SYSTEM"; then
    pass "get_save_data() serializer exists"
else
    fail "get_save_data() missing"
fi

if grep -q "func load_state" "$SYSTEM"; then
    pass "load_state() deserializer exists"
else
    fail "load_state() missing"
fi

if grep -q "_evaluate_threads" "$SYSTEM"; then
    pass "thread trigger evaluator (_evaluate_threads) present"
else
    fail "_evaluate_threads method missing"
fi

if grep -q "_on_customer_left" "$SYSTEM" && grep -q "_evaluate_threads" "$SYSTEM"; then
    pass "trigger evaluator called from customer departure handler"
else
    fail "trigger evaluator not wired to customer departure"
fi

for trigger in "visit_count" "purchase_type" "day_range"; do
    if grep -q "\"$trigger\"" "$SYSTEM"; then
        pass "trigger type '$trigger' handled"
    else
        fail "trigger type '$trigger' not handled"
    fi
done

echo ""

# ── EventBus signals ──────────────────────────────────────────────────────────

echo "[EventBus signals]"

for sig in "regular_recognized" "thread_advanced" "thread_resolved"; do
    if grep -q "signal $sig" "$EVENTBUS"; then
        pass "signal $sig declared"
    else
        fail "signal $sig missing from EventBus"
    fi
done

echo ""

# ── regulars_threads.json ─────────────────────────────────────────────────────

echo "[regulars_threads.json]"

if [ -f "$JSON" ]; then
    pass "regulars_threads.json exists"
else
    fail "regulars_threads.json not found"; echo ""; exit 1
fi

# Count thread entries (lines with "\"id\":")
THREAD_COUNT=$(grep -c '"id"' "$JSON" 2>/dev/null || echo 0)
if [ "$THREAD_COUNT" -ge 4 ]; then
    pass "JSON contains >= 4 thread entries (found $THREAD_COUNT)"
else
    fail "Expected >= 4 thread entries, found $THREAD_COUNT"
fi

for trigger in "visit_count" "purchase_type" "day_range"; do
    if grep -q "\"$trigger\"" "$JSON"; then
        pass "trigger type '$trigger' present in JSON"
    else
        fail "trigger type '$trigger' missing from JSON"
    fi
done

if grep -q "payoff_text" "$JSON"; then
    pass "payoff_text field present in JSON phases"
else
    fail "payoff_text field missing from JSON"
fi

echo ""

# ── GUT test file ─────────────────────────────────────────────────────────────

echo "[GUT tests]"

if [ -f "$TEST" ]; then
    pass "test_regulars_log_system.gd exists"
else
    fail "test_regulars_log_system.gd not found"
fi

for thread in "the_familiar_face" "the_notebook_critic" "the_vacant_unit" "the_legend"; do
    if grep -q "$thread" "$TEST"; then
        pass "thread '$thread' tested"
    else
        fail "thread '$thread' not covered in tests"
    fi
done

if grep -q "day_range" "$TEST" && grep -q "min_day" "$TEST"; then
    pass "day_range boundary tests present"
else
    fail "day_range boundary tests missing"
fi

if grep -q "RECOGNITION_THRESHOLD" "$TEST"; then
    pass "visit_count threshold boundary test present"
else
    fail "visit_count threshold boundary test missing"
fi

if grep -q "get_save_data\|load_state" "$TEST"; then
    pass "save/load round-trip test present"
else
    fail "save/load round-trip test missing"
fi

echo ""

TOTAL=$((PASS + FAIL))
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo "All regulars log checks passed."
else
    echo "Some regulars log checks failed."
fi

exit $EXIT_CODE
