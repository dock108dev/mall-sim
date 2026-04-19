#!/usr/bin/env bash
# Validates ISSUE-007: Add per-store SFX and interaction sound effects
set -euo pipefail

PASS=0
FAIL=0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== ISSUE-007: Add per-store SFX and interaction sound effects ==="
echo ""

# --- AC1: At least 7 new SFX files exist in game/assets/audio/sfx/ ---
echo "[AC1] At least 7 new SFX files in game/assets/audio/sfx/"

NEW_SFX=(
    haggle_accept.wav
    haggle_reject.wav
    build_place.wav
    build_error.wav
    pack_opening.wav
    refurbish_start.wav
    refurbish_complete.wav
    tape_insert.wav
    auth_reveal.wav
    demo_activate.wav
)

NEW_COUNT=0
for sfx in "${NEW_SFX[@]}"; do
    if [ -f "$ROOT/game/assets/audio/sfx/$sfx" ]; then
        NEW_COUNT=$((NEW_COUNT + 1))
        pass "SFX file exists: $sfx"
    else
        fail "SFX file missing: $sfx"
    fi
done

if [ "$NEW_COUNT" -ge 7 ]; then
    pass "At least 7 new SFX files present ($NEW_COUNT total)"
else
    fail "Only $NEW_COUNT new SFX files (need at least 7)"
fi

# --- AC2: Each store type has at least 1 unique interaction SFX ---
echo ""
echo "[AC2] Each store type has at least 1 unique interaction SFX"

AUDIO_MGR="$ROOT/game/autoload/audio_manager.gd"
# Audio keys live in the registry JSON; signal wiring lives in the event handler.
AUDIO_REG="$ROOT/game/content/audio_registry.json"
AUDIO_EVT="$ROOT/game/autoload/audio_event_handler.gd"

# Sports Memorabilia -> auth_reveal
if grep -q 'auth_reveal' "$AUDIO_REG" || grep -q 'auth_reveal' "$AUDIO_EVT"; then
    pass "Sports Memorabilia has auth_reveal SFX"
else
    fail "Sports Memorabilia missing unique SFX"
fi

# Retro Games -> refurbish_start / refurbish_complete
if grep -q 'refurbish_start\|refurbish_complete' "$AUDIO_REG" || grep -q 'refurbish_start\|refurbish_complete' "$AUDIO_EVT"; then
    pass "Retro Games has refurbishment SFX"
else
    fail "Retro Games missing unique SFX"
fi

# Video Rental -> tape_insert
if grep -q 'tape_insert' "$AUDIO_REG" || grep -q 'tape_insert' "$AUDIO_EVT"; then
    pass "Video Rental has tape_insert SFX"
else
    fail "Video Rental missing unique SFX"
fi

# PocketCreatures -> pack_opening
if grep -q 'pack_opening' "$AUDIO_REG" || grep -q 'pack_opening' "$AUDIO_EVT"; then
    pass "PocketCreatures has pack_opening SFX"
else
    fail "PocketCreatures missing unique SFX"
fi

# Consumer Electronics -> demo_activate
if grep -q 'demo_activate' "$AUDIO_REG" || grep -q 'demo_activate' "$AUDIO_EVT"; then
    pass "Consumer Electronics has demo_activate SFX"
else
    fail "Consumer Electronics missing unique SFX"
fi

# --- AC3: SFX are wired to relevant EventBus signals via AudioManager ---
echo ""
echo "[AC3] SFX wired to EventBus signals in AudioManager"

SIGNAL_WIRING=(
    "haggle_completed"
    "haggle_failed"
    "fixture_placed"
    "fixture_placement_invalid"
    "pack_opened"
    "refurbishment_started"
    "refurbishment_completed"
    "item_rented"
    "authentication_completed"
    "demo_item_placed"
)

for sig in "${SIGNAL_WIRING[@]}"; do
    if grep -q "EventBus\\.${sig}\\.connect" "$AUDIO_MGR" || grep -q "EventBus\\.${sig}\\.connect" "$AUDIO_EVT"; then
        pass "EventBus.$sig connected in AudioManager"
    else
        fail "EventBus.$sig not connected in AudioManager"
    fi
done

# --- AC4: Haggle accept and reject have distinct sounds ---
echo ""
echo "[AC4] Haggle accept and reject have distinct sounds"

if (grep -q 'haggle_accept' "$AUDIO_REG" || grep -q 'haggle_accept' "$AUDIO_EVT") && \
   (grep -q 'haggle_reject' "$AUDIO_REG" || grep -q 'haggle_reject' "$AUDIO_EVT"); then
    pass "Haggle accept and reject use distinct SFX names"
else
    fail "Haggle sounds not distinct"
fi

if [ -f "$ROOT/game/assets/audio/sfx/haggle_accept.wav" ] && \
   [ -f "$ROOT/game/assets/audio/sfx/haggle_reject.wav" ]; then
    ACCEPT_SIZE=$(stat -f%z "$ROOT/game/assets/audio/sfx/haggle_accept.wav" 2>/dev/null || \
                  stat -c%s "$ROOT/game/assets/audio/sfx/haggle_accept.wav" 2>/dev/null)
    REJECT_SIZE=$(stat -f%z "$ROOT/game/assets/audio/sfx/haggle_reject.wav" 2>/dev/null || \
                  stat -c%s "$ROOT/game/assets/audio/sfx/haggle_reject.wav" 2>/dev/null)
    if [ "$ACCEPT_SIZE" != "$REJECT_SIZE" ]; then
        pass "haggle_accept.wav and haggle_reject.wav are distinct files"
    else
        fail "haggle_accept.wav and haggle_reject.wav appear identical"
    fi
else
    fail "One or both haggle SFX files missing"
fi

# --- AC5: Build mode has placement success and error sounds ---
echo ""
echo "[AC5] Build mode has placement success and error sounds"

if (grep -q 'build_place' "$AUDIO_REG" || grep -q 'build_place' "$AUDIO_EVT") && \
   (grep -q 'build_error' "$AUDIO_REG" || grep -q 'build_error' "$AUDIO_EVT"); then
    pass "Build mode has distinct place and error SFX"
else
    fail "Build mode missing distinct SFX"
fi

# --- AC6: All SFX preloaded in AudioManager ---
echo ""
echo "[AC6] All new SFX are preloaded in AudioManager"

SFX_KEYS=(
    haggle_accept
    haggle_reject
    build_place
    build_error
    pack_opening
    refurbish_start
    refurbish_complete
    tape_insert
    auth_reveal
    demo_activate
)

for key in "${SFX_KEYS[@]}"; do
    if grep -q "\"${key}\"" "$AUDIO_REG" || grep -q "\"${key}\"" "$AUDIO_EVT" || grep -q "\"${key}\"" "$AUDIO_MGR"; then
        pass "SFX key '$key' registered in AudioManager"
    else
        fail "SFX key '$key' not registered in AudioManager"
    fi
done

# --- AC7: WAV files are valid (check RIFF header) ---
echo ""
echo "[AC7] WAV files have valid headers"

for sfx in "${NEW_SFX[@]}"; do
    FILEPATH="$ROOT/game/assets/audio/sfx/$sfx"
    if [ -f "$FILEPATH" ]; then
        HEADER=$(head -c 4 "$FILEPATH")
        if [ "$HEADER" = "RIFF" ]; then
            pass "$sfx has valid RIFF header"
        else
            fail "$sfx has invalid header"
        fi
    fi
done

# --- Summary ---
echo ""
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi

echo ""
echo "All ISSUE-007 acceptance criteria validated."
exit 0
