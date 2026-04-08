# System Overview

All major systems in mallcore-sim, how they communicate, and what each one owns.

---

## Communication Pattern: Signal Bus

Systems communicate through a global EventBus autoload. No system holds a direct reference to another system. This keeps dependencies unidirectional and makes it possible to test or replace any system in isolation.

```
GameManager (orchestration, state machine)
    |
    v
EventBus (global signal broker, autoload)
    |
    +--- EconomySystem (money, prices, market values)
    +--- InventorySystem (items, stock, backroom)
    +--- CustomerSystem (AI, spawning, behavior)
    +--- TimeSystem (day cycle, speed control)
    +--- ReputationSystem (score, tiers, effects)
    +--- DataLoader (JSON parsing, content registry)
    +--- SaveManager (persistence, serialization)
```

Systems emit signals to the EventBus. Other systems connect to the signals they care about. No direct coupling.

### Autoloads vs Scene-Attached Systems

Only 4 scripts are registered as autoloads in `project.godot`: GameManager, EventBus, AudioManager, Settings. These are globally available singletons.

All gameplay systems (EconomySystem, InventorySystem, CustomerSystem, TimeSystem, ReputationSystem, DataLoader, SaveManager) are standalone class scripts in `game/scripts/`. They are instantiated as children of GameWorld or managed by GameManager at runtime. This keeps the autoload list small and avoids global state for systems that only matter during gameplay.

---

## GameManager

**Responsibility**: Top-level game state machine and lifecycle orchestration.

- Owns the current game state: `MENU`, `PLAYING`, `PAUSED`, `DAY_SUMMARY`, `LOADING`
- Coordinates scene transitions
- Triggers day start / day end sequences
- Holds the reference to the current save data
- Autoload singleton

**Does NOT own**: Any gameplay data, UI state, or system-specific logic.

## EventBus

**Responsibility**: Global signal broker for decoupled communication.

- Declares all cross-system signals in one place
- Any system can emit; any system can connect
- Signals are typed with parameters (e.g., `item_sold(item_id: String, price: float, customer_id: String)`)
- No logic -- pure message passing

**Key signals**:
- `day_started(day_number: int)`
- `day_ended(day_number: int)`
- `item_sold(item_id: String, sale_price: float)`
- `item_stocked(item_id: String, shelf_id: String)`
- `customer_entered(customer: CustomerData)`
- `customer_left(customer: CustomerData, purchased: bool)`
- `reputation_changed(old_value: float, new_value: float)`
- `money_changed(old_amount: float, new_amount: float)`
- `order_placed(order: OrderData)`
- `order_delivered(order: OrderData)`

## EconomySystem

**Responsibility**: All financial logic.

- Tracks player cash balance
- Calculates market values for items based on rarity, condition, and demand
- Processes sales transactions (deduct item, add cash, emit signal)
- Processes purchases/orders (deduct cash, queue delivery)
- Handles operating costs (rent, utilities -- future feature)
- Provides price suggestion API for the UI

**Data owned**: Player cash, market value tables, transaction history for current day.

## InventorySystem

**Responsibility**: All item tracking and storage.

- Maintains the list of all items the player owns (backroom + on shelves)
- Tracks item location (backroom slot, shelf slot, or in-transit)
- Handles item placement and removal from shelves
- Tracks item condition and metadata
- Provides query API: "what's on this shelf?", "what's in the backroom?", "do I have item X?"

**Data owned**: Player inventory list, shelf assignments, backroom contents.

## CustomerSystem

**Responsibility**: Customer spawning, AI behavior, and lifecycle.

- Spawns customers based on time of day, reputation, and randomness
- Each customer is an AI agent with: desired item categories, budget, patience, personality
- Customers browse shelves, evaluate items (price vs. willingness), and decide to buy or leave
- Emits signals when customers enter, browse, buy, or leave
- Manages the customer pool (max simultaneous customers based on store size)

**Data owned**: Active customer list, customer type definitions, spawn schedule.

## TimeSystem

**Responsibility**: In-game clock and day cycle.

- Tracks current time of day (morning/midday/afternoon/evening)
- Tracks current day number
- Manages time speed (1x, 2x, 4x, paused)
- Emits periodic time tick signals for systems that need to update
- Triggers day_started and day_ended through GameManager

**Data owned**: Current time, current day, time speed setting.

## ReputationSystem

**Responsibility**: Player reputation tracking and effects.

- Maintains reputation score (0-100 scale)
- Calculates reputation changes from events (sales, pricing, customer satisfaction)
- Determines reputation tier (Unknown, Local Favorite, Destination Shop, Legendary)
- Provides modifier values that other systems query (e.g., CustomerSystem asks "what's the customer attraction multiplier?")

**Data owned**: Reputation score, tier, modifier lookup tables.

## DataLoader

**Responsibility**: Loading and parsing all JSON content files at startup.

- Reads item definitions, store definitions, customer types, economy config from `res://game/content/`
- Converts JSON into typed Resource objects (ItemDefinition, StoreDefinition, etc.)
- Provides a registry API: `get_item(id)`, `get_items_by_category(cat)`, `get_store_config(type)`
- Validates content on load and reports errors
- Runs once at boot, results cached for the session

**Data owned**: Content registry (read-only after load).

## SaveManager

**Responsibility**: Serializing and deserializing game state.

- Collects saveable data from all systems via a `get_save_data()` interface
- Writes to `user://saves/` as JSON
- Loads save files and distributes data back to systems via `load_save_data(data)`
- Handles auto-save at end of day
- Manages save slots and metadata (timestamp, day number, store name)

**Data owned**: Save file I/O, save metadata index.

---

## Ownership Rules

1. Each system owns its data. No other system writes to it directly.
2. Systems request changes by emitting signals or calling public methods on the owning system.
3. The GameManager orchestrates sequences but does not contain gameplay logic.
4. The EventBus contains no logic -- it is a signal declaration file only.
5. DataLoader is read-only after initialization. Content is never modified at runtime.
