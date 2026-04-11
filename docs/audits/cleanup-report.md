# Code Quality Cleanup Report

Date: 2026-04-10 (updated 2026-04-10)

## Summary

Audited 117 GDScript files (~23,800 LOC), 39 scenes, 51 resources, and 21 JSON content files. Removed dead code, fixed naming collisions, fixed an inconsistency in starting cash, and consolidated duplicate constants.

---

## Dead Code Removed

### `game/resources/product_definition.gd` (deleted)

`ProductDefinition` class was never referenced by any script, scene, or JSON file. The item system uses `ItemDefinition` (template) and `ItemInstance` (runtime) exclusively.

### `RARITY_COLORS_FALLBACK` constant (3 files)

Identical 7-line dictionary defined in `inventory_panel.gd`, `order_panel.gd`, and `pack_opening_panel.gd`. None of the three files ever referenced the constant — all call `UIThemeConstants.get_rarity_color()` instead. Removed from all three.

### `GameManager.STARTING_CASH` constant

Defined as `500.0` in `game_manager.gd` but never referenced anywhere. The economy system uses `Constants.STARTING_CASH` exclusively. Removed.

### `EventBus.item_purchased` signal

Declared in `event_bus.gd` but never emitted or connected to by any script. Removed.

### `DataLoader.load_all_json_in()` static method

Static method labeled "preserved for backward compatibility" but only called by `debug_commands.gd`. Functionally duplicated by the private `_load_entries_from_dir()` instance method. Removed the static method and the misleading section comment. Updated `debug_commands.gd` to use `GameManager.data_loader.get_all_items()` instead.

### `RandomEventEffects.VIRAL_TREND_DEMAND_MULTIPLIER` constant

Defined in `random_event_effects.gd:6` but never referenced anywhere in that file. The constant exists (and is correctly used) in `random_event_system.gd`, which owns the public `get_demand_multiplier()` API. Removed the unused copy from `random_event_effects.gd`.

---

## Consistency Fixes

### `Constants.STARTING_CASH`: 5000 -> 500

`Constants.STARTING_CASH` was set to `5000.0` which contradicted the project brief ($500 starting cash), the store definitions JSON, and the now-removed `GameManager.STARTING_CASH` (which was `500.0`). Corrected to `500.0`.

### `debug_commands.gd`: use typed DataLoader API

Replaced raw `DataLoader.load_all_json_in()` call with `GameManager.data_loader.get_all_items()`, using the typed `ItemDefinition` API consistent with the rest of the codebase.

### `ReputationSystem.MAX_CUSTOMERS_SMALL/MEDIUM` renamed to `MAX_CUSTOMERS_BY_TIER_SMALL/MEDIUM`

`ReputationSystem` defined `MAX_CUSTOMERS_SMALL: Dictionary` and `MAX_CUSTOMERS_MEDIUM: Dictionary` — tier-keyed lookup tables mapping `Tier -> int`. Both `CustomerSystem` and `StoreSelector` independently define identically-named `MAX_CUSTOMERS_SMALL: int = 5` and `MAX_CUSTOMERS_MEDIUM: int = 8` — flat integer defaults for the base (Unknown tier) cap. The shared name across incompatible types (Dictionary vs. int) creates confusion when reading code. Renamed the Dictionary constants in `reputation_system.gd` to `MAX_CUSTOMERS_BY_TIER_SMALL` and `MAX_CUSTOMERS_BY_TIER_MEDIUM` and updated the two internal call sites (`get_max_customers()`). No external callers were affected — `get_max_customers()` is the public API.

---

## Files Over 300 LOC (CLAUDE.md Limit)

The project standard is max 300 lines per script. The following files exceed this:

| File | Lines | Assessment |
|------|-------|------------|
| `game_world.gd` | 923 | System orchestrator — instantiates ~25 systems and ~20 UI panels. Splitting would create indirection without reducing complexity. Candidate for extraction of `_setup_systems()` and `_setup_ui()` into helper scripts in a future refactor. |
| `data_loader.gd` | 721 | JSON parsing for 9 content types. Each parser is independent. Could split per content type but adds file management overhead with no logic benefit. |
| `economy_system.gd` | 499 | Core economy logic: market value calculation, demand tracking, orders, drift, save/load. Cohesive single-responsibility. Could split save/load and ordering into sub-systems. |
| `customer.gd` | 583 | AI state machine with 6 states, navigation, item evaluation. Cohesive. |
| `save_manager.gd` | 569 | Collect/distribute pattern across 20 systems. Length is proportional to system count. |
| `audio_manager.gd` | 541 | SFX pool, music crossfade, ambient crossfade, event handlers. |
| `inventory_panel.gd` | 529 | UI panel with grid, detail view, placement mode, refurbish/pack buttons. UI panels tend to be long due to node wiring. |
| `settings_panel.gd` | 524 | 3-tab settings UI (audio/display/controls) with keybinding. |
| `fixture_placement_system.gd` | 492 | Grid placement, validation, upgrade delegation, save/load. |
| `customer_animator.gd` | 446 | Procedural animation state machine driving 5 animation states. |
| `mall_hallway.gd` | 428 | Mall environment, storefront management, store transitions. |
| `hud.gd` | 424 | HUD with cash, reputation, time, event banners — wide signal surface area. |
| `staff_panel.gd` | 411 | Staff management UI. |
| `trend_system.gd` | 409 | Trend generation, weighted selection, fade math, save/load. |
| `staff_system.gd` | 406 | Hiring, wages, auto-restock, auto-pricing, save/load. |
| `ambient_moments_system.gd` | 398 | Secret thread ambient event system. |
| `checkout_system.gd` | 392 | Purchase flow, haggling integration, warranty. |

**Recommendation:** `game_world.gd` and `economy_system.gd` are the strongest candidates for future decomposition. The others are within reasonable bounds for their responsibilities.

---

## Files NOT Changed

- No `print()` statements found (good adherence to CLAUDE.md).
- No `TODO`/`FIXME`/`HACK` comments found.
- No commented-out code blocks found.
- Naming conventions are consistent throughout.
- All scripts use static typing.
- `@onready` and `preload()` patterns are used consistently.
- No `get_node()` calls with long paths — all use `@onready`/`@export`.

---

## Intentional Patterns Left As-Is

**Same-named constants across independent systems** — several pairs of constants share a name and value across unrelated systems (e.g., `TREND_MULT_MIN/MAX` in both `trend_system.gd` and `market_event_system.gd`; `ANNOUNCEMENT_DAYS` in `trend_system.gd` and `seasonal_event_system.gd`; `CARD_CATEGORY` and `SET_TAGS` in `meta_shift_system.gd` and `pack_opening_system.gd`; `FADE_DURATION` in `scene_transition.gd` and `mall_hallway.gd`). These are all same-type (float/int/String/Array) local constants with no cross-system dependency. Centralizing them into `Constants` would add coupling between unrelated systems for no runtime benefit. Left as-is. The `MAX_CUSTOMERS_SMALL/MEDIUM` case was different — those were same-named constants with incompatible types (int vs. Dictionary), which was confusing; those were renamed.

---

## What Was Not Done

- No behavioral changes were made.
- No features were added.
- No files were split — flagged above for follow-up only.
- The `player_interacted` signal in EventBus is emitted by `interaction_ray.gd` and has one consumer, so it was kept despite light usage.
- The `content_loaded` signal is emitted by `boot.gd` — kept.
- The `item_lost` signal is emitted by two systems — kept.
