# Content and Data

Gameplay content is authored as JSON under `game/content/`. Boot loads every
JSON file recursively, infers a content type from either the file data or file
path, builds typed Godot `Resource` objects, and registers those objects with
`ContentRegistry`.

## Loader Pipeline

```text
game/content/**/*.json
  -> DataLoaderSingleton._discover_json_files()
  -> DataLoaderSingleton._detect_type()
  -> ContentParser.parse_*()
  -> ContentRegistry.register()
  -> ContentRegistry.register_entry()
  -> ContentRegistry.validate_all_references()
```

Boot blocks on content errors. If validation fails, the boot scene shows an
error panel instead of opening the main menu.

## Content Directories

Current content roots include:

| Directory | Purpose |
| --- | --- |
| `game/content/items/` | Item catalogs for store categories. |
| `game/content/stores/` | Store definitions and store-specific config files. |
| `game/content/customers/` | Customer profiles and store-specific customer data. |
| `game/content/economy/` | Pricing, difficulty, and seasonal economy config. |
| `game/content/events/` | Market, seasonal, random, ambient, and named season data. |
| `game/content/endings/` | Ending configuration. |
| `game/content/meta/` | Secret thread data. |
| `game/content/milestones/` and `game/content/progression/` | Milestone definitions. |
| `game/content/onboarding/` | Onboarding hint config. |
| `game/content/staff/` | Staff definitions. |
| `game/content/suppliers/` | Supplier catalog. |
| `game/content/unlocks/` | Unlock definitions. |

There are also legacy root-level content files such as
`game/content/items_retro_games.json`, `game/content/sports_seasons.json`, and
`game/content/upgrades.json`. They are still loaded because `DataLoaderSingleton`
scans the whole content tree.

## Type Detection

`DataLoaderSingleton` detects content type in this order:

1. A dictionary `type` key when present.
2. Event file names under `game/content/events/`.
3. Known directories such as `items`, `stores`, `customers`, `fixtures`,
   `milestones`, `progression`, `staff`, `upgrades`, `economy`, `suppliers`,
   `unlocks`, and `endings`.
4. Known file basenames such as `pocket_creatures_cards`,
   `pocket_creatures_tournaments`, `sports_seasons`, `seasonal_config`, and
   `secret_threads`.

For dictionary files, entries are extracted from `entries`, `items`, or
`definitions` arrays when those keys exist. Otherwise the loader uses the first
array of dictionaries it finds, or treats the dictionary itself as one entry.

## Canonical IDs

`ContentRegistry` requires canonical IDs to match:

```text
^[a-z][a-z0-9_]{0,63}$
```

Lookup through `ContentRegistry.resolve(raw)` normalizes strings by trimming,
converting to `snake_case`, replacing hyphens, spaces, and slashes with
underscores, collapsing duplicate underscores, and resolving aliases.

Use canonical `StringName` IDs in runtime system boundaries. Do not use display
names as keys.

## Registered Resource Models

Important resource classes in `game/resources/`:

| Resource | Main fields |
| --- | --- |
| `ItemDefinition` | ID, display data, category, store type, base price, rarity, condition range, tags, rental/demo/authentication/lifecycle fields. |
| `StoreDefinition` | ID, scene path, budget, fixture capacity, shelf/backroom capacity, starting inventory, supplier tiers, traffic, sounds, music, upgrade IDs. |
| `CustomerTypeDefinition` | ID, store affinity, budget, patience, price sensitivity, preferences, spawn weight, rental/snack behavior. |
| `EconomyConfig` | Starting cash, rent values, rarity/condition multipliers, haggle limits, reputation tiers, markup ranges, demand modifiers. |
| `FixtureDefinition` | Grid size, footprint, slot count, rotation support, restrictions, unlock conditions, scene path, tier data. |
| `MarketEventDefinition` | Target tags/categories/stores, magnitude, duration, announcement timing, cooldown, text. |
| `SeasonalEventDefinition` | Day timing, store multipliers, traffic/spending multipliers, customer weights, announcement text. |
| `RandomEventDefinition` | Probability, effect type/target/magnitude, severity, cooldown, time window, bulk-order fields. |
| `MilestoneDefinition` | Trigger type/key/threshold, visibility, tier, reward type/value, unlock ID. |
| `StaffDefinition` | Role, skill, hire cost, morale, wage, seniority, assigned store. |
| `SupplierDefinition` | Tier, store type, lead time, reliability, unlock condition, catalog. |
| `UnlockDefinition` | Effect type, target, value, and unlock message. |
| `UpgradeDefinition` | Store type, cost, reputation requirement, effect type/value, one-time flag. |
| `PerformanceReport` | Daily revenue, expenses, profit, sales, customers, walkouts, satisfaction, reputation delta, special income/costs. |

Field names above come from current resource scripts. When adding JSON, confirm
the parser maps the authored keys into the target resource before documenting a
new contract.

## Content Validation

`ContentRegistry.validate_all_references()` currently checks:

- item `store_type` references resolve to known content
- store `starting_inventory` entries exist as item resources
- scene paths registered in content exist through `ResourceLoader.exists()`

Tests under `tests/gut/` also validate portions of boot content, catalog
coverage, event content, diminishing rarity data, store scenes, and customer
profiles.

## Runtime Access

Use `ContentRegistry` for canonical lookup:

```gdscript
var store_id: StringName = ContentRegistry.resolve("Sports")
var store_def: StoreDefinition = ContentRegistry.get_store_definition(store_id)
```

Use `DataLoaderSingleton` helpers when a system needs catalog collections, such
as all fixtures, all suppliers for a store, all market events, all tournament
events, or all ambient moments.
