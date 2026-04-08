# Issue 061: Implement PocketCreatures card shop store type

**Wave**: wave-4
**Milestone**: M4 Polish + Replayability
**Labels**: `gameplay`, `store:monster-cards`, `phase:m4plus`, `priority:medium`
**Dependencies**: issue-043

## Why This Matters

PocketCreatures is the most content-rich store and tests data pipeline at scale.

## Scope

PocketCreaturesStoreController extending StoreController. Store scene. Unique mechanic: pack opening. Content: 30+ cards across sets.

## Deliverables

- game/scenes/stores/pocket_creatures.tscn
- PocketCreaturesStoreController.gd
- Pack opening mechanic (buy sealed pack, open for random cards)
- Card singles in binders
- 30+ card item definitions

## Acceptance Criteria

- Store is playable
- Pack opening produces random cards from probability tables
- Singles can be priced and sold individually
- No core system modifications
