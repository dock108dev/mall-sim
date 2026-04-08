# Issue 002: Implement player controller with WASD movement and mouse look

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `phase:m1`, `priority:high`
**Dependencies**: None

## Why This Matters

Player needs to exist in the world to interact with anything.

## Scope

CharacterBody3D with WASD movement, mouse look, gravity, floor snapping. No jumping. Cursor lock on click, unlock on Escape.

## Deliverables

- Player scene at game/scenes/player/player.tscn
- WASD movement at configurable speed
- Mouse look with sensitivity setting
- Gravity and floor snapping
- Cursor lock/unlock toggle

## Acceptance Criteria

- Player moves in 3D space with WASD
- Mouse rotates camera
- Player stays on floor
- Escape frees cursor, click re-locks
- No clipping through walls
