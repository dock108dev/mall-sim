# Issue 015: Create starter sports card content set (15-20 items)

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `content`, `store:sports`, `data`, `phase:m1`, `priority:high`
**Dependencies**: issue-001

## Why This Matters

M1 needs enough items to fill shelves and make the store feel real.

## Scope

Create 15-20 sports card item definitions in JSON. Mix of trading cards, autographs, and sealed product. Spread across rarity tiers. Use normalized schema (condition_range, subcategory, base_price).

## Deliverables

- game/content/items/sports_memorabilia.json with 15-20 items
- Mix: ~10 singles, ~3 autographs, ~2 sealed product
- Rarity spread: ~8 common, ~4 uncommon, ~2 rare, ~1 very_rare
- Realistic price range: $2-$500
- All items use normalized schema from DATA_MODEL.md

## Acceptance Criteria

- DataLoader loads all items without warnings
- Items span multiple categories and rarities
- Prices make sense for the item type
- condition_range is appropriate per item
