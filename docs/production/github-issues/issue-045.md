# Issue 045: Implement second store type: retro game store

**Wave**: wave-3
**Milestone**: M3 Progression + Content Expansion
**Labels**: `gameplay`, `store:video-games`, `phase:m3`, `priority:high`
**Dependencies**: issue-041, issue-006, issue-011

## Why This Matters

Second store proves the modular architecture works. If it requires core changes, architecture needs fixing.

## Scope

RetroGameStoreController extending StoreController. Store interior scene. Unique mechanic: testing station. Content: 20+ retro game items.

## Deliverables

- game/scenes/stores/retro_games.tscn
- RetroGameStoreController.gd
- Testing station mechanic (customer tests before buying, increases conversion)
- game/content/items/retro_games.json with 20+ items
- Customer types for retro store

## Acceptance Criteria

- Store loads and is playable
- No core system modifications required
- Testing station mechanic works
- Different customer types appear
- Architecture validation: adding this store didn't break sports store
