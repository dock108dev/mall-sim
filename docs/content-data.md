# Content and Data

Mallcore Sim loads gameplay content from JSON under `game/content/`. The boot
pipeline discovers every JSON file under that tree, infers a content type from
either the file contents or the path, converts supported entries into typed
`Resource` objects, registers those resources and raw entries, and then validates
cross-references before gameplay starts.

## Loader pipeline

```text
game/content/**/*.json
  -> DataLoaderSingleton._discover_json_files()
  -> DataLoaderSingleton._detect_type()
  -> ContentParser.parse_*()
  -> ContentRegistry.register()
  -> ContentRegistry.register_entry()
  -> ContentRegistry.validate_all_references()
```

Important current loader behavior:

- the content root is `res://game/content/`
- JSON reads are capped at `1 MiB` per file
- per-file load failures are recorded and aggregated
- boot fails visibly if any content errors remain at the end of the scan

## Current content layout

The checked-in content tree currently includes these canonical subdirectories:

| Path | Current role |
| --- | --- |
| `game/content/items/` | Main item catalogs. |
| `game/content/stores/` | Store definitions (`store_definitions.json`), store-specific config files (`electronics.json`, `retro_games.json`, `video_rental_config.json`), tournament and sports-season catalogs, and per-store subdirectories (`pocket_creatures/` with `creatures.json` and `packs.json`; `retro_games/` with `grades.json`). |
| `game/content/customers/` | Customer definitions and personalities-related data. |
| `game/content/economy/` | Economy and difficulty-related config. |
| `game/content/events/` | Market, seasonal, random, ambient, and named-season event data. |
| `game/content/endings/` | Ending definitions. |
| `game/content/meta/` | Secret thread data and regulars thread data. |
| `game/content/progression/` | Canonical milestone definitions consumed by both `DataLoader` and `ProgressionSystem`. |
| `game/content/onboarding/` | Onboarding hint config. |
| `game/content/staff/` | Staff definitions. |
| `game/content/suppliers/` | Supplier definitions. |
| `game/content/unlocks/` | Unlock definitions. |

The root of `game/content/` also contains several config-oriented JSON files:

- `audio_registry.json`
- `fixtures.json`
- `haggle_dialogue.json`
- `market_trends_catalog.json`
- `meta_shifts.json`
- `pocket_creatures_cards.json`
- `upgrades.json`

A `localization/` subdirectory is present at the content root but is currently
empty.

`game/content/` is the single canonical content root. `DataLoaderSingleton`
loads only from `res://game/content/` with no fallback paths, and
`ProgressionSystem` reads milestones from
`res://game/content/progression/milestone_definitions.json`.

## Type detection

`DataLoaderSingleton` determines content type in this order:

1. a dictionary `type` field when present
2. special handling for files under `game/content/events/`
3. known directory names such as `items`, `stores`, `customers`, `fixtures`,
   `milestones`, `progression`, `staff`, `upgrades`, `economy`, `suppliers`,
   `unlocks`, and `endings`
4. known file basenames such as `retro_games`, `electronics`,
   `video_rental_config`, `pocket_creatures_cards`,
   `pocket_creatures_tournaments`, `sports_seasons`, `seasonal_config`,
   `secret_threads`, and `personalities`

For dictionary-shaped files, entries come from `entries`, `items`, or
`definitions` arrays when present. Otherwise the loader uses the first array of
dictionaries it finds, or treats the dictionary itself as a single entry.

## Canonical IDs and scene-path rules

`ContentRegistry` requires canonical IDs to match:

```text
^[a-z][a-z0-9_]{0,63}$
```

`ContentRegistry.resolve(raw)` normalizes by:

- trimming whitespace
- converting to `snake_case`
- replacing hyphens, spaces, and slashes with underscores
- collapsing repeated underscores
- resolving aliases to a canonical ID

Scene paths registered through content are also constrained:

- all scene paths must stay under `res://game/scenes/`
- scene paths must end in `.tscn`
- store scene paths must stay under `res://game/scenes/stores/`

Use canonical `StringName` IDs at runtime rather than display names.

## Stores — SSOT

`game/content/stores/store_definitions.json` is the single source of truth
for the shipping store roster. Every authoritative property (id, display
name, scene path, inventory type, interaction set, starting inventory,
rent, fixtures, unique mechanics) lives there.

