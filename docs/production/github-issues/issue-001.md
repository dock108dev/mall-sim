# Issue 001: Wire DataLoader to parse all content JSON on boot

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `tech`, `data`, `phase:m1`, `priority:high`
**Dependencies**: None

## Why This Matters

Every system depends on content data. DataLoader is the foundation of the data-driven pipeline. Nothing else in wave-1 can be integration-tested without it.

## Current State

`game/scripts/data/data_loader.gd` exists as a `RefCounted` class with two static helper methods (`load_json`, `load_all_json_in`) but no registry, no typed Resources, and no public query API. It needs to be expanded into the full content registry described in `docs/architecture/DATA_MODEL.md`.

### Resource Class Status (UPDATED)

Resource class scripts **partially exist** at `game/resources/` (NOT `game/scripts/resources/` as specified in RESOURCE_CLASS_SPEC.md). They have significant gaps:

| Class | File | Status | Issues |
|---|---|---|---|
| ItemDefinition | `game/resources/item_definition.gd` | EXISTS | Field `name` should be `item_name`; missing `set_name`, `rental_period_days`, `platform`, `region`, `condition_value_multipliers` |
| ItemInstance | `game/resources/item_instance.gd` | EXISTS | Missing `player_set_price`, `rental_due_day` |
| StoreDefinition | `game/resources/store_definition.gd` | EXISTS | Field `name` should be `store_name`, `starting_budget` should be `starting_cash`; missing `backroom_capacity`, `daily_rent`, `starting_inventory`, `fixtures`, `base_foot_traffic`, `available_supplier_tiers`, `unique_mechanics`, `aesthetic_tags`, `ambient_sound` |
| CustomerTypeDefinition | — | **MISSING** | Must be created from scratch |
| ProductDefinition | `game/resources/product_definition.gd` | EXISTS | **Not in spec** — legacy scaffold, keep for now but do not use in DataLoader |

**Decision**: Update classes in-place at `game/resources/` and update RESOURCE_CLASS_SPEC.md to reflect the actual path.

### DataLoader Conversion

The current DataLoader extends `RefCounted` with only static methods. It needs to become either a `Node` (if added as a child of GameManager) or remain `RefCounted` with instance state. Since SYSTEM_OVERVIEW.md says it should be instantiated by GameManager at runtime, converting to `Node` is recommended so it can be `add_child()`'d.

## Content Files to Load

| Directory | Files | Format | Count |
|---|---|---|---|
| `game/content/items/` | `sports_memorabilia_cards.json`, `retro_games.json`, `video_rental.json`, `pocket_creatures.json`, `consumer_electronics.json` | Array of item objects | 143 total items |
| `game/content/stores/` | `store_definitions.json` | Array of store objects | 5 stores |
| `game/content/customers/` | `sports_store_customers.json`, `retro_games_customers.json`, `video_rental_customers.json`, `pocket_creatures_customers.json`, `electronics_customers.json` | Array of customer objects | 21 customer types |
| `game/content/economy/` | `pricing_config.json` | Single config object | 1 |

### Verified Item Counts Per Store (confirmed on disk 2026-04-08)

| Store | File | Count | store_type value |
|---|---|---|---|
| sports | `sports_memorabilia_cards.json` | 19 | `"sports"` |
| retro_games | `retro_games.json` | 28 | `"retro_games"` |
| rentals | `video_rental.json` | 30 | `"rentals"` |
| pocket_creatures | `pocket_creatures.json` | 38 | `"pocket_creatures"` |
| electronics | `consumer_electronics.json` | 28 | `"electronics"` |
| **Total** | | **143** | |

### Verified Customer Counts (confirmed on disk 2026-04-08)

