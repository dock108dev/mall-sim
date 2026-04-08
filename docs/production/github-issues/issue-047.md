# Issue 047: Implement build mode prototype

**Wave**: wave-3
**Milestone**: M3 Progression + Content Expansion
**Labels**: `gameplay`, `phase:m3`, `priority:medium`
**Dependencies**: issue-004

## Why This Matters

Store customization is a core fantasy — making the space 'yours'.

## Scope

Toggle build mode with B key. Top-down camera. Grid overlay. Place/move shelf fixtures. Exit returns to first-person. Customer pathfinding adapts to layout.

## Deliverables

- Build mode toggle (B key)
- Camera switches to top-down/orbit
- Grid overlay showing valid placement cells
- Place new fixtures from catalog
- Move/rotate existing fixtures
- NavMesh rebake on layout change
- Exit returns to player controller

## Acceptance Criteria

- B enters build mode, B exits
- Can place a new shelf
- Can move existing shelf
- Customers navigate new layout
- Layout persists between days
