# Issue 005: Implement inventory system with ItemInstance tracking

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `tech`, `phase:m1`, `priority:high`
**Dependencies**: issue-001

## Why This Matters

Inventory is the core data structure. Every transaction, display, and customer interaction touches it.

## Current State

**IMPORTANT**: The existing stub at `game/scripts/systems/inventory_system.gd` uses **quantity-based tracking** (`store_id -> {item_id: quantity}`). This is architecturally incompatible with the design, which requires **instance-based tracking** where each physical item is a unique `ItemInstance` with its own condition, price, and location. The stub must be **rewritten**, not extended.

The `ItemInstance` class exists at `game/resources/item_instance.gd` (updated by issue-001 to include `player_set_price` and `rental_due_day` fields). See `docs/architecture/RESOURCE_CLASS_SPEC.md` for the exact fields.

## Design

Each item the player owns is a unique `ItemInstance` with:
- A reference to its `ItemDefinition` (static data from DataLoader)
- Its own `condition` (poor/fair/good/near_mint/mint)
- Its own `current_location` ("backroom", "shelf:card_case_1:3", etc.)
- Its own `player_set_price` (what the player is asking for it)
- Its own `acquired_day` and `acquired_price` (for profit tracking)

This means two copies of the same card (e.g., two `sports_griffey_rookie`) are separate instances that can have different conditions and prices.

### Location Model

Locations use a string format:
- `"backroom"` — in backroom storage
- `"shelf:{fixture_id}:{slot_index}"` — on a specific shelf slot (fixture IDs from store_definitions.json, e.g., `"shelf:card_case_1:3"`)
- `"sold"` — sold (kept for daily transaction history, purged on day end)
- `"rented"` — currently rented out (video rental only)

Fixture IDs come from the store definition's `fixtures` array. For M1, only the sports store's 6 fixtures are relevant:
- `card_case_1` (8 slots), `card_case_2` (8 slots), `sealed_shelf` (6 slots), `memorabilia_shelf` (4 slots), `wall_display` (3 slots), `checkout_counter` (2 slots)

## Deliverables

- Rewritten `game/scripts/systems/inventory_system.gd` with instance-based tracking
- Internal storage: `var _instances: Dictionary = {}` (instance_id -> ItemInstance)
- Instance ID generation: `"{item_definition.id}_{auto_increment_counter}"`

### Public API

```gdscript
# Adding/removing
func create_instance(definition: ItemDefinition, condition: String, acquired_price: float) -> ItemInstance
func remove_instance(instance_id: String) -> bool

# Location management
func move_to_shelf(instance_id: String, fixture_id: String, slot_index: int) -> bool
func move_to_backroom(instance_id: String) -> void
func mark_sold(instance_id: String, sale_price: float) -> void

# Queries
func get_instance(instance_id: String) -> ItemInstance
func get_backroom_items() -> Array[ItemInstance]
func get_shelf_items(fixture_id: String) -> Array[ItemInstance]
func get_all_shelf_items() -> Array[ItemInstance]
func get_items_by_definition(item_id: String) -> Array[ItemInstance]
func is_slot_occupied(fixture_id: String, slot_index: int) -> bool
func get_shelf_item_at(fixture_id: String, slot_index: int) -> ItemInstance  # null if empty
```

### EventBus Signals Needed

These signals should be added to `game/autoload/event_bus.gd`:
```gdscript
signal item_stocked(instance_id: String, fixture_id: String, slot_index: int)
signal item_removed_from_shelf(instance_id: String)
signal item_added_to_inventory(instance_id: String)
```

### Starter Inventory Initialization

When a new game starts, the system should create ItemInstances from the store definition's `starting_inventory` array:
1. For each item ID in `starting_inventory`, look up the `ItemDefinition` via DataLoader
2. Create an `ItemInstance` with a random condition (weighted toward "good"/"near_mint")
3. Set `acquired_price` to `base_price * condition_multiplier * 0.6` (wholesale discount)
4. Set `current_location` to `"backroom"`
5. Player then manually stocks shelves (issue-006)

## Acceptance Criteria

- Can create item instances from definitions with unique IDs
- Can query backroom vs shelf items separately
- Moving item updates its `current_location` string
- No duplicate `instance_id` values
- `item_stocked` signal fires when item placed on shelf
- `item_removed_from_shelf` signal fires when item removed
- Slot occupancy tracking prevents placing two items in the same slot
- `get_shelf_items('card_case_1')` returns only items on that fixture
- Two instances of the same definition have different instance IDs