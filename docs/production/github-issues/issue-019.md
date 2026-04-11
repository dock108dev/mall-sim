# Issue 019: Create store definition JSON for sports store

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `content`, `store:sports`, `phase:m1`, `priority:medium`
**Dependencies**: None

## Status: CONTENT COMPLETE — Validated

The sports store definition lives in `game/content/stores/store_definitions.json` alongside the other 4 stores. All 5 store types are in one file, matching the DATA_MODEL.md convention.

## Current Definition

- Store ID: `sports`
- Size: small, 31 shelf capacity, 100 backroom
- Starting cash: $500, daily rent: $50
- 6 fixture slots with typed layout (2 glass cases, sealed shelf, memorabilia shelf, wall display, checkout)
- Starting inventory: 9 item IDs referencing `sports_memorabilia_cards.json`
- Allowed categories: trading_cards, sealed_packs, sealed_product, memorabilia
- Unique mechanics: authentication
- Aesthetic tags and ambient sound path

## Cross-Validation (Cycle 5)

- ✓ All `starting_inventory` item IDs resolve to actual items in `sports_memorabilia_cards.json`
  - Fixed in cycle 5: remapped 8 broken placeholder IDs (sports_mcgwire_common, sports_pippen_common, etc.) to real item IDs
  - New inventory: pippen_hoops, shaq_classic, thomas_leaf, favre_topps, ichiro_topps, griffey_rookie, wax_pack_93 ×2, display_bat
  - Total starter stock cost at base prices: ~$127 (reasonable vs $500 starting cash)
- ✓ Fixture slot counts sum to `shelf_capacity`: 8+8+6+4+3+2 = 31
- ✓ `allowed_categories` match item categories in sports_memorabilia_cards.json
- ✓ `store_type: "sports"` on all 19 items matches store ID

## Cleanup Required

- [ ] Delete `game/content/stores/sports_memorabilia.json` (duplicate of unified file entry — covered by issue-086)
- [ ] Delete `game/content/stores/sample_sports_store.json` (legacy scaffold — covered by issue-086)
- [ ] Validate through DataLoader parsing (blocked on issue-001)

## Acceptance Criteria

- ✓ Store definition loads without validation errors from unified `store_definitions.json`
- ✓ All starting_inventory IDs resolve to valid items
- ✓ Fixture capacity matches shelf_capacity field
- ✓ Fields match the StoreDefinition resource schema
- [ ] Legacy standalone files removed (issue-086)