# Issue 012: Implement purchase flow at register

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `ui`, `phase:m1`, `priority:high`
**Dependencies**: issue-004, issue-010, issue-011

## Why This Matters

This closes the core loop: stock → price → customer buys → money. Without the register, the player can stock shelves and watch customers browse, but nothing happens.

## Current State

The checkout counter fixture exists in the sports store scene (issue-004) with a `RegisterPosition` Marker3D where the customer stands to pay. The `Interactable` base class (issue-003) provides the interaction trigger. EconomySystem (issue-010) handles the cash transaction. The customer state machine (issue-011) has a `PURCHASING` state that moves the customer to the register and waits.

## Design

### Checkout Flow

```
Customer reaches PURCHASING state
  → Walks to RegisterPosition Marker3D
  → Holds their chosen item (stored as ItemInstance ref on customer)
  → Patience timer starts (15-30 seconds based on customer patience stat)
  |
  v
Player interacts with register (Interactable Area3D)
  → CheckoutUI overlay appears
  → Game time pauses (TimeSystem.set_time_speed(0))
  → UI shows item details and customer info
  |
  +-- Player clicks CONFIRM:
  |     → EconomySystem.complete_sale(item, sale_price)
  |     → InventorySystem.mark_sold(instance_id, sale_price)
  |     → ReputationSystem receives sale event (price ratio → rep delta)
  |     → EventBus.item_sold.emit(instance_id, sale_price)
  |     → Customer transitions to LEAVING (happy)
  |     → CheckoutUI hides, time resumes
  |     → Ka-ching SFX + cash animation
  |
  +-- Player clicks REJECT:
  |     → Customer transitions to LEAVING (unhappy)
  |     → ReputationSystem.adjust(-1.0) (mild penalty for rejection)
  |     → Item stays on shelf (customer puts it back conceptually)
  |     → CheckoutUI hides, time resumes
  |
  +-- Patience timer expires (player ignores customer):
        → Customer transitions to LEAVING (unhappy)
        → ReputationSystem.adjust(-2.0) (larger penalty for being ignored)
        → Item stays on shelf
        → Prompt flashes briefly: "Customer left — too slow!"
        → No CheckoutUI interaction needed
```

### Customer Patience Timer

When a customer enters PURCHASING state and reaches the register:
- `wait_time = customer.browse_time_range[0] * customer.patience` (lower bound scaled by patience)
- For M1, this is roughly 10-25 seconds of real time at 1x speed
- A visual indicator shows on the customer (patience bar or foot-tapping animation placeholder)
- Timer pauses when CheckoutUI is open (player is already interacting)
- If multiple customers queue, they wait in order at WaitPosition Marker3Ds

### Queue Behavior (M1 Simplified)

For M1, only one customer can be at the register at a time. If a second customer enters PURCHASING while the register is occupied:
- They stand at WaitPosition Marker3D
- Their patience timer starts with +10 seconds bonus (queuing grace)
- When the first customer finishes (sale, reject, or timeout), the next customer steps up
- If their patience runs out while waiting, they leave (same as timeout)

## Scene Structure

```
CheckoutUI (Control) — full-screen overlay, hidden by default
  +- PanelContainer (centered, ~400x350px)
  |    +- VBoxContainer
  |         +- TitleLabel ("Checkout")
  |         +- HSeparator
  |         +- ItemSection (HBoxContainer)
  |         |    +- ItemIcon (TextureRect, 64x64)
  |         |    +- ItemDetails (VBoxContainer)
  |         |         +- ItemNameLabel ("1986 Rookie Card - MJ")
  |         |         +- ConditionLabel ("Condition: Near Mint")
  |         |         +- RarityLabel ("Rarity: Rare")
  |         +- HSeparator
  |         +- PriceSection (VBoxContainer)
  |         |    +- SalePriceLabel ("Sale Price: $675.00") — the player_set_price
  |         |    +- MarketValueLabel ("Market Value: $540.00") — for reference
  |         |    +- MarginLabel ("+$270.00 profit" or "-$50.00 loss") — sale_price - acquired_price
  |         +- HSeparator
  |         +- CustomerSection (HBoxContainer)
  |         |    +- CustomerTypeLabel ("Serious Collector")
  |         |    +- BudgetHintLabel ("Willing to pay this price" or "Stretching their budget")
  |         +- HSeparator
  |         +- ButtonRow (HBoxContainer, centered)
  |              +- ConfirmButton ("Sell — $675.00")
  |              +- RejectButton ("Decline")
  +- BackgroundDim (ColorRect, full-screen, semi-transparent black)
```

### Budget Hint Logic

The BudgetHintLabel gives the player a soft signal about price fairness without revealing exact willingness:
- If sale_price <= customer's willingness_to_pay * 0.8: "Happy to pay this!"
- If sale_price <= customer's willingness_to_pay: "Willing to pay this price"
- If sale_price <= customer's willingness_to_pay * 1.2: "Stretching their budget"
- If sale_price > customer's willingness_to_pay * 1.2: should not reach register (customer rejects in EVALUATING)

## Script: `game/scripts/ui/checkout_ui.gd`

```
extends Control

# References set via @export or @onready
var _current_customer: Node  # the customer at register
var _current_item: ItemInstance

func show_checkout(customer: Node, item: ItemInstance) -> void:
    _current_customer = customer
    _current_item = item
    # Populate all labels from item and customer data
    # Pause time
    # Show self + background dim
    visible = true

func _on_confirm_pressed() -> void:
    # EconomySystem.complete_sale(_current_item, _current_item.player_set_price)
    # InventorySystem.mark_sold(_current_item.instance_id, _current_item.player_set_price)
    # EventBus.item_sold.emit(...)
    # Resume time
    # Hide self
    _current_customer.complete_purchase(true)
    visible = false

func _on_reject_pressed() -> void:
    # ReputationSystem.adjust(-1.0)
    # Resume time
    _current_customer.complete_purchase(false)
    visible = false
```

## Register Interaction

The checkout counter's `RegisterPosition` area is an `Interactable` (from issue-003). Its `interact()` method:
1. Checks if a customer is in PURCHASING state at the register
2. If yes: opens CheckoutUI with that customer and their chosen item
3. If no: shows a brief message "No customer waiting" (or does nothing)

## EventBus Signals Used

- `item_sold(instance_id: String, sale_price: float)` — emitted on confirmed sale
- `customer_left(customer_data, purchased: bool)` — emitted by customer on leaving
- `reputation_changed(old_value: float, new_value: float)` — emitted by ReputationSystem

## Deliverables

- `game/scripts/ui/checkout_ui.gd` — checkout overlay Control script
- `game/scenes/ui/checkout_ui.tscn` — checkout UI scene
- Register Interactable script that opens CheckoutUI when customer is waiting
- Customer patience timer implementation (in customer state machine or register controller)
- Confirm flow: EconomySystem.complete_sale → InventorySystem.mark_sold → signals
- Reject flow: reputation penalty → customer leaves
- Timeout flow: larger penalty → customer leaves automatically

## Acceptance Criteria

- Customer at register + player interacts: checkout UI appears with correct item/price/customer info
- Confirm sale: cash increases by sale_price, item removed from inventory, customer leaves happy
- Reject sale: customer leaves, no cash change, small reputation penalty (-1.0)
- Player ignores customer too long: customer leaves automatically, larger reputation penalty (-2.0)
- Sale price shown matches player_set_price on the item
- Profit/loss calculated correctly (sale_price - acquired_price)
- Time pauses while checkout UI is open
- Only one checkout can be active at a time
- If no customer is at register, interaction does nothing meaningful