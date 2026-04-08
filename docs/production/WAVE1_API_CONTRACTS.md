# Wave-1 API Contracts

This document defines the cross-system interface contracts for wave-1. When two or more issues must agree on a method signature, signal payload, or data shape, the contract is defined here. Individual issue specs reference these contracts — this file is authoritative.

---

## Contract 1: EconomySystem Daily Summary

**Producer**: EconomySystem (issue-010)
**Consumer**: DaySummaryScreen (issue-014)

### `get_daily_summary() -> Dictionary`

Returns a snapshot of the current day's financial activity. Called by the day summary screen when `day_ended` fires.

```gdscript
# Return shape:
{
    "day": int,                    # Current day number
    "revenue": float,              # Total cash received from sales today
    "expenses": float,             # Total cash spent today (rent, orders)
    "items_sold": Array[Dictionary],  # Each: {"item_name": String, "sale_price": float}
    "customers_served": int,       # Customers who purchased something
    "customers_lost": int          # Customers who left without buying
}
```

**Rules**:
- `revenue` and `expenses` are non-negative floats
- `items_sold` is ordered chronologically (first sale first)
- `customers_served + customers_lost` = total customers who entered the store today
- Summary is reset when `day_started` fires for the next day

---

## Contract 2: Market Value Calculation

**Owner**: EconomySystem (issue-010)
**Callers**: CustomerAI (issue-011), PriceSettingUI (issue-008), CheckoutUI (issue-012)

### `get_market_value(item: ItemInstance) -> float`

Returns the current fair market value of a specific item instance.

```gdscript
# M1 formula (no demand modifiers yet):
func get_market_value(item: ItemInstance) -> float:
    var base := item.definition.base_price
    var cond_mult := _get_condition_multiplier(item.condition)
    return base * cond_mult
```

**Rules**:
- Uses condition multipliers from `pricing_config.json`: poor=0.25, fair=0.5, good=1.0, near_mint=1.5, mint=2.0
- Does NOT apply `rarity_multipliers` — rarity is already baked into `base_price`
- Does NOT apply `demand_modifier` in M1 (added in issue-024, wave-2)
- Returns a positive float; never zero or negative
- All systems must call this method rather than computing the formula themselves

### `get_suggested_price(item: ItemInstance) -> float`

Returns a suggested retail price (market value × 1.35 markup).

```gdscript
func get_suggested_price(item: ItemInstance) -> float:
    return get_market_value(item) * 1.35
```

---

## Contract 3: InventorySystem Item Queries

**Owner**: InventorySystem (issue-005)
**Callers**: CustomerAI (issue-011), ShelfInteraction (issue-006), InventoryUI (issue-007), CheckoutUI (issue-012)

### Instance ID Format

```
"{item_definition_id}_{auto_increment_counter}"
# Example: "sports_griffey_rookie_3"
```

Instance IDs are unique across all items for the entire game session. The counter never resets.

### Location String Format

```
"backroom"                        # In storage
"shelf:{fixture_id}:{slot_index}" # On a shelf (e.g., "shelf:card_case_1:3")
"sold"                            # Sold today (purged on day boundary)
"rented"                          # Currently rented (video rental only)
```

### Key Query Methods

```gdscript
func get_all_shelf_items() -> Array[ItemInstance]
# Returns all items currently on any shelf. Used by CustomerAI to browse available items.

func get_shelf_items(fixture_id: String) -> Array[ItemInstance]
# Returns items on a specific fixture. Used by shelf interaction UI.

func get_backroom_items() -> Array[ItemInstance]
# Returns items in backroom. Used by inventory UI in placement mode.

func get_shelf_item_at(fixture_id: String, slot_index: int) -> ItemInstance
# Returns the item at a specific slot, or null. Used by shelf interaction.

func is_slot_occupied(fixture_id: String, slot_index: int) -> bool
# Checks slot availability. Used before placement.
```

---

## Contract 4: TimeSystem Signals and Phase Queries

**Owner**: TimeSystem (issue-009)
**Consumers**: CustomerSpawner (issue-011), HUD (issue-013), DaySummary (issue-014), EconomySystem (issue-010)

### Signals

```gdscript
# Emitted via EventBus:
signal day_started(day_number: int)
signal day_ended(day_number: int)
signal hour_changed(hour: int)                # Every in-game hour
signal day_phase_changed(phase: String)        # "morning", "midday", "afternoon", "evening"
signal time_tick(day: int, hour: int, minute: int)  # Every in-game minute (for HUD)
```

### Phase Definitions

| Phase | Hours | Customer Spawn Modifier |
|---|---|---|
| morning | 09:00–11:59 | 0.5× |
| midday | 12:00–14:59 | 1.5× |
| afternoon | 15:00–17:59 | 1.0× |
| evening | 18:00–20:59 | 0.3× |

### Query Methods

```gdscript
func get_current_hour() -> int
func get_current_minute() -> int
func get_current_day() -> int
func get_current_phase() -> String
func get_time_speed() -> int             # 0=paused, 1=normal, 2=fast, 4=fastest
func set_time_speed(speed: int) -> void
func is_store_open() -> bool             # true if hour in [STORE_OPEN_HOUR, STORE_CLOSE_HOUR)
```

---

## Contract 5: ReputationSystem Daily Delta

**Producer**: ReputationSystem (issue-018)
**Consumer**: DaySummaryScreen (issue-014)

### `get_daily_delta() -> float`

Returns the net reputation change accumulated during the current day. Positive means reputation improved.