| Store | File | Count | Format |
|---|---|---|---|
| sports | `sports_store_customers.json` | 4 | Array ✓ |
| retro_games | `retro_games_customers.json` | 4 | Array ✓ |
| video_rental | `video_rental_customers.json` | 4 | Array ✓ |
| pocket_creatures | `pocket_creatures_customers.json` | 5 | Array ✓ |
| electronics | `electronics_customers.json` | 4 | Array ✓ |
| **Total** | | **21** | |

**Legacy files to skip or handle gracefully** (issue-086 tracks removal):
- `game/content/items/sports_baseball_card.json` (single Dictionary, not Array)
- `game/content/items/games_retro_cartridge.json` (single Dictionary)
- `game/content/items/electronics_mp3_player.json` (single Dictionary)
- `game/content/items/fakemon_booster.json` (single Dictionary)
- `game/content/items/video_rental_vhs.json` (single Dictionary)
- `game/content/stores/sample_sports_store.json` (single Dictionary, different schema)
- `game/content/stores/sports_memorabilia.json` (single Dictionary, duplicate of unified entry)
- `game/content/customers/casual_browser.json` (single Dictionary, non-standard schema — skip for now, disposition TBD in issue-086)

DataLoader should log a warning and skip any file that parses as a Dictionary (not Array) in the items/ and customers/ directories. For stores/, only load `store_definitions.json` by name.

## Implementation Spec

### Step 1: Update Resource Class Scripts

Update the 3 existing files in `game/resources/` and create 1 new file, per the spec in `docs/architecture/RESOURCE_CLASS_SPEC.md`:

