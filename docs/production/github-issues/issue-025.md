# Issue 025: Implement stock ordering system

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `gameplay`, `ui`, `phase:m2`, `priority:high`
**Dependencies**: issue-001, issue-005, issue-010, issue-014

## Why This Matters

Ordering is how the player grows their business beyond starter inventory. Without it, the game ends when the shelves are empty. This closes the core loop: stock shelves → sell to customers → order more stock → repeat.

## Current State

No ordering system exists. The end-of-day summary (issue-014) provides a natural transition point into the ordering phase. EconomySystem (issue-010) handles cash tracking. DataLoader (issue-001) provides the item catalog. InventorySystem (issue-005) manages item instances.

## Design

### Ordering Flow

```
Day ends → Summary screen → "Order Stock" button
  |
  v
Catalog UI opens
  |-- Browse available items (filtered by supplier tier)
  |-- Add items to order cart
  |-- See running total vs. available cash
  |-- Confirm order
  v
Order confirmed
  |-- Cash deducted immediately via EconomySystem
  |-- Order queued in pending_orders
  |-- EventBus.order_placed emitted
  v
Next day_started signal
  |-- Pending orders with delivery_day == current_day are fulfilled
  |-- For each ordered item: create ItemInstance in backroom
  |-- EventBus.order_delivered emitted
  |-- Notification: "Your order has arrived! Check the backroom."
```

### Wholesale Pricing

Items are ordered at wholesale cost, not market value:
- **Wholesale cost** = `base_price * condition_avg_multiplier * wholesale_discount`
- `wholesale_discount` = `0.6` (player buys at 60% of good-condition market value)
- Ordered items arrive in random condition weighted toward good/near_mint:
  - poor: 5%, fair: 15%, good: 40%, near_mint: 30%, mint: 10%
- The margin between wholesale cost and sale price is the player's profit opportunity

### Supplier Tiers

The catalog is filtered by the player's current supplier tier (managed by issue-040). For M2, implement a simplified version:
- **Tier 1** (default): common and uncommon items only
- **Tier 2** (reputation ≥ 25): adds rare items
- **Tier 3** (reputation ≥ 50): adds very_rare and legendary items

Tier thresholds come from `pricing_config.json` (add `supplier_tiers` section if not present). For M2, hardcode tier checks against reputation; issue-040 formalizes this.

### Order Data Structure

```gdscript
# Stored in ordering_system.gd
var _pending_orders: Array[Dictionary] = []

# Each order:
# {
#   "order_id": "order_001",
#   "items": [
#     {"item_id": "sports_griffey_rookie", "quantity": 2, "unit_cost": 3.00},
#     {"item_id": "sports_jordan_auto_ball", "quantity": 1, "unit_cost": 180.00}
#   ],
#   "total_cost": 186.00,
#   "placed_day": 3,
#   "delivery_day": 4
# }
```

### Catalog Data

The catalog is not a separate data file — it's derived at runtime from DataLoader:
1. Get all items for the current store type via `DataLoader.get_items_by_store(store_type)`
2. Filter by current supplier tier (rarity gate)
3. Calculate wholesale cost for each item
4. Present in the Catalog UI

## Implementation Spec

### Step 1: OrderingSystem Script

Create `game/scripts/systems/ordering_system.gd` extending Node:

```gdscript
class_name OrderingSystem extends Node

var _pending_orders: Array[Dictionary] = []
var _next_order_id: int = 1
var _current_store_type: String = ""
var _wholesale_discount: float = 0.6

# Called by GameManager when game starts
func initialize(store_type: String) -> void

# Get items available for ordering at current tier
func get_catalog(reputation_score: float) -> Array[Dictionary]
  # Returns: [{"definition": ItemDefinition, "wholesale_cost": float, "available": bool}]

# Place an order, returns true if cash sufficient
func place_order(items: Array[Dictionary], economy: EconomySystem) -> bool
  # items: [{"item_id": String, "quantity": int}]
  # Calculates total, checks cash, deducts via economy.deduct_expense()
  # Creates pending order, emits EventBus.order_placed

# Called on day_started — delivers pending orders
func process_deliveries(current_day: int, inventory: InventorySystem) -> Array[Dictionary]
  # Returns list of delivered orders
  # For each item in delivered order: inventory.create_instance() with random condition
  # Emits EventBus.order_delivered for each order

# For save/load
func get_save_data() -> Dictionary
func load_save_data(data: Dictionary) -> void
```

### Step 2: Catalog UI

Create `game/scenes/ui/catalog_panel.tscn` and `game/scripts/ui/catalog_panel.gd`.

#### Scene Structure

