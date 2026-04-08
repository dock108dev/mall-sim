# Issue 004: Create sports store interior scene with placeholder geometry

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `art`, `store:sports`, `phase:m1`, `priority:high`
**Dependencies**: None

## Why This Matters

The store is where the entire game happens. M1 needs one playable store.

## Scope

One store interior scene with 4-6 shelf units, 1 checkout counter, 1 door/entrance trigger, basic lighting. All placeholder geometry (BoxMesh, colored materials). Shelves have defined item slots (Area3D per slot).

## Deliverables

- game/scenes/stores/sports_memorabilia.tscn
- 4-6 ShelfNode instances with item slot Area3Ds
- RegisterArea with customer waiting position
- DoorTrigger Area3D for entrance
- Basic warm fluorescent lighting
- NavigationRegion3D with baked navmesh

## Acceptance Criteria

- Scene loads without errors
- Player can walk around the interior
- Shelf slots are clickable interactables
- Navmesh covers walkable floor area
- Lighting feels like a small retail space