- `ContentRegistry.get_all_store_ids()` returns the live roster.
- `StoreRegistry` is a runtime cache seeded from `ContentRegistry` in its
  `_ready` (`_seed_from_content_registry()`). It does **not** hardcode
  entries.
- `MallOverview` (the hub's store-selection UI) iterates the roster from
  `ContentRegistry`; card content is fully data-driven.
- Adding or removing a store is a JSON edit; no scene or autoload code needs
  to change as long as the scene file at the declared `scene_path` follows
  the store-contract conventions (Camera3D at root for hub-mode entry, an
  `OrbitPivot` marker, a store controller script attached to the root).

Shipping roster (per ADR 0007 and `store_definitions.json`): `sports`
(aliased `sports_memorabilia`), `retro_games`, `rentals` (aliased
`video_rental`), `pocket_creatures`, `electronics` (aliased
`consumer_electronics`).

## Typed resource models

The loader currently builds and registers typed resources from `game/resources/`
for these main domains:

| Resource class | Domain |
| --- | --- |
| `ItemDefinition` | Item catalog entries and store inventory authoring. |
| `StoreDefinition` | Store scenes, capacities, fixtures, starting inventory, and upgrade hooks. |
| `CustomerTypeDefinition` | Customer budgets, patience, preferences, and store affinity. |
| `EconomyConfig` | Starting cash, rent, markup, haggle, rarity, and demand tuning. |
| `FixtureDefinition` | Build-mode fixture placement data. |
| `MarketEventDefinition` | Store/category/tag-driven market modifiers. |
| `SeasonalEventDefinition` | Calendar-driven seasonal modifiers. |
| `RandomEventDefinition` | One-off runtime events and bulk-order style effects. |
| `MilestoneDefinition` | Progression triggers and rewards. |
| `StaffDefinition` | Staff roles, costs, morale, wages, and assignments. |
| `SupplierDefinition` | Supplier tiers, catalog, and unlock rules. |
| `UnlockDefinition` | Unlock effects and messages. |
| `UpgradeDefinition` | Store upgrade cost and effect data. |
| `SportsSeasonDefinition` | Sports-memorabilia demand cycles. |
| `TournamentEventDefinition` | Pocket Creatures tournament scheduling and rewards. |
| `AmbientMomentDefinition` | Ambient flavor-moment triggers and presentation. |
| `PerformanceReport` | Structured end-of-day report data. |

## Non-resource content

Not every content file becomes a typed `Resource`. Current examples include:

- endings, which are kept as entry dictionaries in `ContentRegistry`
- secret threads, which remain dictionaries plus a `DataLoaderSingleton` array
- difficulty config, seasonal config, and named seasons, which remain dictionary
  or array data exposed through `DataLoaderSingleton`
- store-specific config dictionaries such as retro games, electronics, and video
  rental config

## Validation

`ContentRegistry.validate_all_references()` currently checks:

- item `store_type` values resolve to known content
- store `starting_inventory` entries exist as item resources
- registered scene paths exist through `ResourceLoader.exists()`

Additional GUT and integration tests also validate the boot content set, store
scene references, event data, catalog completeness, and related content
contracts.

## Runtime access

Use `ContentRegistry` for canonical single-entry lookup:

```gdscript
var store_id: StringName = ContentRegistry.resolve("Sports")
var store_def: StoreDefinition = ContentRegistry.get_store_definition(store_id)
```

Use `DataLoaderSingleton` when a system needs collection-style access or raw
config data. The current public getter surface includes:

- `get_all_items()`, `get_all_stores()`, `get_all_customers()`
- `get_all_fixtures()`, `get_all_market_events()`,
  `get_all_seasonal_events()`, `get_all_random_events()`
- `get_all_staff_definitions()`, `get_all_upgrades()`,
  `get_all_suppliers()`, `get_all_milestones()`, `get_all_unlocks()`
- `get_all_sports_seasons()`, `get_all_tournament_events()`,
  `get_all_ambient_moments()`, `get_all_secret_threads()`
- `get_economy_config()`, `get_difficulty_config()`,
  `get_retro_games_config()`, `get_electronics_config()`,
  `get_video_rental_config()`, `get_seasonal_config()`,
  `get_named_seasons()`, `get_named_season_cycle_length()`
