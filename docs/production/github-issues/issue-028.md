# Issue 028: Implement basic audio system with SFX and ambient

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `audio`, `phase:m2`, `priority:medium`
**Dependencies**: None

## Why This Matters

Audio feedback makes sales satisfying and the mall feel alive.

## Scope

AudioManager plays SFX (register chime, door bell) and background music (mall ambient loop). Audio buses for master/music/sfx. play_sfx(name) API.

## Deliverables

- AudioManager.play_sfx(sfx_name) method
- Background music loop (placeholder track)
- Audio buses: Master, Music, SFX
- Purchase SFX on item_sold signal
- Door SFX on store enter/exit
- Ambient mall background

## Acceptance Criteria

- Sale triggers register sound
- Background music plays on game start
- Volume sliders affect correct buses
- No audio glitches or overlaps
