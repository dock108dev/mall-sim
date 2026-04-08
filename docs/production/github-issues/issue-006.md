# Issue 006: Implement shelf interaction and item placement flow

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `ui`, `phase:m1`, `priority:high`
**Dependencies**: issue-003, issue-004, issue-005

## Why This Matters

Stocking shelves is the primary player action in the daily loop.

## Scope

Player interacts with shelf to open placement UI. Select item from backroom list. Place on shelf slot. Item appears on shelf (placeholder mesh). Remove item from shelf back to backroom.

## Deliverables

- Shelf interaction opens inventory panel filtered to backroom items
- Click item in panel to place on shelf slot
- Placed item shows as colored BoxMesh on shelf
- Right-click or interact with placed item to return to backroom
- Shelf capacity enforced (can't place on full shelf)

## Acceptance Criteria

- Interact with empty shelf slot: shows backroom items
- Select item: it appears on shelf, removed from backroom
- Interact with stocked item: returns to backroom
- Full shelf rejects placement
