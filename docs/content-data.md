# Content and Data

Gameplay content is loaded from JSON under `game/content/`. The boot pipeline
discovers every JSON file under that tree, reads the required root `"type"`
field, converts supported entries into typed `Resource` objects, registers
those resources and raw entries, and then validates cross-references before
gameplay starts.

## Loader pipeline

```text
game/content/**/*.json
  -> DataLoaderSingleton._discover_json_files()
  -> dict["type"] looked up in DataLoader._TYPE_ROUTES
  -> ContentParser.parse_*()
  -> ContentRegistry.register()
  -> ContentRegistry.register_entry()
  -> ContentRegistry.validate_all_references()
```

Important current loader behavior:

- the content root is `res://game/content/`
- JSON reads are capped at `1 MiB` per file (`MAX_JSON_FILE_BYTES`)
- per-file load failures are recorded and aggregated
- boot fails visibly if any content errors remain at the end of the scan

## Current content layout

The checked-in content tree under `game/content/`:

| Path | Current role |
| --- | --- |
| `items/retro_games.json` | Retro Games item catalog (the only shipping item file). |
| `stores/store_definitions.json` | Shipping store roster (single entry: `retro_games`). |
| `stores/retro_games.json` | Per-store config for Retro Games. |
| `stores/retro_games/grades.json` | Retro Games condition grades (loaded as `retro_games_grades_data`). |
| `customers/` | `archetypes.json`, `casual_browser.json`, `customer_profiles.json`, `personalities.json`, `retro_games_customers.json`. |
| `economy/` | `difficulty_config.json`, `pricing_config.json`. |
| `events/` | `ambient_moments.json`, `market_events.json`, `random_events.json`. |
| `endings/` | `ending_config.json`. |
| `manager/` | `manager_notes.json` consumed by `ManagerRelationshipManager`. |
| `meta/` | `regulars_threads.json` consumed directly by the regulars-log system. |
| `progression/` | `arc_unlocks.json` (boot-validated) and `milestone_definitions.json`. |
| `onboarding/` | `onboarding_config.json`. |
| `staff/` | `staff_definitions.json`. |
| `suppliers/` | `supplier_catalog.json`. |
| `unlocks/` | `unlocks.json`. |
| `beta/days/` | `day_01.json`, `day_02.json` — loaded directly by `BetaDayOneController`, routed to `ignore` in the loader table. |
| `beta/events/` | `customer_events.json`, `hidden_thread_events.json` — same path as above. |

Top-level config / data JSON files at the content root:

- `audio_registry.json`
- `day_beats.json`
- `fixtures.json`
- `haggle_dialogue.json`
- `objectives.json` (boot-validated for required keys)
- `platforms.json` (consumed by `PlatformSystem`)
- `tutorial_contexts.json`
- `upgrades.json`

A `localization/` directory is present at the content root and is currently
empty; the project-side translation resources live under
`game/assets/localization/` and are referenced from `project.godot`.

`game/content/` is the single canonical content root. `DataLoaderSingleton`
loads only from `res://game/content/` with no fallback paths, and
`ProgressionSystem` reads milestones from
`res://game/content/progression/milestone_definitions.json`.

## Type detection

Every content JSON must declare a root `"type"` field. The loader looks the
value up in `DataLoader._TYPE_ROUTES`; a missing field, a non-Dictionary root,
or an unknown type produces a per-file load error and fails boot via the
in-scene error panel. There is no heuristic detection by filename or
directory.

Routes fall into three buckets in `_TYPE_ROUTES`:

1. **`entries:<kind>`** — parsed as a list of registered entries of `<kind>`
   (item, store, customer, fixture, milestone, staff, upgrade, supplier,
   unlock, market_event, random_event, ambient_moment).
2. **Singleton / specialized configs** — `economy`, `difficulty_config`,
   `ending`, `retro_games_config`, `day_beats_data`.
3. **`ignore`** — recognized type strings whose payloads are loaded by
   another system (e.g. `audio_registry_data`, `haggle_dialogue_data`,
   `arc_unlocks_data`, `objectives_data`, `regulars_threads_data`,
   `personality_data`, `archetypes_data`, `platforms_data`,
   `manager_notes_data`, `onboarding_config_data`,
   `tutorial_contexts_data`, `retro_games_grades_data`,
   `beta_day_data`, `beta_events_data`).

For entry-bucket dictionary-shaped files, entries come from `entries`,
`items`, or `definitions` arrays when present. Otherwise the loader uses the
first array of dictionaries it finds, or treats the dictionary itself as a
single entry.

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
- Adding or removing a store is a JSON edit; no scene or autoload code needs
  to change as long as the scene file at the declared `scene_path` follows
  the store-contract conventions (Camera3D at root for hub-mode entry, an
  `OrbitPivot` marker, a store controller script attached to the root).

Shipping roster (per `store_definitions.json`): `retro_games`.

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
| `RandomEventDefinition` | One-off runtime events and bulk-order style effects. |
| `MilestoneDefinition` | Progression triggers and rewards. |
| `StaffDefinition` | Staff roles, costs, morale, wages, and assignments. |
| `SupplierDefinition` | Supplier tiers, catalog, and unlock rules. |
| `UnlockDefinition` | Unlock effects and messages. |
| `UpgradeDefinition` | Store upgrade cost and effect data. |
| `AmbientMomentDefinition` | Ambient flavor-moment triggers and presentation. |
| `PerformanceReport` | Structured end-of-day report data. |

## Non-resource content

Not every content file becomes a typed `Resource`. Current examples include:

- endings, which are kept as entry dictionaries in `ContentRegistry`
- regulars-thread data under `game/content/meta/`, which is consumed
  directly by the systems that use it rather than re-exposed as a typed
  catalog through `DataLoaderSingleton`
- difficulty config, which remains dictionary data exposed through
  `DataLoaderSingleton.get_difficulty_config()`
- the `retro_games` per-store config dictionary
  (`DataLoaderSingleton.get_retro_games_config()`)
- beta day-1/day-2 day files and beta event files, which
  `BetaDayOneController` reads directly from disk

## Validation

`ContentRegistry.validate_all_references()` currently checks:

- duplicate IDs and alias-conflict errors recorded during registration (so
  boot fails loudly when an id or alias resolves to more than one target)
- item `store_type` values resolve to known content
- store `starting_inventory` entries exist as item resources
- registered scene paths exist through `ResourceLoader.exists()`
- market-event `target_store_types` resolve to known stores
- supplier and milestone cross-references resolve to known content

Additional GUT and integration tests also validate the boot content set, store
scene references, event data, catalog completeness, and related content
contracts.

## Runtime access

Use `ContentRegistry` for canonical single-entry lookup:

```gdscript
var store_id: StringName = ContentRegistry.resolve("Retro Games")
var store_def: StoreDefinition = ContentRegistry.get_store_definition(store_id)
```

Use `DataLoaderSingleton` when a system needs collection-style access or raw
config data. The current public getter surface includes:

- `get_all_items()`, `get_all_stores()`, `get_all_customers()`
- `get_all_fixtures()`, `get_all_market_events()`,
  `get_all_random_events()`
- `get_all_staff_definitions()`, `get_all_upgrades()`,
  `get_all_suppliers()`, `get_all_milestones()`, `get_all_unlocks()`
- `get_all_ambient_moments()`
- `get_economy_config()`, `get_difficulty_config()`,
  `get_retro_games_config()`