```
CatalogPanel (PanelContainer)
  +- VBoxContainer
  |  +- Header (HBoxContainer)
  |  |  +- TitleLabel ("Supplier Catalog")
  |  |  +- CashLabel ("Cash: $1,250.00")
  |  |  +- CartTotalLabel ("Cart: $0.00")
  |  +- FilterBar (HBoxContainer)
  |  |  +- CategoryFilter (OptionButton) — All / Cards / Equipment / Sealed / etc.
  |  |  +- SortButton (OptionButton) — Price ↑ / Price ↓ / Name / Rarity
  |  +- ScrollContainer
  |  |  +- ItemGrid (GridContainer, 1 column)
  |  |     +- CatalogItemRow (repeated)
  |  |        +- ItemName (Label)
  |  |        +- Category (Label)
  |  |        +- Rarity (Label, color-coded)
  |  |        +- WholesalePrice (Label, "$3.00")
  |  |        +- QuantitySpinner (SpinBox, min 0, max 10)
  |  +- Footer (HBoxContainer)
  |     +- OrderSummaryLabel ("3 items, $186.00")
  |     +- ConfirmButton ("Place Order")
  |     +- CancelButton ("Close")
```

#### UI Behavior

- Opens from the day summary screen ("Order Stock" button) or via `C` key during evening phase
- Shows wholesale cost, not market value (player sees what they pay)
- Quantity spinner per item (0 = not ordering)
- Running cart total updates as quantities change
- Confirm button disabled if cart total > available cash
- Confirm button disabled if cart is empty
- After confirming: brief "Order placed!" feedback, panel closes
- Items the player already has in stock are still orderable (can stock multiples)

### Step 3: EventBus Signals

Add to `game/autoload/event_bus.gd`:
```gdscript
signal order_placed(order_id: String, total_cost: float)
signal order_delivered(order_id: String, item_count: int)
```

### Step 4: Integration Points

- **DaySummary (issue-014)**: Add "Order Stock" button that opens CatalogPanel
- **GameManager**: Instantiate OrderingSystem as child, call `process_deliveries()` on `day_started`
- **EconomySystem**: Orders use `deduct_expense(amount, "stock_order")` for daily log tracking
- **InventorySystem**: Delivered items created via `create_instance()` with random condition
- **HUD notification**: Show "Delivery arrived: X items" on day start if orders were delivered

### Step 5: Constants

Add to `game/scripts/core/constants.gd`:
```gdscript
const WHOLESALE_DISCOUNT: float = 0.6
const MAX_ORDER_QUANTITY_PER_ITEM: int = 10
const ORDER_DELIVERY_DELAY_DAYS: int = 1
const ORDER_CONDITION_WEIGHTS: Dictionary = {
    "poor": 0.05, "fair": 0.15, "good": 0.40, "near_mint": 0.30, "mint": 0.10
}
```

## Deliverables

- `game/scripts/systems/ordering_system.gd` — order management, catalog generation, delivery processing
- `game/scenes/ui/catalog_panel.tscn` — catalog UI scene
- `game/scripts/ui/catalog_panel.gd` — catalog UI logic
- EventBus signals: `order_placed`, `order_delivered`
- Constants for wholesale discount, delivery delay, condition weights
- Integration with DaySummary, GameManager, EconomySystem, InventorySystem
- Save/load support via `get_save_data()` / `load_save_data()`

## Acceptance Criteria

- Open catalog from day summary: see all items available at current tier with wholesale prices
- Filter by category: only matching items shown
- Add items to cart: running total updates, reflects actual wholesale cost
- Place order with sufficient cash: cash deducted immediately, order confirmation shown
- Place order with insufficient cash: confirm button disabled, cart total shown in red
- Next day_started: items appear in backroom as ItemInstances with random conditions
- Ordered items have `acquired_price` set to their wholesale unit cost
- Ordered items have `acquired_day` set to delivery day
- Multiple orders across days are tracked independently
- Empty cart: confirm button disabled
- EventBus.order_placed fires with order_id and total_cost
- EventBus.order_delivered fires with order_id and item_count
- Catalog only shows common/uncommon items at tier 1 (reputation < 25)
- At reputation ≥ 25, rare items appear in catalog
- At reputation ≥ 50, very_rare/legendary items appear

## Test Plan

1. Open catalog, verify item list matches DataLoader items for store type
2. Add 3 items to cart, verify total = sum of wholesale costs × quantities
3. Confirm order, verify cash decreased by total, order in pending list
4. Advance to next day, verify items in backroom with correct definition references
5. Verify items have random conditions (run 10+ deliveries, check distribution)
6. Verify tier filtering by setting reputation to 0, 25, 50 and checking catalog
7. Verify insufficient cash prevents order placement
8. Save game with pending order, load, verify order still delivers next day