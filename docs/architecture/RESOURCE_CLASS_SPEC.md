# Resource Class Specification

This document defines the exact fields for each typed Resource class used by DataLoader and runtime systems. Field lists are derived from the **actual JSON content on disk** as of cycle 21, not the original DATA_MODEL.md (which is now outdated for stores and customers).

All Resource classes live in `game/resources/`.

---

## ItemDefinition

**File**: `game/resources/item_definition.gd`
**Source JSON**: `game/content/items/*.json` (5 files, 143 items total)

```gdscript
class_name ItemDefinition
extends Resource

# Required fields (DataLoader should warn if missing)
@export var id: String
@export var item_name: String
@export var store_type: String               # Must match a store ID
@export var category: String                 # Must be in store's allowed_categories
@export var rarity: String                   # common|uncommon|rare|very_rare|legendary
@export var base_price: float                # Market value at "good" condition

# Optional fields
@export var subcategory: String = ""         # e.g., "loose", "cib", "sealed", "holo"
@export var condition_range: PackedStringArray = ["poor", "fair", "good", "near_mint", "mint"]
@export var condition_value_multipliers: Dictionary = {}  # Override per-condition multipliers
@export var tags: PackedStringArray = []     # Freeform tags for filtering/matching
@export var description: String = ""         # Flavor text for tooltip
@export var icon_path: String = ""           # JSON key: "icon"
@export var set_name: String = ""            # For set completion tracking (pocket_creatures, sports)
@export var depreciates: bool = false        # Electronics: value drops over time
@export var appreciates: bool = false        # Sealed/rare collectibles: value rises
@export var can_be_demo_unit: bool = false   # Electronics demo-floor eligibility
@export var monthly_depreciation_rate: float = 0.0
@export var launch_spike_eligible: bool = false
@export var launch_spike_multiplier: float = 1.0
@export var supplier_tier: int = 0
@export var rental_period_days: int = 0      # Video rental: default rental duration
@export var platform: String = ""            # Retro games: console platform
@export var region: String = ""              # Retro games: NTSC/PAL/JP
```

### Field Mapping from JSON

| JSON key | Resource field | Notes |
|---|---|---|
| `item_name` | `item_name` | Canonical item display name |
| `base_price` | `base_price` | Canonical base value key |
| `condition_range` | `condition_range` | Canonical ordered condition labels |
| `icon` | `icon_path` | Legacy alias still accepted by the parser |
| `set` | `set_name` | Legacy alias still accepted by the parser |
| All other keys | Same name | Direct 1:1 mapping |

### Store-Specific Optional Fields

These appear only in certain store types' items:
- **Sports**: `era`, `sport`, `team`, `player_name`, `authentication_status`
- **Retro Games**: `platform`, `region`, `completeness` (loose/cib/nib)
- **Video Rental**: `genre`, `rental_period_days`, `format` (vhs/dvd)
- **PocketCreatures**: `set_name`, `card_number`, `element_type`, `hp`, `is_holo`
- **Electronics**: `depreciates`, `can_be_demo_unit`, `monthly_depreciation_rate`, `launch_spike_eligible`, `launch_spike_multiplier`, `supplier_tier`

The implementer should store unrecognized keys in an `extra: Dictionary` field rather than ignoring them, to preserve store-specific data without needing a subclass per store type.

---

## ItemInstance

**File**: `game/resources/item_instance.gd`
**Not loaded from JSON** — created at runtime when player acquires items.

```gdscript
class_name ItemInstance
extends RefCounted

var instance_id: String          # Unique per-instance (e.g., UUID or incrementing counter)
var definition: ItemDefinition   # Reference to the static definition
var condition: String = "good"   # Current condition grade
var acquired_day: int = 0        # Day number when acquired
var acquired_price: float = 0.0  # What the player paid
var current_location: String = "backroom"  # "backroom", "shelf:<fixture_id>:<slot>", "sold", "rented"
var player_set_price: float = -1.0  # Player's asking price (-1 = not priced)
var rental_due_day: int = -1     # Video rental: when due back (-1 = not rented)
```

### Instance ID Generation

Use a simple incrementing counter per session: `"{definition.id}_{counter}"`. Counter resets are fine across sessions since instance IDs are only used for runtime tracking and save/load serialization.

---

## StoreDefinition

**File**: `game/resources/store_definition.gd`
**Source JSON**: `game/content/stores/store_definitions.json` (5 stores)

