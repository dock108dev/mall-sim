# EventBus Signal Catalog

Consolidated reference for all signals declared on the EventBus autoload (`game/autoload/event_bus.gd`). Each wave-1 issue specifies signals it needs — this document reconciles them into a single canonical list.

## How to Use This Document

When implementing an issue that adds signals to EventBus:
1. Check this catalog for the canonical signal name and signature
2. Add the signal to `event_bus.gd` exactly as specified here
3. If your issue needs a signal not in this catalog, add it here first

---

## Signal Naming Conventions

- Past tense for events that already happened: `item_sold`, `day_ended`
- Present tense for requests: `price_panel_requested`, `notification_requested`
- Parameters use `instance_id: String` for ItemInstance references (not `item_id`)
- Parameters use `store_id: String` for store references

---

## Existing Signals (in event_bus.gd today)

These signals exist in the current codebase. Some need signature updates to match issue specs.

| Signal | Current Signature | Needed Signature | Status |
|---|---|---|---|
| `player_interacted` | `(target: Node)` | `(target: Node)` | ✓ OK |
| `item_sold` | `(item_id: String, price: float)` | `(instance_id: String, sale_price: float)` | ⚠ Rename params |
| `item_purchased` | `(item_id: String, cost: float)` | `(item_id: String, cost: float)` | ✓ OK (wave-2) |
| `store_opened` | `(store_id: String)` | — | ❓ No issue references this |
| `store_closed` | `(store_id: String)` | — | ❓ No issue references this |
| `customer_entered` | `(customer_data: Dictionary)` | `(customer: Node)` | ⚠ Change param type |
| `customer_left` | `(customer_data: Dictionary)` | `(customer: Node, purchased: bool)` | ⚠ Change signature |
| `day_started` | `(day: int)` | `(day_number: int)` | ✓ OK (param name cosmetic) |
| `day_ended` | `(day: int)` | `(day_number: int)` | ✓ OK (param name cosmetic) |
| `hour_changed` | `(hour: int)` | `(hour: int)` | ✓ OK |
| `notification_requested` | `(message: String)` | `(message: String)` | ✓ OK (future use) |

## New Signals (to be added by wave-1 issues)

### Time System (issue-009)

```gdscript
signal time_speed_changed(speed: float)
```
- **Emitted by**: TimeSystem when player changes speed (1/2/3/Space keys)
- **Listened by**: HUD (issue-013) for speed indicator display

### Economy System (issue-010)

```gdscript
signal money_changed(old_amount: float, new_amount: float)
signal expense_deducted(amount: float, reason: String)
```
- **money_changed emitted by**: EconomySystem on every cash change (sales, expenses)
- **money_changed listened by**: HUD (issue-013) for cash display
- **expense_deducted emitted by**: EconomySystem when rent/costs are paid
- **expense_deducted listened by**: DaySummary (issue-014) for expense tracking

### Inventory System (issue-005)

```gdscript
signal item_stocked(instance_id: String, fixture_id: String, slot_index: int)
signal item_removed_from_shelf(instance_id: String)
signal item_added_to_inventory(instance_id: String)
```
- **item_stocked emitted by**: InventorySystem when item placed on shelf
- **item_stocked listened by**: ShelfSlot (issue-006), InventoryPanel (issue-007)
- **item_removed_from_shelf emitted by**: InventorySystem when item returned to backroom
- **item_removed_from_shelf listened by**: ShelfSlot (issue-006), InventoryPanel (issue-007)
- **item_added_to_inventory emitted by**: InventorySystem when new item created
- **item_added_to_inventory listened by**: InventoryPanel (issue-007)

### Shelf Interaction (issue-006)

