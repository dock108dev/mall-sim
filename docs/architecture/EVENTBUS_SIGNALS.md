# EventBus Signal Registry

Consolidated inventory of all EventBus signals across wave-1 and wave-2. Each signal lists its typed parameters, the issue that introduces it, and which systems emit/connect to it.

The EventBus (`game/autoload/event_bus.gd`) is a pure signal broker — no logic, no state.

---

## Current Signals (Phase 0)

These exist in EventBus today:

| Signal | Parameters | Status |
|---|---|---|
| `player_interacted` | `target: Node` | Exists |
| `item_sold` | `item_id: String, price: float` | Exists — **update signature in issue-088** |
| `item_purchased` | `item_id: String, cost: float` | Exists |
| `store_opened` | `store_id: String` | Exists |
| `store_closed` | `store_id: String` | Exists |
| `customer_entered` | `customer_data: Dictionary` | Exists — **update to typed param in issue-088** |
| `customer_left` | `customer_data: Dictionary` | Exists — **update to typed param in issue-088** |
| `day_started` | `day: int` | Exists |
| `day_ended` | `day: int` | Exists |
| `hour_changed` | `hour: int` | Exists |
| `notification_requested` | `message: String` | Exists |

---

## Wave-1 Signal Additions

All wave-1 signals are pre-populated by issue-088 (preflight). Individual system issues verify their signals exist and connect to them.

### Inventory Signals (issue-005)

```gdscript
signal item_stocked(instance_id: String, fixture_id: String, slot_index: int)
signal item_removed_from_shelf(instance_id: String)
signal item_added_to_inventory(instance_id: String)
```

- **Emitted by**: InventorySystem
- **Connected by**: Store scene (visual updates), HUD (stock count), CustomerAI (shelf contents changed)

### Time Signals (issue-009)

```gdscript
signal time_speed_changed(new_speed: int)
signal day_phase_changed(phase: String)  # "morning", "midday", "afternoon", "evening"
```

- **Emitted by**: TimeSystem
- **Connected by**: HUD (speed indicator, phase display), CustomerSpawner (arrival rate), Lighting (ambient changes)
- Note: `day_started`, `day_ended`, `hour_changed` already exist

### Economy Signals (issue-010)

Update existing `item_sold` signature and add new signals:

```gdscript
# Updated signature (was: item_id: String, price: float)
signal item_sold(instance_id: String, sale_price: float)

# New signals
signal money_changed(old_amount: float, new_amount: float)
signal expense_deducted(amount: float, reason: String)
signal transaction_recorded(transaction: Dictionary)
```

- **Emitted by**: EconomySystem
- **Connected by**: HUD (cash display), ReputationSystem (pricing fairness calc), Day Summary (daily totals)

### Customer Signals (issue-011)

Update existing signatures to use typed data:

```gdscript
# Updated signatures
signal customer_entered(customer_id: String, type_id: String)
signal customer_left(customer_id: String, purchased: bool)

# New signals
signal customer_browsing(customer_id: String, fixture_id: String)
signal customer_evaluating(customer_id: String, instance_id: String)
signal customer_waiting_at_register(customer_id: String)
```

- **Emitted by**: CustomerAI state machine
- **Connected by**: Register interaction (issue-012), HUD (customer count), Day Summary (customers served/lost)

### Purchase Flow Signals (issue-012)

```gdscript
signal checkout_started(customer_id: String)
signal checkout_completed(customer_id: String, instance_id: String, sale_price: float)
signal checkout_cancelled(customer_id: String, reason: String)
```

- **Emitted by**: Register/CheckoutUI
- **Connected by**: EconomySystem (process transaction), InventorySystem (mark sold), CustomerAI (leave after purchase), ReputationSystem

### Shelf Interaction Signals (issue-006)

```gdscript
signal shelf_slot_activated(fixture_id: String, slot_index: int, allowed_categories: PackedStringArray)
signal inventory_item_selected(instance_id: String)
signal price_panel_requested(instance_id: String)
```

- **Emitted by**: ShelfSlot / InventoryPanel
- **Connected by**: InventoryPanel (open placement mode), ShelfSlot (complete placement), PricePanel (open)

### Price Setting Signals (issue-008)

```gdscript
signal price_set(instance_id: String, price: float)
```

- **Emitted by**: PricePanel
- **Connected by**: ShelfSlot (update price tag Label3D)

### Reputation Signals (issue-018)

```gdscript
signal reputation_changed(old_value: float, new_value: float)
signal reputation_tier_changed(old_tier: String, new_tier: String)
```

- **Emitted by**: ReputationSystem
- **Connected by**: HUD (reputation display), CustomerSpawner (attraction multiplier), Day Summary

### Interaction Signals (issue-003)

`player_interacted` already exists. No new signals needed.

### GameWorld Orchestration Signals (issue-087)

```gdscript
signal game_initialized()          # All systems loaded, ready to play
signal day_cycle_morning()          # Morning prep phase started
signal day_cycle_open()             # Store is open for business
signal day_cycle_closing()          # Store closing sequence started
signal new_game_started(store_id: String)
```

- **Emitted by**: GameManager / GameWorld
- **Connected by**: All systems (initialization), UI (phase transitions)

---

## Wave-2 Signal Additions (Preview)

### Ordering System (issue-025)

```gdscript
signal order_placed(order: Dictionary)      # {items: [...], total_cost: float}
signal order_delivered(order: Dictionary)   # Next morning delivery
```

### Save/Load (issue-026)

```gdscript
signal save_completed(slot: int)
signal load_completed(slot: int)
```

### Haggling (issue-023)

```gdscript
signal haggle_started(customer_id: String, instance_id: String)
signal haggle_offer(customer_id: String, offer_price: float)
signal haggle_resolved(customer_id: String, accepted: bool, final_price: float)
```

---

## Signal Naming Conventions

- Past tense for events that happened: `item_sold`, `day_ended`, `customer_left`
- Present tense for state changes: `customer_browsing`, `customer_evaluating`
- `_requested` suffix for commands: `notification_requested`
- `_changed` suffix for value updates: `money_changed`, `reputation_changed`
- Use `instance_id` (not `item_id`) when referring to a specific item the player owns
- Use `item_id` (not `instance_id`) when referring to a definition/catalog entry

## Implementation Notes

- Issue-088 pre-populates ALL wave-1 signals in EventBus in a single commit (Batch 0)
- Individual system issues verify their signals exist and wire up connections
- All signals must have typed parameters (no untyped `Variant` unless necessary)
- Signal parameter order: subject first (customer_id, instance_id), then details

## Noted Discrepancy (Resolved)

The `item_sold` signal has two valid signatures depending on context:
- **Wave-1 API contracts (simplified)**: `item_sold(instance_id: String, sale_price: float)` — used by EconomySystem, ReputationSystem, Day Summary
- **Full wave-2 signature**: `item_sold(instance_id: String, sale_price: float, customer_id: String)` — adds customer tracking for analytics

**Decision**: Use the 2-parameter version for M1 (`instance_id, sale_price`). The `customer_id` parameter will be added in wave-2 when customer analytics are implemented. This avoids breaking changes — systems that don't need `customer_id` can ignore the third parameter when it's added.
