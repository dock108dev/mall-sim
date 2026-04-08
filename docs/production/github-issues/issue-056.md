# Issue 056: Create video rental content set (20-30 parody titles)

**Wave**: wave-3
**Milestone**: M3 Progression + Content Expansion
**Labels**: `content`, `store:rentals`, `data`, `phase:m3`, `priority:medium`
**Dependencies**: issue-042, issue-016

## Status: CONTENT COMPLETE — Validated

Content exists at `game/content/items/video_rental.json` with 30 items.
Customer types exist at `game/content/customers/video_rental_customers.json` with 4 types.

## Current Content Summary

| Category | Count | Examples |
|---|---|---|
| VHS classics | 10 | Cosmic Battles IV, Velociraptor Gardens, The Grid |
| VHS new releases | 5 | Recent parody titles for the New Releases wall |
| DVD titles | 5 | DVD format variants with higher rental fees |
| Snacks | 5 | Popcorn, candy, soda — register impulse buys |
| Merchandise | 5 | Movie posters, standees, decorative items |

All rental items include `rental_fee`, `rental_period_days`, and `max_rentals` fields.
Price range spans rental-appropriate values.

## Cross-Validation

- ✓ Item categories match store definition's `allowed_categories`
- ✓ Customer preferred_categories match item categories
- ✓ Titles are recognizable parodies but legally distinct
- ✓ Rental pricing makes sense for the rental business model
- ✓ Snacks and merchandise provide non-rental revenue stream
- ✓ All 11 `starting_inventory` IDs from store_definitions.json resolve to items in video_rental.json (verified cycle 26)
- ✓ `store_type: "rentals"` on all items matches store definition ID

## Remaining Work

- [ ] Validate through DataLoader parsing (blocked on issue-001)
- [ ] Remove legacy `game/content/items/video_rental_vhs.json` (single sample item, superseded — covered by issue-086)

## Acceptance Criteria

- ✓ 30 items across multiple categories
- ✓ Titles are recognizable parodies but legally distinct
- ✓ Pricing makes sense for rental model
- ✓ Starting inventory items (11 entries) all resolve to valid items
- ✓ Customer `store_types` arrays reference valid store ID `"rentals"`
- [ ] All items load via DataLoader without warnings (blocked on issue-001)
- [ ] Passes content validation (issue-016)
- [ ] Legacy `video_rental_vhs.json` removed (covered by issue-086)