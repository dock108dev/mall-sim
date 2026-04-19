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

---

## Pass 2 — Dead-Code and Unreachable-Path Deletion (2026-04-19)

### Diff-Driven Deletion Summary

1. **Deleted `_can_test_item(item_id: StringName)` from `game/scripts/stores/retro_games.gd`.**
   The method was a private ID-based wrapper around `_testing_system.can_test()` that was never called from any game code. The only caller was one GUT test. The public counterpart `can_test_item(item: ItemInstance)` is the real contract and is actively called from game code (line 109). Deleted the dead private variant and its dedicated test case from `tests/gut/test_retro_games_controller.gd`.

2. **Removed unreachable `consumer_electronics` legacy fallback from `game/scripts/stores/electronics_store_controller.gd`.**
   `_load_demo_config()` fell back to looking up `&"consumer_electronics"` if `ContentRegistry.exists("electronics")` returned false. Since `store_definitions.json` registers `"electronics"` as the canonical ID and `"consumer_electronics"` as an alias, both entries live and die together — the fallback could never succeed when the canonical lookup failed. The dead branch was deleted and replaced with a `push_error()` hard failure so a missing entry surfaces immediately rather than silently degrading.

### SSOT Verification (cumulative)

| Domain | Authoritative module | Notes |
| --- | --- | --- |
| Store content parsing | `game/scripts/content_parser.gd` via `game/autoload/data_loader.gd` | Unchanged from Pass 1. |
| Pocket Creatures item catalog | `game/content/stores/pocket_creatures_cards.json` | Unchanged from Pass 1. |
| Sports season content | `game/content/stores/sports_seasons.json` | Unchanged from Pass 1. |
| Runtime item-testing completion signal | `EventBus.item_test_completed` | Unchanged from Pass 1. |
| Electronics store content entry | `"electronics"` (canonical) in `ContentRegistry` | `"consumer_electronics"` alias exists in `store_definitions.json`; no separate fallback lookup needed in code. |
| Item testability predicate | `RetroGamesController.can_test_item(ItemInstance)` | The ID-based private variant `_can_test_item(StringName)` was the dead duplicate; deleted. |

### Risk Log

1. **Retained `_format_legacy_metadata` in `game/scenes/ui/save_load_panel.gd`.**
   `_format_metadata()` falls back to this for save slot metadata that lacks the `day`/`cash` keys. Because `_read_slot_metadata_from_save` reads the raw save file without first running migrations, a v0 save file on disk would produce metadata without those keys and legitimately reach this branch. Deleting it would show empty slot previews for any user with an un-migrated save.

2. **Retained `_migrate_v0_to_v1` in `game/scripts/core/save_manager.gd`.**
   Migration chain must remain complete; there is no safe floor version below which we stop migrating.

3. **Retained `generate_report()` in `game/scripts/systems/performance_report_system.gd`.**
   Called only from tests currently, but it reflects live system state and is likely the intended UI integration point. Removing it would leave the system with no snapshot API and break the test suite. Left for a broader day-summary pass.

### Sanity Check

- `_can_test_item` has zero remaining references in game code or tests.
- `consumer_electronics` string no longer appears as a fallback lookup in GDScript; it remains only as an alias entry in `store_definitions.json` (correct) and as a scene path segment in `store_definitions.json` scene_path field (correct).
- `can_test_item(ItemInstance)` still has its caller at `retro_games.gd:109` and is fully intact.