```gdscript
signal shelf_slot_activated(fixture_id: String, slot_index: int, allowed_categories: PackedStringArray)
signal inventory_item_selected(instance_id: String)
signal price_panel_requested(instance_id: String)
```
- **shelf_slot_activated emitted by**: ShelfSlot when player interacts with empty slot
- **shelf_slot_activated listened by**: InventoryPanel (issue-007) to open in placement mode
- **inventory_item_selected emitted by**: InventoryPanel when player picks an item for placement
- **inventory_item_selected listened by**: ShelfSlot (issue-006) to complete placement
- **price_panel_requested emitted by**: ShelfSlot context menu "Set Price" button
- **price_panel_requested listened by**: PricePanel (issue-008)

### Price Setting (issue-008)

```gdscript
signal price_set(instance_id: String, price: float)
```
- **Emitted by**: PricePanel when player confirms a price
- **Listened by**: ShelfSlot (issue-006) to update price tag Label3D

### Reputation System (issue-018)

```gdscript
signal reputation_changed(old_value: float, new_value: float)
```
- **Emitted by**: ReputationSystem on every reputation modification
- **Listened by**: HUD (issue-013) for reputation display
- **Note**: Already declared in event_bus.gd? No — not currently present. Must be added.

## Complete Canonical Signal List

This is the full set of signals that `event_bus.gd` should declare after all wave-1 issues are implemented:

```gdscript
extends Node

# Player (issue-003)
signal player_interacted(target: Node)

# Time (issue-009)
signal day_started(day_number: int)
signal day_ended(day_number: int)
signal hour_changed(hour: int)
signal time_speed_changed(speed: float)

# Economy (issue-010)
signal item_sold(instance_id: String, sale_price: float)
signal money_changed(old_amount: float, new_amount: float)
signal expense_deducted(amount: float, reason: String)

# Inventory (issue-005)
signal item_stocked(instance_id: String, fixture_id: String, slot_index: int)
signal item_removed_from_shelf(instance_id: String)
signal item_added_to_inventory(instance_id: String)

# Shelf interaction (issue-006)
signal shelf_slot_activated(fixture_id: String, slot_index: int, allowed_categories: PackedStringArray)
signal inventory_item_selected(instance_id: String)
signal price_panel_requested(instance_id: String)

# Pricing (issue-008)
signal price_set(instance_id: String, price: float)

# Customer (issue-011)
signal customer_entered(customer: Node)
signal customer_left(customer: Node, purchased: bool)

# Reputation (issue-018)
signal reputation_changed(old_value: float, new_value: float)

# UI (future)
signal notification_requested(message: String)

# Store lifecycle (future — no wave-1 issue uses these yet)
signal store_opened(store_id: String)
signal store_closed(store_id: String)

# Ordering (wave-2, issue-025)
signal item_purchased(item_id: String, cost: float)
```

## Removed/Deprecated Signals

None yet. `store_opened` and `store_closed` are declared but unused by any wave-1 issue. Keep them for wave-2 (issue-046, store unlock system).

## Cross-Issue Signal Flow Diagram

```
Player presses E on shelf slot
  → shelf_slot_activated (ShelfSlot → InventoryPanel)
  → Player selects item
  → inventory_item_selected (InventoryPanel → ShelfSlot)
  → item_stocked (InventorySystem → ShelfSlot, InventoryPanel)

Player sets price on stocked item
  → price_panel_requested (ShelfSlot → PricePanel)
  → price_set (PricePanel → ShelfSlot)

Customer buys item
  → item_sold (EconomySystem → ReputationSystem, DaySummary log)
  → money_changed (EconomySystem → HUD)
  → item_removed_from_shelf (InventorySystem → ShelfSlot, InventoryPanel)
  → customer_left (CustomerAI → DaySummary log)
  → reputation_changed (ReputationSystem → HUD)

Day cycle
  → hour_changed (TimeSystem → HUD, CustomerSpawner)
  → day_ended (TimeSystem → GameManager → ReputationSystem, EconomySystem)
  → day_started (GameManager → TimeSystem, EconomySystem)
  → time_speed_changed (TimeSystem → HUD)
```
