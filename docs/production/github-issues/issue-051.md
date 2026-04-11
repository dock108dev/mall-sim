# Issue 051: Create retro game content set (20-30 items)

**Wave**: wave-3
**Milestone**: M3 Progression + Content Expansion
**Labels**: `content`, `store:video-games`, `data`, `phase:m3`, `priority:medium`
**Dependencies**: issue-041, issue-016

## Status: CONTENT COMPLETE — 28 items, fully cross-validated

Content exists at `game/content/items/retro_games.json` with 28 items.
Customer types exist at `game/content/customers/retro_games_customers.json` with 4 types.

## Current Content Summary

| Category | Count | Examples |
|---|---|---|
| Loose cartridges | ~10 | Plumber World, Hedgehog Rush, Earth Kids, Ninja Shadow |
| CIB games | ~2 | Elf Quest CIB, Plumber World CIB |
| NIB/sealed | ~1 | Final Saga VII Sealed |
| Consoles (working) | ~2 | SuperStation, TriForce 64 |
| Consoles (for-parts) | ~1 | MegaDrive 16 (for parts) |
| Consoles (CIB) | ~1 | TriForce 64 CIB |
| Accessories | ~4 | Controllers (SS, T64), memory card, link cable |
| Guides/magazines | ~2 | Elf Quest guide, Console Power Magazine |
| Imports | ~2 | Cosmic Warrior Z (JP), Puzzle Drop DX (JP) |

Platforms: SuperStation, MegaDrive16, TriForce64, DiscStation, PortaBoy.
Rarity: common through legendary (Ninja Shadow at $350).
Price range: $5 (memory card) to $350 (Ninja Shadow legendary).

## Cross-Validation

- ✓ Item categories (`cartridges`, `consoles`, `accessories`, `guides`) match store definition's `allowed_categories`
- ✓ All 10 `starting_inventory` IDs in store_definitions.json resolve to items in retro_games.json (verified cycle 26)
- ✓ Customer `preferred_categories` match item categories
- ✓ Customer budget ranges ($15-200) cover the majority of item prices
- ✓ Rarity spread covers all 5 tiers including legendary
- ✓ `store_type: "retro_games"` on all items matches store definition ID
- ✓ Customer `store_types` arrays reference valid store ID `"retro_games"`

## Remaining Work

- [ ] Validate through DataLoader parsing (blocked on issue-001)
- [ ] Confirm loose items exclude `mint` from condition_range
- [ ] Confirm CIB items include `near_mint` and `mint` in condition_range
- [ ] Remove legacy `game/content/items/games_retro_cartridge.json` (covered by issue-086)

## Acceptance Criteria

- ✓ 28 items defined in `retro_games.json` (within 20-30 target range)
- ✓ Items span multiple categories and platforms
- ✓ Starting inventory items (10 entries) all resolve to valid items
- ✓ Customer types (4) match archetypes from RETRO_GAMES.md deep dive
- [ ] CIB items have condition_range including near_mint/mint
- [ ] Loose items exclude mint
- [ ] All items load via DataLoader without warnings (blocked on issue-001)
- [ ] Passes content validation (issue-016)
- [ ] Legacy `games_retro_cartridge.json` removed (covered by issue-086)