# Data Model

How mallcore-sim defines, loads, and uses game content. The goal is a data-driven architecture where adding new items, store types, or customer types is a JSON editing task, not a code change.

---

## Content Directory Structure

```
res://game/content/
  +-- items/
  |    +-- sports_memorabilia.json
  |    +-- retro_games.json
  |    +-- video_rental.json
  |    +-- pocket_creatures.json
  |    +-- consumer_electronics.json
  +-- stores/
  |    +-- store_definitions.json
  +-- customers/
  |    +-- customer_types.json
  +-- economy/
  |    +-- pricing_config.json
  |    +-- market_events.json
```

Each JSON file contains an array of definition objects. The DataLoader reads all files at boot and builds an in-memory registry.

## Item Definitions (JSON)

Every item in the game is defined in a JSON file grouped by store type.

```json
{
  "id": "retro_sonic2_cart_loose",
  "name": "Sonic the Hedgehog 2",
  "store_type": "retro_games",
  "category": "cartridge",
  "subcategory": "loose",
  "rarity": "common",
  "base_price": 8.00,
  "condition_range": ["poor", "fair", "good", "near_mint", "mint"],
  "condition_value_multipliers": {
    "poor": 0.25,
    "fair": 0.5,
    "good": 1.0,
    "near_mint": 1.5,
    "mint": 2.0
  },
  "tags": ["platformer", "genesis", "classic"],
  "description": "16-bit platformer cartridge. Loose, no box or manual.",
  "icon": "res://game/assets/icons/items/sonic2_cart.png"
}
```

### Required Fields
- `id`: Unique string identifier. Convention: `[store]_[name]_[variant]`
- `name`: Display name
- `store_type`: Which store sells this item
- `category`: Primary grouping (cartridge, card, vhs, etc.)
- `rarity`: One of `common`, `uncommon`, `rare`, `very_rare`, `legendary`
- `base_price`: Market value at "good" condition in dollars

### Optional Fields
- `subcategory`: Secondary grouping (loose, cib, sealed)
- `condition_range`: Which conditions this item can appear in
- `condition_value_multipliers`: Override default multipliers per condition
- `tags`: Freeform tags for search, filtering, and customer preference matching
- `description`: Flavor text for tooltip
- `icon`: Path to icon texture
- `depreciates`: Boolean, true for electronics (value drops over time)
- `appreciates`: Boolean, true for sealed/rare collectibles

## Store Definitions (JSON)

```json
{
  "id": "retro_games",
  "name": "Retro Game Store",
  "description": "Buy, sell, and trade classic video games and consoles.",
  "default_layout": "res://game/scenes/stores/retro_games.tscn",
  "shelf_capacity": 40,
  "backroom_capacity": 100,
  "starting_cash": 500.00,
  "starting_inventory": ["retro_sonic2_cart_loose", "retro_mario64_cart_loose", "retro_snes_console_used"],
  "available_supplier_tiers": [1, 2, 3],
  "unique_mechanics": ["testing_station", "refurbishment"],
  "ambient_sound": "res://game/assets/audio/ambiance/retro_store.ogg"
}
```

## Customer Type Definitions (JSON)

```json
{
  "id": "nostalgic_adult",
  "name": "Nostalgic Shopper",
  "store_types": ["retro_games", "video_rental"],
  "budget_range": [20.00, 80.00],
  "patience": 0.7,
  "price_sensitivity": 0.5,
  "preferred_categories": ["cartridge", "console"],
  "preferred_tags": ["classic", "platformer", "rpg"],
  "condition_preference": "near_mint",
  "browse_time_range": [30, 90],
  "purchase_probability_base": 0.6,
  "dialogue_pool": "nostalgic_adult",
  "model": "res://game/assets/models/customers/casual_adult.glb"
}
```

## Economy Configuration (JSON)

```json
{
  "starting_cash": 500.00,
  "daily_rent": 50.00,
  "reputation_tiers": {
    "unknown": { "min": 0, "customer_multiplier": 1.0 },
    "local_favorite": { "min": 25, "customer_multiplier": 1.5 },
    "destination_shop": { "min": 50, "customer_multiplier": 2.0 },
    "legendary": { "min": 80, "customer_multiplier": 3.0 }
  },
  "condition_multipliers": {
    "poor": 0.25,
    "fair": 0.5,
    "good": 1.0,
    "near_mint": 1.5,
    "mint": 2.0
  },
  "rarity_multipliers": {
    "common": 1.0,
    "uncommon": 2.5,
    "rare": 6.0,
    "very_rare": 15.0,
    "legendary": 40.0
  }
}
```

## Runtime Resource Scripts

JSON is for content authoring. At runtime, the DataLoader converts JSON into typed Godot Resource scripts for type safety and editor integration.

### ItemDefinition (Resource)

```gdscript
class_name ItemDefinition extends Resource

@export var id: String
@export var item_name: String
@export var store_type: String
@export var category: String
@export var rarity: String
@export var base_price: float
@export var tags: PackedStringArray
@export var description: String
@export var icon_path: String
```

### ItemInstance (RefCounted)

Represents a specific item the player owns (with condition, acquisition info):

```gdscript
class_name ItemInstance extends RefCounted

var definition: ItemDefinition
var condition: String
var acquired_day: int
var acquired_price: float
var current_location: String  # "backroom", "shelf:3", "sold"
```

### StoreDefinition, CustomerTypeDefinition

Similar pattern -- Resource scripts with typed fields matching the JSON schema.

## DataLoader

Autoload singleton that runs at boot:

1. Scans `res://game/content/` for all JSON files
2. Parses each file and validates required fields
3. Creates Resource instances and stores them in dictionaries keyed by `id`
4. Logs warnings for missing fields, duplicate IDs, or invalid references

Public API:
- `get_item(id: String) -> ItemDefinition`
- `get_items_by_store(store_type: String) -> Array[ItemDefinition]`
- `get_items_by_category(category: String) -> Array[ItemDefinition]`
- `get_store(id: String) -> StoreDefinition`
- `get_customer_types_for_store(store_type: String) -> Array[CustomerTypeDefinition]`
- `get_economy_config() -> EconomyConfig`

## Naming Conventions

- Item IDs: `{store_type}_{item_name}_{variant}` (e.g., `retro_zelda_oot_cib`)
- Store IDs: lowercase snake_case matching the store type (e.g., `retro_games`)
- Customer IDs: descriptive snake_case (e.g., `nostalgic_adult`)
- All IDs must be unique within their type
- JSON filenames match the store type or system they configure

## Adding New Content

To add a new item:
1. Open the appropriate JSON file in `res://game/content/items/`
2. Add a new object to the array following the schema above
3. Run the game -- DataLoader picks it up automatically
4. If the item has an icon, add it to `res://game/assets/icons/items/`

To add a new store type:
1. Add a store definition to `store_definitions.json`
2. Create a new items JSON file in `res://game/content/items/`
3. Create the store interior scene in `res://game/scenes/stores/`
4. Add customer types that reference the new store type
5. Register the store scene path in the store definition