```gdscript
# Called by day summary screen alongside EconomySystem.get_daily_summary()
var rep_delta := reputation_system.get_daily_delta()
# Display as "+2.5" or "-1.0" on the summary screen
```

### `reset_daily_delta() -> void`

Called on `day_started` to zero the accumulator for the new day.

### `adjust(delta: float, reason: String) -> void`

The single entry point for all reputation changes. The `reason` parameter is for debug logging.

**Rules**:
- Score is clamped to [0.0, 100.0]
- `_daily_delta` tracks the actual (post-clamp) change, not the requested change
- Emits `EventBus.reputation_changed(old_score, new_score)` only when value actually changes
- Tier transitions checked after every adjustment

### Reputation Tiers

| Tier | Min Score | Customer Multiplier |
|---|---|---|
| unknown | 0 | 1.0× |
| local_favorite | 25 | 1.5× |
| destination_shop | 50 | 2.0× |
| legendary | 80 | 3.0× |

---

## Contract 6: Customer → Register Handoff

**Producer**: CustomerAI (issue-011)
**Consumer**: CheckoutUI/RegisterInteractable (issue-012)

### Flow

```
1. Customer enters PURCHASING state
2. Customer navigates to RegisterPosition (Marker3D)
3. Customer finds register: get_tree().get_first_node_in_group("register")
4. Customer calls: register.set_waiting_customer(self)
5. Register shows visual indicator (customer waiting)
6. Player interacts with register (E key) → CheckoutUI opens
7. CheckoutUI displays: item name, condition, player's set price, customer budget hint
8. Player confirms or rejects sale
9. CheckoutUI calls: customer.complete_purchase(success: bool)
10. If success: EconomySystem.process_sale(), InventorySystem.mark_sold()
11. Customer enters LEAVING state, walks to door, queue_free()
12. EventBus.customer_left emitted
```

### Register Node Interface

```gdscript
# The register Interactable adds itself to group "register"
# Must implement:
func set_waiting_customer(customer: Node) -> void
func get_waiting_customer() -> Node  # Returns null if no one waiting
func clear_waiting_customer() -> void
```

### Customer Interface (for CheckoutUI to call)

```gdscript
# CustomerAI exposes:
var chosen_item: ItemInstance          # The item the customer wants to buy
var budget: float                      # Max the customer will pay
var customer_name: String              # Display name for UI

func complete_purchase(success: bool) -> void
# success=true: customer bought the item, transitions to LEAVING happy
# success=false: sale rejected or timed out, transitions to LEAVING unhappy
```

### Budget Hint Tiers (shown in CheckoutUI)

| Customer Budget vs Price | Hint Text |
|---|---|
| budget >= price × 2.0 | "Eager to buy" |
| budget >= price × 1.2 | "Seems interested" |
| budget >= price | "Considering it" |
| budget < price | "Looks hesitant" |

### Patience Timer

If the player doesn't interact with the register within `patience × 30` seconds (real-time, adjusted for time speed), the customer calls `complete_purchase(false)` on itself and leaves.

---

## Contract 7: DataLoader Query API

**Owner**: DataLoader (issue-001)
**Callers**: All gameplay systems

### Item Lookup

```gdscript
func get_item(id: String) -> ItemDefinition          # null if not found
func get_items_by_store(store_type: String) -> Array[ItemDefinition]
func get_items_by_category(category: String) -> Array[ItemDefinition]
func get_all_items() -> Array[ItemDefinition]
```

### Store Lookup

```gdscript
func get_store(id: String) -> StoreDefinition         # null if not found
func get_all_stores() -> Array[StoreDefinition]
```

### Customer Lookup

```gdscript
func get_customer_types_for_store(store_type: String) -> Array[CustomerTypeDefinition]
func get_all_customer_types() -> Array[CustomerTypeDefinition]
```

### Economy Config

```gdscript
func get_economy_config() -> Dictionary  # Raw parsed pricing_config.json
```

**Rules**:
- All `get_*` methods return empty arrays (not null) when no results found
- Single-item lookups (`get_item`, `get_store`) return null when not found
- Data is read-only after `load_all_content()` completes
- `load_all_content()` must be called before any queries

---

## Signal Payload Reference

All signals emitted through EventBus with their expected payloads:

| Signal | Parameters | Emitter | Notes |
|---|---|---|---|
| `day_started` | `day_number: int` | TimeSystem | First day is 1 |
| `day_ended` | `day_number: int` | TimeSystem | |
| `hour_changed` | `hour: int` | TimeSystem | 24h format (9-21) |
| `day_phase_changed` | `phase: String` | TimeSystem | morning/midday/afternoon/evening |
| `item_sold` | `instance_id: String, sale_price: float` | EconomySystem | After cash updated |
| `item_stocked` | `instance_id: String, fixture_id: String, slot_index: int` | InventorySystem | |
| `item_removed_from_shelf` | `instance_id: String` | InventorySystem | |
| `item_added_to_inventory` | `instance_id: String` | InventorySystem | New instance created |
| `money_changed` | `old_amount: float, new_amount: float` | EconomySystem | |
| `reputation_changed` | `old_value: float, new_value: float` | ReputationSystem | |
| `customer_entered` | `customer_id: String` | CustomerSpawner | |
| `customer_left` | `customer_id: String, purchased: bool` | CustomerAI | |
| `player_interacted` | `target: Node` | Player | |
| `notification_requested` | `message: String` | Any system | For HUD toast display |
