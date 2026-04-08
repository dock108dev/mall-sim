# Issue 067: Create PocketCreatures content set (30-40 cards)

**Wave**: wave-4
**Milestone**: M4 Polish + Replayability
**Labels**: `content`, `store:monster-cards`, `data`, `phase:m4plus`, `priority:medium`
**Dependencies**: issue-043, issue-016

## Status: CONTENT COMPLETE — 38 items, validated

Content exists at `game/content/items/pocket_creatures.json` with 38 items.
Customer types exist at `game/content/customers/pocket_creatures_customers.json` with 5 types.

## Current Content Summary

38 items across singles, booster packs, sealed boxes, starter decks, and accessories.
Multiple sets and rarity tiers represented.
Card-specific metadata included (type, set, element where applicable).

## Cross-Validation

- ✓ Item count (38) within target range (30-40)
- ✓ Multiple sets represented (Base Set, Jungle, Neo Genesis)
- ✓ Rarity spread covers all tiers (common through legendary)
- ✓ Sealed products present for pack-opening mechanic
- ✓ Customer types (5) cover competitive player, collector, pack cracker, parent, trader
- ✓ Matches issue-001 expected count of 38
- ✓ All 15 unique `starting_inventory` IDs from store_definitions.json resolve to items in this file
- ✓ `store_type: "pocket_creatures"` on all items matches store definition ID
- ✓ Item categories match store definition's `allowed_categories`: booster_packs, singles, sealed_product, starter_decks, accessories

## Remaining Work

- [ ] Validate through DataLoader parsing (blocked on issue-001)
- [ ] Confirm sealed products have `appreciates: true`

## Acceptance Criteria

- ✓ 38 items defined in `pocket_creatures.json` (within 30-40 target range)
- ✓ Items span booster packs, singles, sealed product, starter decks, and accessories
- ✓ Multiple sets represented (Base Set, Jungle, Neo Genesis)
- ✓ Rarity distribution includes all 5 tiers
- ✓ Starting inventory items (23 entries, 15 unique IDs) all resolve to valid items
- ✓ Customer types (5) match all archetypes from POCKETCREATURES.md deep dive
- ✓ Customer `store_types` arrays reference valid store ID `"pocket_creatures"`
- [ ] All items load via DataLoader without warnings (blocked on issue-001)
- [ ] Sealed products confirmed to have `appreciates: true`
- [ ] Passes content validation (issue-016)