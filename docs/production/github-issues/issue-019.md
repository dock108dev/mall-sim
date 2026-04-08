# Issue 019: Create store definition JSON for sports store

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `content`, `data`, `store:sports`, `phase:m1`, `priority:medium`
**Dependencies**: issue-001

## Why This Matters

Store definitions drive what items are allowed where and what mechanics are available.

## Scope

Expand the sample sports store JSON to a full store definition with allowed categories, fixture slots, starting inventory references, supplier tier info.

## Deliverables

- game/content/stores/sports_store.json fully populated
- Includes: allowed_categories, fixture_slots, backroom_capacity, starting_budget, starting_inventory item IDs, unique_mechanics list

## Acceptance Criteria

- DataLoader loads store definition without errors
- Starting inventory references exist in items JSON
- allowed_categories match items in sports_memorabilia.json
