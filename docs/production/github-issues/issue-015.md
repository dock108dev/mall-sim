# Issue 015: Create starter sports card content set (15-20 items)

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `content`, `store:sports`, `data`, `phase:m1`, `priority:medium`
**Dependencies**: None

## Status: CONTENT COMPLETE — 19 items, validated

Content exists at `game/content/items/sports_memorabilia_cards.json` with 19 items.

## Current Content Summary

| Category | Subcategory | Count | Rarity Spread | Price Range |
|---|---|---|---|---|
| trading_cards | singles | 9 | 3 common, 3 uncommon, 2 rare, 1 very_rare | $1.50–$450 |
| sealed_packs | sealed | 4 | 2 common, 1 uncommon, 1 rare | $3–$85 |
| memorabilia | autographs | 2 | 1 rare, 1 very_rare | $25–$350 |
| memorabilia | equipment | 1 | common | $15 |
| memorabilia | jerseys | 1 | legendary | $1,200 |
| memorabilia | display | 2 | 1 uncommon, 1 rare | $35–$75 |

All items use `store_type: "sports"` matching the store definition ID.

## Cross-Validation

- ✓ 19 items within target range of 15-20
- ✓ All categories match store definition's `allowed_categories`: `["trading_cards", "sealed_packs", "memorabilia"]`
- ✓ All 9 `starting_inventory` IDs from store_definitions.json resolve to items in this file
- ✓ Rarity spread covers common through legendary
- ✓ Price range ($1.50–$1,200) provides meaningful decisions for all customer budget ranges
- ✓ 4 items have `appreciates: true` (sealed packs and the Mantle card)
- ✓ Tags include values matching customer preferred_tags ("rookie", "team_gear", "autograph", etc.)

## Remaining Work

- [ ] Validate through DataLoader parsing (blocked on issue-001)
- [ ] Verify condition_range arrays are appropriate per item type

## Acceptance Criteria

- ✓ 19 items defined in `sports_memorabilia_cards.json`
- ✓ Items span trading cards, sealed product, and memorabilia categories
- ✓ Rarity distribution includes all 5 tiers
- ✓ Starting inventory items are included
- [ ] All items load via DataLoader without warnings (blocked on issue-001)
- [ ] Passes content validation (issue-016)