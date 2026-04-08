# Issue 086: Remove legacy single-item scaffold JSON files

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `tech`, `data`, `phase:m1`, `priority:low`
**Dependencies**: issue-001

## Why This Matters

The original Phase 0 scaffolding created single-item sample JSON files. These have been superseded by full content sets but still exist on disk. DataLoader (issue-001) will skip these files with warnings, but they should be removed to keep the content directory clean and avoid confusion.

## Dependency Note

This issue now depends on issue-001 because DataLoader must be implemented and confirmed working with the real content files before legacy files are deleted. This ensures we don't accidentally remove anything DataLoader needs.

## Files to Remove

### Items (single-item scaffolds, superseded by full content sets)

| File | Superseded By | Notes |
|---|---|---|
| `game/content/items/sports_baseball_card.json` | `sports_memorabilia_cards.json` (19 items) | Single sample card |
| `game/content/items/games_retro_cartridge.json` | `retro_games.json` (28 items) | Single sample cartridge |
| `game/content/items/electronics_mp3_player.json` | `consumer_electronics.json` (28 items) | Single sample MP3 player |
| `game/content/items/fakemon_booster.json` | `pocket_creatures.json` (38 items) | Single sample booster |
| `game/content/items/video_rental_vhs.json` | `video_rental.json` (30 items) | Single sample VHS tape |

### Stores (standalone files, now merged into unified store_definitions.json)

| File | Superseded By | Notes |
|---|---|---|
| `game/content/stores/sample_sports_store.json` | `store_definitions.json` | Legacy Phase 0 scaffold with different schema |
| `game/content/stores/sports_memorabilia.json` | `store_definitions.json` | Duplicate of sports entry in unified file |

### Customer (legacy — DECISION: REMOVE)

| File | Decision | Rationale |
|---|---|---|
| `game/content/customers/casual_browser.json` | **Remove** | Single-Dict format with non-standard schema (`spending_range` instead of `budget_range`, missing `store_types`, `purchase_probability_base`, `browse_time_range`). Converting would require inventing field values. Each store already has 4-5 well-defined customer types that cover the casual browser archetype (e.g., `sports_casual_fan`, `retro_nostalgic_adult`). A universal fallback customer is not needed for M1 and can be re-created with proper schema if needed later. |

## Implementation Steps

1. Confirm DataLoader (issue-001) boots cleanly and skips all legacy files with warnings
2. Delete all 8 files listed above
3. Run DataLoader again — verify same item/store/customer counts, zero skip warnings
4. Remove any references to these files in documentation (issue specs already note them as legacy)

## Acceptance Criteria

- All 5 legacy item scaffold files are deleted
- Both legacy store files are deleted
- `casual_browser.json` is deleted
- DataLoader loads cleanly: 143 items, 5 stores, 21 customers, 0 warnings
- No item ID conflicts remain across content files
- Git history preserves the files for reference if ever needed