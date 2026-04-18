# SSOT Cleanup Audit

## Diff-Driven Deletion Summary

1. **Deleted non-runtime `DataLoader` shim code.**
   `game/scripts/data_loader.gd` was only a grep target for shell validators. The real parser path is `game/scripts/content_parser.gd` plus `game/autoload/data_loader.gd`, so the shim was removed and the validators were retargeted to the canonical parser.

2. **Removed dead Pocket Creatures and sports-season compatibility catalogs.**
   `game/content/items_pocket_creatures.json` and `game/content/sports_seasons.json` were deleted because runtime no longer used them; canonical content already lives in `game/content/stores/pocket_creatures_cards.json` and `game/content/stores/sports_seasons.json`.

3. **Deleted loader branches that only existed to skip the removed compatibility files.**
   `DataLoaderSingleton._should_skip_file()` no longer special-cases the deleted root Pocket Creatures and sports-season catalogs.

4. **Removed the dead `item_tested` signal path.**
   Runtime testing code now emits only `item_test_completed`, and the tests that existed solely to preserve the old `item_tested` compatibility signal were removed or updated.

## SSOT Verification

| Domain | Authoritative module | Notes |
| --- | --- | --- |
| Store content parsing | `game/scripts/content_parser.gd` via `game/autoload/data_loader.gd` | Shell validators now point at the parser that actually sets `store.music` and recommended markup fields. |
| Pocket Creatures item catalog | `game/content/stores/pocket_creatures_cards.json` | Root `items_pocket_creatures.json` copy was deleted. |
| Sports season content | `game/content/stores/sports_seasons.json` | Root `sports_seasons.json` copy was deleted. |
| Runtime item-testing completion signal | `EventBus.item_test_completed` | `item_tested` was removed because no runtime listener used it. |
| Milestone catalog loaded by boot | `game/content/progression/milestone_definitions.json` through `DataLoaderSingleton` | Loader still skips the legacy `game/content/milestones/milestone_definitions.json` file when both exist. |

## Risk Log

1. **Retained legacy milestone consumers outside the boot loader.**
   `ProgressionSystem` still reads `game/content/milestones/milestone_definitions.json` directly, and `CompletionTracker` still names revenue milestones from that legacy set. That overlap is active runtime behavior, not dead code, so it was left for a broader convergence pass instead of being partially deleted here.

2. **Retained milestone loader skip for the legacy milestone catalog.**
   The boot pipeline still contains the progression-over-milestones precedence rule because the legacy milestone file still exists in the repository and one runtime system still depends on it directly.

## Sanity Check

- No runtime or validator references remain to deleted files `game/scripts/data_loader.gd`, `game/content/items_pocket_creatures.json`, or `game/content/sports_seasons.json`.
- No runtime code emits or listens for the deleted `item_tested` signal; the remaining tests use `item_test_completed`.
- Documentation and catalog validation now point at the surviving canonical content locations for sports seasons and store parsing.
