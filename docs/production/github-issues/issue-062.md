# Issue 062: Implement consumer electronics store type

**Wave**: wave-4
**Milestone**: M4 Polish + Replayability
**Labels**: `gameplay`, `store:electronics`, `phase:m4plus`, `priority:medium`
**Dependencies**: issue-044

## Why This Matters

Electronics is the anti-collectible — depreciation is a new economic axis.

## Scope

ElectronicsStoreController extending StoreController. Store scene. Unique mechanic: product depreciation + demo units. Content: 20+ electronics items.

## Deliverables

- game/scenes/stores/consumer_electronics.tscn
- ElectronicsStoreController.gd
- Depreciation mechanic (value drops over time for electronics)
- Demo unit mechanic (sacrifice one item for category sales boost)
- 20+ electronics item definitions

## Acceptance Criteria

- Store is playable
- Items depreciate over game days
- Demo unit placement boosts relevant category sales
- No core system modifications