**Update** `game/resources/item_definition.gd`:
- Rename `name` → `item_name` (Godot's Node.name conflict)
- Add missing fields: `set_name: String`, `rental_period_days: int`, `platform: String`, `region: String`, `condition_value_multipliers: Dictionary`
- Add `extra: Dictionary` for unrecognized store-specific JSON keys

**Update** `game/resources/item_instance.gd`:
- Add `player_set_price: float` (player's asking price, default -1.0)
- Add `rental_due_day: int` (for video rental, default -1)

**Update** `game/resources/store_definition.gd`:
- Rename `name` → `store_name`
- Rename `starting_budget` → `starting_cash`
- Remove `store_type` (redundant with `id`)
- Add missing required fields: `backroom_capacity: int`, `daily_rent: float`, `starting_inventory: PackedStringArray`, `fixtures: Array` (of Dictionaries)
- Add missing optional fields: `base_foot_traffic: float`, `available_supplier_tiers: Array[int]`, `unique_mechanics: PackedStringArray`, `aesthetic_tags: PackedStringArray`, `ambient_sound: String`

**Create** `game/resources/customer_type_definition.gd` — CustomerTypeDefinition extends Resource:
- Required: `id`, `customer_name`, `store_types: PackedStringArray`, `budget_range: Array[float]`, `patience: float`, `price_sensitivity: float`, `purchase_probability_base: float`
- Optional: `description`, `preferred_categories`, `preferred_tags`, `preferred_rarities`, `condition_preference`, `browse_time_range`, `impulse_buy_chance`, `visit_frequency`, `mood_tags`, `dialogue_pool`, `model_path`
- Add `extra: Dictionary` for unrecognized keys

Leave `game/resources/product_definition.gd` untouched — it's not part of the DataLoader pipeline.

### Step 2: Expand DataLoader

Convert from static-only RefCounted to a stateful class (Node or RefCounted with instance methods).

#### Registry Data Structures

```gdscript
var _items: Dictionary = {}          # id -> ItemDefinition
var _stores: Dictionary = {}         # id -> StoreDefinition  
var _customer_types: Dictionary = {} # id -> CustomerTypeDefinition
var _economy_config: Dictionary = {} # raw parsed config
var _load_errors: Array[String] = [] # collected warnings
```

#### Loading Sequence

1. Load economy config first (needed for validation context)
2. Load all item files from `Constants.ITEMS_PATH` — skip non-Array files with warning
3. Load store definitions from `Constants.STORES_PATH + "store_definitions.json"` specifically
4. Load all customer files from `Constants.CUSTOMERS_PATH` — skip non-Array files with warning
5. Run cross-reference validation (starting_inventory IDs, store_type references)
6. Log summary: "DataLoader: loaded {n} items, {n} stores, {n} customers, {n} warnings"

#### JSON-to-Resource Mapping

For each JSON dict, create the Resource and set fields. Handle the `name` -> `item_name`/`store_name`/`customer_name` rename (since Godot's Node.name is built-in). Store unrecognized keys in `extra: Dictionary`.

### Validation Rules

On load, collect warnings (not errors) for:
- Missing required fields: `id`, `name`, `store_type`, `category`, `rarity`, `base_price` (items)
- Missing required fields: `id`, `name`, `shelf_capacity`, `starting_inventory` (stores)
- Missing required fields: `id`, `name`, `store_types`, `budget_range`, `patience`, `price_sensitivity`, `purchase_probability_base` (customers)
- Duplicate IDs within a type (keep first, warn on second)
- Store `starting_inventory` referencing item IDs that don't exist
- Customer `store_types` referencing store IDs that don't exist
- Unknown rarity values (not in: common, uncommon, rare, very_rare, legendary)
- Non-Array JSON files in items/ or customers/ directories

### Public API

```gdscript
func load_all_content() -> void            # Call once at boot
func get_item(id: String) -> ItemDefinition
func get_items_by_store(store_type: String) -> Array[ItemDefinition]
func get_items_by_category(category: String) -> Array[ItemDefinition]
func get_all_items() -> Array[ItemDefinition]
func get_store(id: String) -> StoreDefinition
func get_all_stores() -> Array[StoreDefinition]
func get_customer_types_for_store(store_type: String) -> Array[CustomerTypeDefinition]
func get_all_customer_types() -> Array[CustomerTypeDefinition]
func get_economy_config() -> Dictionary
func get_load_errors() -> Array[String]    # For debug UI
```

## Deliverables

- Updated `game/resources/item_definition.gd` — add missing fields, rename `name` → `item_name`
- Updated `game/resources/item_instance.gd` — add `player_set_price`, `rental_due_day`
- Updated `game/resources/store_definition.gd` — add missing fields, fix field names
- New `game/resources/customer_type_definition.gd` — full CustomerTypeDefinition resource
- Expanded `game/scripts/data/data_loader.gd` with full registry and query API
- Loads all 5 item files, 1 store file, 5 customer files, 1 economy config
- Validation logging for schema errors, missing refs, duplicate IDs
- Legacy files handled gracefully (warned and skipped)

## Acceptance Criteria

- Run game, check output: all 143 items loaded without errors
- `get_items_by_store('sports')` returns 19 items
- `get_items_by_store('retro_games')` returns 28 items
- `get_items_by_store('rentals')` returns 30 items
- `get_items_by_store('pocket_creatures')` returns 38 items
- `get_items_by_store('electronics')` returns 28 items
- `get_all_stores()` returns 5 stores
- `get_store('sports').starting_inventory` has 9 entries, all resolvable to ItemDefinitions
- `get_customer_types_for_store('sports')` returns 4 types
- `get_customer_types_for_store('pocket_creatures')` returns 5 types
- `get_all_customer_types()` returns 21 types
- Duplicate ID produces a warning (test by temporarily duplicating an entry)
- Missing required field produces a warning
- Legacy single-item scaffold files produce a skip warning, don't crash
- `casual_browser.json` is skipped with a warning (non-Array format)

## Test Plan

1. Boot the game, verify console output shows: "DataLoader: loaded 143 items, 5 stores, 21 customers, 0 warnings" (or similar)
2. Introduce a duplicate ID in one JSON file, verify warning appears
3. Remove a required field from one item, verify warning appears
4. Call each public API method and verify return types and counts
5. Verify Resource fields are populated correctly (spot-check a few items)