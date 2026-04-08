# Issue 003: Implement interaction raycast and context-sensitive prompt

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `phase:m1`, `priority:high`
**Dependencies**: issue-002

## Why This Matters

Interaction is how the player touches every game system — shelves, register, items.

## Scope

Forward-facing raycast (~2m range) detects Interactable nodes. Shows 'Press E to [action]' prompt on HUD. E key triggers interaction via EventBus signal.

## Deliverables

- InteractionRay on player camera
- HUD prompt label shows/hides based on raycast target
- EventBus.player_interacted signal emitted on E press
- Interactable base class used for detection (already exists)

## Acceptance Criteria

- Aim at interactable: prompt appears
- Aim away: prompt disappears
- Press E while aiming: interaction signal fires
- Works at ~2m range, not further
