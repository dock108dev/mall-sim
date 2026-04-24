#!/usr/bin/env bash
# Validates .aidlc/issues/ISSUE-019: StoreRegistry autoload as a runtime cache
# of ContentRegistry (per docs/decisions/0007-remove-sneaker-citadel.md; the
# hardcoded sneaker_citadel seed has been replaced with data-driven seeding).
# (Distinct from tests/validate_issue_019.sh which covers a different issue
# numbering namespace — recommended markup guidance.)
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="$ROOT/game/autoload/store_registry.gd"
ENTRY="$ROOT/game/autoload/store_registry_entry.gd"
PROJECT="$ROOT/project.godot"
TEST="$ROOT/tests/unit/test_store_registry.gd"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-019 (aidlc): StoreRegistry ==="

[ -f "$REGISTRY" ] && pass "exists: game/autoload/store_registry.gd" \
	|| fail "missing: game/autoload/store_registry.gd"

[ -f "$ENTRY" ] && pass "exists: game/autoload/store_registry_entry.gd" \
	|| fail "missing: game/autoload/store_registry_entry.gd"

if grep -q '^StoreRegistry="\*res://game/autoload/store_registry.gd"' "$PROJECT"; then
	pass "registered as autoload in project.godot"
else
	fail "StoreRegistry not registered in [autoload] section"
fi

if grep -Eq 'func resolve\(store_id: StringName\) -> StoreRegistryEntry' "$REGISTRY"; then
	pass "exposes resolve(store_id: StringName) -> StoreRegistryEntry"
else
	fail "resolve(store_id) signature missing or wrong"
fi

if grep -Eq 'func register\(entry: StoreRegistryEntry\)' "$REGISTRY"; then
	pass "exposes register(entry: StoreRegistryEntry)"
else
	fail "register(entry) signature missing"
fi

if grep -q '_seed_from_content_registry' "$REGISTRY"; then
	pass "seeds from ContentRegistry (SSOT: store_definitions.json)"
else
	fail "_seed_from_content_registry missing — registry must be data-driven"
fi

if ! grep -q 'sneaker_citadel' "$REGISTRY"; then
	pass "no hardcoded sneaker_citadel block (removed per ADR 0007)"
else
	fail "sneaker_citadel reference still present — removal incomplete"
fi

if grep -q 'push_error' "$REGISTRY" && grep -q 'unknown store_id' "$REGISTRY"; then
	pass "unknown store_id path emits push_error"
else
	fail "no push_error path for unknown store_id"
fi

if grep -q 'duplicate register' "$REGISTRY"; then
	pass "duplicate-register guard present"
else
	fail "duplicate-register guard missing"
fi

[ -f "$TEST" ] && pass "GUT test exists: tests/unit/test_store_registry.gd" \
	|| fail "missing GUT test tests/unit/test_store_registry.gd"

if grep -q 'test_resolves_all_definitions_from_content_registry' "$TEST"; then
	pass "test covers seeded resolution from ContentRegistry"
else
	fail "test does not cover content-registry-driven seeding"
fi

if grep -q 'bogus_id\|unknown' "$TEST"; then
	pass "test covers unknown id path"
else
	fail "test does not cover unknown id"
fi

if grep -q 'duplicate' "$TEST"; then
	pass "test covers duplicate-register guard"
else
	fail "test does not cover duplicate register"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
