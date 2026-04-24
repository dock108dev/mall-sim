# Legacy Content-Path Audit — 2026-04-23 (ISSUE-026)

Phase 0 exit criterion "delete remaining legacy content path duplicates" —
removed all duplicated JSON-reading infrastructure outside the content
autoloads. Specialty config autoloads still own their own domain data
(objectives, tutorial steps, audio registry, market trends, onboarding,
regulars threads, personalities, archetypes, milestones, arc unlocks, day
beats, endings, meta shifts, retro-games grades) — that is single-ownership,
not duplication — but they no longer reimplement `FileAccess.open` +
`JSON.parse` boilerplate. All JSON IO routes through
`DataLoader.load_json(path)` (static helper on `game/autoload/data_loader.gd`).

## Deleted

- `game/scripts/core/constants.gd` — removed 12 unused legacy path constants
  (`ITEMS_PATH`, `STORES_PATH`, `CUSTOMERS_PATH`, `ECONOMY_PATH`,
  `FIXTURES_PATH`, `MILESTONES_PATH`, `EVENTS_PATH`, `SEASONAL_EVENTS_PATH`,
  `RANDOM_EVENTS_PATH`, `STAFF_PATH`, `SECRET_THREADS_PATH`,
  `UPGRADES_PATH`). `grep` confirms zero references in active code.

## Migrated to `DataLoader.load_json`

| File | Content file |
| --- | --- |
| `game/autoload/objective_director.gd` | `objectives.json`, `tutorial_steps.json` |
| `game/autoload/tutorial_context_system.gd` | `tutorial_contexts.json` |
| `game/autoload/audio_manager.gd` | `audio_registry.json` |
| `game/autoload/market_trend_system.gd` | `market_trends_catalog.json` |
| `game/autoload/onboarding_system.gd` | `onboarding_config.json` |
| `game/scripts/systems/regulars_log_system.gd` | `regulars_threads.json` |
| `game/scripts/systems/shopper_archetype_config.gd` | `personalities.json` |
| `game/scripts/systems/customer_simulator.gd` | `archetypes.json` |
| `game/scripts/systems/progression_system.gd` | `milestone_definitions.json` |
| `game/scripts/systems/day_manager.gd` | `arc_unlocks.json` |
| `game/scripts/systems/performance_report_system.gd` | `day_beats.json` |
| `game/scripts/systems/ending_evaluator.gd` | `ending_config.json` |
| `game/scripts/systems/meta_shift_system.gd` | `meta_shifts.json` |
| `game/scripts/stores/retro_games.gd` | `grades.json` |
| `game/scripts/core/boot.gd` | `arc_unlocks.json`, `objectives.json` (boot validators) |

## Intentionally untouched

- `game/autoload/settings.gd`, `game/scripts/core/save_manager.gd`,
  `game/scenes/ui/main_menu.gd`, `game/scripts/systems/tutorial_system.gd`,
  `game/autoload/difficulty_system.gd:_safe_load_config` — these read
  `user://` settings/save state, not `res://game/content/` data.
- `game/autoload/data_loader.gd`, `game/autoload/content_registry.gd`,
  `game/scripts/content_parser.gd` — authorized content-loading owners.

## Verification

- `grep -R "FileAccess.open.*game/content"` in `game/` returns zero hits.
- `grep -R "Constants\.\(ITEMS_PATH\|...\)"` returns zero hits.
- Boot path still registers ≥ 5 stores via `DataLoaderSingleton.load_all()` →
  `ContentRegistry` as before; schema validators in `boot.gd` preserved.
