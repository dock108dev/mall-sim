# Issue 068: Create electronics content set (20-25 items)

**Wave**: wave-4
**Milestone**: M4 Polish + Replayability
**Labels**: `content`, `store:electronics`, `data`, `phase:m4plus`, `priority:medium`
**Dependencies**: issue-044, issue-016

## Status: CONTENT COMPLETE — 28 items, validated

Content exists at `game/content/items/consumer_electronics.json` with 28 items.
Customer types exist at `game/content/customers/electronics_customers.json` with 4 types.

## Current Content Summary

28 items across portable audio, portable gaming, digital cameras, PDAs, headphones, gadgets, and accessories.
All appropriate items include `depreciates: true`.
Price ranges fit 2000s-era electronics ($5-$300).

## Cross-Validation

- ✓ Item count (28) exceeds target range (20-25)
- ✓ 5+ product categories represented (portable_audio, handheld_gaming, audio, gadgets, accessories)
- ✓ Customer types (4) cover early adopter, bargain hunter, gift buyer, tech enthusiast
- ✓ Depreciation flags set on electronics items
- ✓ Matches issue-001 expected count of 28
- ✓ All 13 `starting_inventory` IDs from store_definitions.json resolve to items in this file
- ✓ `store_type: "electronics"` on all items matches store definition ID
- ✓ Item categories match store definition's `allowed_categories`: portable_audio, handheld_gaming, audio, gadgets, accessories

## Remaining Work

- [ ] Validate through DataLoader parsing (blocked on issue-001)
- [ ] Confirm accessories depreciate slower than main electronics
- [ ] Remove legacy `game/content/items/electronics_mp3_player.json` (covered by issue-086)

## Acceptance Criteria

- ✓ 28 items defined in `consumer_electronics.json` (exceeds 20-25 target range)
- ✓ Items span portable audio, handheld gaming, cameras, PDAs, headphones, gadgets, and accessories
- ✓ All appropriate items include `depreciates: true`
- ✓ Price range ($5-$300) appropriate for 2000s-era electronics
- ✓ Starting inventory items (13 entries) all resolve to valid items
- ✓ Customer types (4) match all archetypes from ELECTRONICS.md deep dive
- ✓ Customer `store_types` arrays reference valid store ID `"electronics"`
- [ ] All items load via DataLoader without warnings (blocked on issue-001)
- [ ] Accessories confirmed to depreciate slower than main electronics
- [ ] Legacy `electronics_mp3_player.json` removed (covered by issue-086)
- [ ] Passes content validation (issue-016)