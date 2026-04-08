# Issue 052: Implement third store type: video rental

**Wave**: wave-3
**Milestone**: M3 Progression + Content Expansion
**Labels**: `gameplay`, `store:rentals`, `phase:m3`, `priority:medium`
**Dependencies**: issue-042

## Why This Matters

Rental is the most mechanically distinct store type — validates the framework's flexibility.

## Scope

VideoRentalStoreController extending StoreController. Store interior scene. Unique mechanic: rental lifecycle (rent instead of sell). Content: 20+ parody movie titles.

## Deliverables

- game/scenes/stores/video_rental.tscn
- VideoRentalStoreController.gd
- Rental mechanic: items rented, returned after N days, late fees
- game/content/items/video_rental.json with 20+ titles
- Customer types for rental store

## Acceptance Criteria

- Store loads and is playable
- Rental mechanic: items leave and return
- Late fees generate revenue
- No core system modifications required