```gdscript
class_name StoreDefinition
extends Resource

# Required fields
@export var id: String
@export var store_name: String               # JSON key: "name"
@export var description: String
@export var shelf_capacity: int              # Total item slots (should equal sum of fixture slots)
@export var backroom_capacity: int
@export var starting_cash: float
@export var daily_rent: float
@export var starting_inventory: PackedStringArray  # Array of item IDs
@export var allowed_categories: PackedStringArray
@export var fixtures: Array[Dictionary]      # Array of {id, type, slots, label}
@export var scene_path: String               # Path to store interior scene (.tscn)

# Optional fields
@export var size_category: String = "small"  # small|medium|large
@export var fixture_slots: int = 6           # Max number of fixtures
@export var max_employees: int = 2
@export var base_foot_traffic: float = 0.4
@export var available_supplier_tiers: Array[int] = [1, 2, 3]
@export var unique_mechanics: PackedStringArray = []
@export var aesthetic_tags: PackedStringArray = []
@export var ambient_sound: String = ""
```

### Field Mapping from JSON

| JSON key | Resource field | Notes |
|---|---|---|
| `name` | `store_name` | Renamed to avoid Godot's built-in `name` property |
| `scene_path` | `scene_path` | Path to the store's interior `.tscn` scene |
| `fixtures` | `fixtures` | Stored as Array[Dictionary], not a typed Resource |
| All other keys | Same name | Direct 1:1 mapping |

---

## CustomerTypeDefinition

**File**: `game/resources/customer_type_definition.gd`
**Source JSON**: `game/content/customers/*.json` (5 store-specific files, 21 types total)

```gdscript
class_name CustomerTypeDefinition
extends Resource

# Required fields
@export var id: String
@export var customer_name: String            # JSON key: "name"
@export var store_types: PackedStringArray   # Which stores this type visits
@export var budget_range: Array[float]       # [min, max]
@export var patience: float                  # 0.0-1.0
@export var price_sensitivity: float         # 0.0-1.0
@export var purchase_probability_base: float # 0.0-1.0

# Optional fields
@export var description: String = ""
@export var preferred_categories: PackedStringArray = []
@export var preferred_tags: PackedStringArray = []
@export var preferred_rarities: PackedStringArray = []
@export var condition_preference: String = ""  # Preferred minimum condition
@export var browse_time_range: Array[float] = [30.0, 90.0]  # seconds
@export var impulse_buy_chance: float = 0.1
@export var visit_frequency: String = "normal"  # low|normal|high
@export var mood_tags: PackedStringArray = []
@export var dialogue_pool: String = ""       # ID for dialogue system
@export var model_path: String = ""          # JSON key: "model"
```

### casual_browser.json — SKIP (Legacy)

`casual_browser.json` is a single Dictionary (not an Array) with a non-standard schema — it uses `spending_range` instead of `budget_range`, and lacks `store_types`, `purchase_probability_base`, and `browse_time_range`. **DataLoader should skip this file with a warning.** Removal is tracked in issue-086.

---

## EconomyConfig

**File**: No dedicated Resource class needed — store as raw Dictionary.
**Source JSON**: `game/content/economy/pricing_config.json`

The pricing config is a single-object structure with known top-level keys. DataLoader stores it as `Dictionary` and provides `get_economy_config() -> Dictionary`. Systems that need typed access (EconomySystem, SupplierSystem) can parse it on init.

Top-level keys (verified against actual file on disk, cycle 21):
- `starting_cash`: float (500.00)
- `daily_rent`: float (50.00)
- `reputation_tiers`: Dictionary of tier objects, each with `{min, customer_multiplier, label}`
  - Keys: `unknown`, `local_favorite`, `destination_shop`, `legendary`
- `condition_multipliers`: Dictionary mapping condition strings to float multipliers
  - Keys: `poor` (0.25), `fair` (0.5), `good` (1.0), `near_mint` (1.5), `mint` (2.0)
- `rarity_multipliers`: Dictionary mapping rarity strings to float multipliers
  - Keys: `common` (1.0), `uncommon` (2.5), `rare` (6.0), `very_rare` (15.0), `legendary` (40.0)
- `supplier_tiers`: Array of tier objects, each with `{tier, name, reputation_threshold, revenue_threshold, rarity_access, wholesale_discount, description}`
  - 3 tiers: Local Distributor, Regional Supplier, Premium Wholesaler
- `price_ratio_reputation_deltas`: Dictionary of pricing bands, each with `{min_ratio?, max_ratio?, delta, description}`
  - Keys: `deep_discount`, `fair_deal`, `market_rate`, `slight_markup`, `overpriced`, `gouging`
- `reputation_decay`: Dictionary with stock-level thresholds and penalties
  - Keys: `well_stocked_threshold`, `well_stocked_bonus`, `understocked_threshold`, `understocked_penalty`, `empty_penalty`

---

## Directory Layout

```
game/resources/
  item_definition.gd
  item_instance.gd
  store_definition.gd
  customer_type_definition.gd
  product_definition.gd        # Legacy scaffold, not used by DataLoader
```

These are pure data containers with no behavior. Game logic lives in the system scripts (`game/scripts/systems/`).
