#!/usr/bin/env bash
# Validation for ISSUE-008: Add per-store background music tracks
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
check() { if eval "$1" 2>/dev/null; then pass "$2"; else fail "$2"; fi; }

echo "=== ISSUE-008: Add per-store background music tracks ==="
echo ""

# AC1: At least 1 new gameplay music track in game/assets/audio/music/
echo "[AC1] New gameplay music tracks in game/assets/audio/music/"
MUSIC_DIR="$ROOT/game/assets/audio/music"
check "[ -f '$MUSIC_DIR/mall_hallway_music.wav' ]" "mall_hallway_music.wav exists"
check "[ -f '$MUSIC_DIR/sports_store_music.wav' ]" "sports_store_music.wav exists"
check "[ -f '$MUSIC_DIR/retro_games_music.wav' ]" "retro_games_music.wav exists"
check "[ -f '$MUSIC_DIR/video_rental_music.wav' ]" "video_rental_music.wav exists"
check "[ -f '$MUSIC_DIR/card_shop_music.wav' ]" "card_shop_music.wav exists"
check "[ -f '$MUSIC_DIR/electronics_store_music.wav' ]" "electronics_store_music.wav exists"

# Verify WAV headers
echo ""
echo "[AC1b] WAV files have valid RIFF headers"
for wav in mall_hallway_music sports_store_music retro_games_music video_rental_music card_shop_music electronics_store_music; do
    check "head -c4 '$MUSIC_DIR/${wav}.wav' | grep -q RIFF" "${wav}.wav has valid RIFF header"
done

# AC2: Music changes when entering/exiting stores (crossfade via AudioManager)
echo ""
echo "[AC2] Music changes on store entry/exit via AudioManager"
AM="$ROOT/game/autoload/audio_manager.gd"
check "grep -q 'storefront_entered.connect' '$AM'" "AudioManager connects to storefront_entered"
check "grep -q 'storefront_exited.connect' '$AM'" "AudioManager connects to storefront_exited"
check "grep -q '_play_store_music_for' '$AM'" "AudioManager has _play_store_music_for method"
check "grep -q 'store_def.music' '$AM'" "AudioManager reads store_def.music field"
check "grep -q '_crossfade_to' '$AM'" "AudioManager uses crossfade for music transitions"

# AC3: Music loops seamlessly (restart on finished signal)
echo ""
echo "[AC3] Music loops seamlessly"
check "grep -q '_on_music_finished' '$AM'" "Music finished callback exists"
check "grep -q 'player.play()' '$AM'" "Music player restarts on finish"

# AC4: Music volume does not overwhelm SFX or ambiance
echo ""
echo "[AC4] Music volume attenuated to not overwhelm SFX/ambiance"
check "grep -q 'MUSIC_VOLUME_DB' '$AM'" "MUSIC_VOLUME_DB constant defined"
check "grep -q 'MUSIC_VOLUME_DB.*=.*-' '$AM'" "MUSIC_VOLUME_DB is negative (attenuated)"
check "grep -q 'db_to_linear(MUSIC_VOLUME_DB)' '$AM'" "Crossfade uses MUSIC_VOLUME_DB"

# AC5: Mall hallway has its own music distinct from store interiors
echo ""
echo "[AC5] Mall hallway has distinct music"
check "grep -q 'mall_hallway_music' '$AM'" "mall_hallway_music referenced in AudioManager"
check "grep -q 'play_music(\"mall_hallway_music\")' '$AM'" "Mall hallway music played on store exit"
# Verify it's not using menu_music for gameplay
check "! grep -q '_on_storefront_exited.*menu_music' '$AM'" "Store exit does not fall back to menu_music"

# StoreDefinition has music field
echo ""
echo "[AC-extra] StoreDefinition and data pipeline"
SD="$ROOT/game/resources/store_definition.gd"
check "grep -q 'var music: String' '$SD'" "StoreDefinition has music field"

DL="$ROOT/game/scripts/data_loader.gd"
check "grep -q 'store.music' '$DL'" "DataLoader parses music field"

# Store definitions JSON has music paths
JSON="$ROOT/game/content/stores/store_definitions.json"
check "grep -q '\"music\"' '$JSON'" "store_definitions.json has music field"
check "grep -c '\"music\"' '$JSON' | grep -q '5'" "All 5 stores have music field"

echo ""
echo "=== Results: $PASS/$((PASS+FAIL)) passed, $FAIL failed ==="
echo ""
if [ $FAIL -eq 0 ]; then
    echo "All ISSUE-008 acceptance criteria validated."
else
    echo "Some checks failed."
    exit 1
fi
