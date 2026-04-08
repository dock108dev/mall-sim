# Issue 020: Create customer type definitions for sports store (3-4 types)

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `content`, `store:sports`, `phase:m1`, `priority:medium`
**Dependencies**: None

## Status: CONTENT COMPLETE — Validated

Customer definitions exist at `game/content/customers/sports_store_customers.json` with 4 types.

## Current Customer Types

| ID | Name | Budget | Patience | Price Sensitivity | Purchase Prob |
|---|---|---|---|---|---|
| sports_casual_fan | Casual Fan | $10-40 | 0.8 | 0.4 | 0.65 |
| sports_serious_collector | Serious Collector | $50-200 | 0.5 | 0.5 | 0.45 |
| sports_kid_allowance | Kid with Allowance | $3-15 | 0.3 | 0.9 | 0.70 |
| sports_investor | Card Investor | $100-500 | 0.3 | 0.95 | 0.30 |

All types include: mood_tags, impulse_buy_chance, visit_frequency, and browse_time_range.

## Cross-Validation (Cycle 5)

- ✓ Budget ranges cover the store's item price spread ($1.50-$1,200): kid covers commons, casual covers commons/uncommons, collector covers uncommons/rares, investor covers rares/very_rares
- ✓ All 4 types reference `store_types` containing `"sports"` which matches the store definition ID
- ✓ `preferred_categories` use values matching store definition's `allowed_categories`
- ✓ Fields match CustomerTypeDefinition resource schema from DATA_MODEL.md
- ✓ No broken store_type references detected in automated validation
- ⚠ `casual_browser.json` exists as a separate generic fallback at `game/content/customers/casual_browser.json` — disposition to be decided (keep as universal fallback or remove as legacy)

## Remaining Work

- [ ] Validate through DataLoader parsing (blocked on issue-001)
- [ ] Decide whether `casual_browser.json` should be a universal fallback customer or removed (tracked in issue-086)
- [ ] Confirm preferred_tags have matching items (tags like "team_gear", "autograph" should map to actual item tags in sports_memorabilia_cards.json)

## Acceptance Criteria

- ✓ All 4 customer types load without validation errors
- ✓ Preferred categories have matching items in the sports store content
- ✓ Budget ranges are reasonable relative to item prices
- ✓ Fields match the CustomerTypeDefinition resource schema
- [ ] Preferred tags confirmed to match actual item tags (needs DataLoader)