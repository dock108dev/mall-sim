# Issue 010: Implement EconomySystem with cash tracking and transactions

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `tech`, `phase:m1`, `priority:high`
**Dependencies**: issue-001

## Why This Matters

Money is how the player knows if they're winning or losing. The EconomySystem also owns the market value calculation that the pricing UI, customer AI, and reputation system all depend on.

## Current State

No EconomySystem script exists. EventBus has `item_sold(item_id, price)` and `item_purchased(item_id, cost)` signals. Pricing config exists at `game/content/economy/pricing_config.json` with condition multipliers, rarity multipliers, and demand modifiers.

## Design

### Cash Tracking

- Player cash balance: single float, starts at store definition's `starting_cash` (loaded via DataLoader)
- Cash is global (shared across stores if player has multiple — future consideration, M1 is single-store)
- Cash cannot go below 0.0 — operations that would make it negative return false

### Market Value Calculation

This is the canonical formula used throughout the game for M1:

```
market_value = base_price × condition_multiplier
```

Where:
- `base_price` — from ItemDefinition. This is the item's market value at "good" condition. It **already reflects the item's rarity** (a rare rookie card has base_price $75, not $2).
- `condition_multiplier` — from pricing_config.json `condition_multipliers` (poor=0.25, fair=0.5, good=1.0, near_mint=1.5, mint=2.0)

**Examples:**
- Common card, base_price $2.00, good condition → market_value = $2.00 × 1.0 = $2.00
- Common card, base_price $2.00, mint condition → market_value = $2.00 × 2.0 = $4.00
- Rare rookie, base_price $75.00, near_mint → market_value = $75.00 × 1.5 = $112.50
- Legendary card, base_price $1200.00, poor → market_value = $1200.00 × 0.25 = $300.00

> **Design note — rarity_multiplier and demand_modifier**: The `rarity_multipliers` table in pricing_config.json (common=1.0, uncommon=2.5, rare=6.0, very_rare=15.0, legendary=40.0) exists for content generation tooling and future supplier/wholesale pricing (issue-025, issue-040). It is NOT applied to market_value because base_price already encodes rarity. The `demand_modifier` defaults to 1.0 for M1 and will be used by issue-024 (dynamic pricing) and issue-050 (trend system) in later waves. When those features land, the formula becomes: `market_value = base_price × condition_multiplier × demand_modifier`.

### Price Suggestion

The UI (issue-008) needs a suggested retail price. The EconomySystem provides:

```gdscript
func get_market_value(item: ItemInstance) -> float:
    var condition_mult = _condition_multipliers[item.condition]
    return item.definition.base_price * condition_mult

func get_suggested_price(item: ItemInstance) -> float:
    return get_market_value(item) * _config.markup_ranges.default  # 1.35x
```

### Transaction Processing

```gdscript
func complete_sale(instance_id: String, sale_price: float) -> bool:
    # 1. Add sale_price to cash
    # 2. Mark item as sold via InventorySystem
    # 3. Emit EventBus.item_sold
    # 4. Emit EventBus.money_changed
    # 5. Record in daily transaction log
    return true

func deduct_expense(amount: float, reason: String) -> bool:
    # Returns false if insufficient funds
    if _cash < amount:
        return false
    _cash -= amount
    EventBus.money_changed.emit(_cash + amount, _cash)
    return true
```

### Daily Transaction Log

Track for end-of-day summary (issue-014):
```gdscript
var _daily_log: Dictionary = {
    "sales": [],        # [{instance_id, item_name, sale_price, market_value}]
    "expenses": [],     # [{amount, reason}]
    "total_revenue": 0.0,
    "total_expenses": 0.0
}
var _daily_customers_served: int = 0
var _daily_customers_lost: int = 0
```

Reset on `day_started`. Read by end-of-day summary screen.

### Customer Counting

EconomySystem connects to `EventBus.customer_left(customer_id, purchased)` to count served/lost:
```gdscript
func _on_customer_left(_customer_id: String, purchased: bool) -> void:
    if purchased:
        _daily_customers_served += 1
    else:
        _daily_customers_lost += 1
```

### Daily Summary (for issue-014)

**Cross-reference**: See `docs/production/WAVE1_API_CONTRACTS.md` Contract 1 for the authoritative specification of this method.

```gdscript
func get_daily_summary() -> Dictionary:
    return {
        "day": _current_day,
        "revenue": _daily_log.total_revenue,
        "expenses": _daily_log.total_expenses,
        "items_sold": _daily_log.sales.map(
            func(s): return {"item_name": s.item_name, "sale_price": s.sale_price}
        ),
        "customers_served": _daily_customers_served,
        "customers_lost": _daily_customers_lost
    }
```

This method transforms the internal log into the format expected by the Day Summary screen (issue-014).

## Deliverables

- `game/scripts/systems/economy_system.gd` extending Node
- Cash balance tracking with `money_changed` signal
- `get_market_value(item: ItemInstance) -> float` — canonical market value
- `get_suggested_price(item: ItemInstance) -> float` — suggested retail (market × 1.35)
- `complete_sale(instance_id, sale_price) -> bool` — processes sale
- `deduct_expense(amount, reason) -> bool` — processes expense
- `get_daily_log() -> Dictionary` — detailed daily transaction log
- `get_daily_summary() -> Dictionary` — aggregated summary for day summary screen (see API contract)
- `reset_daily_log()` — connected to `day_started`, also resets customer counters
- Customer served/lost counting via `customer_left` signal connection
- Daily rent deduction connected to `day_ended` signal
- Loads multiplier tables from pricing_config.json via DataLoader

## Acceptance Criteria

- Starting cash matches store definition's `starting_cash` value
- `get_market_value` for a $10 base_price item at near_mint returns $15.00 (10 × 1.5)
- `get_market_value` for a $10 base_price item at poor returns $2.50 (10 × 0.25)
- `get_suggested_price` returns market_value × 1.35
- `complete_sale` adds cash, emits `item_sold` and `money_changed`
- `deduct_expense` subtracts cash, returns false if insufficient
- Daily rent deduction fires on `day_ended` using store's `daily_rent` value
- Cash never goes below 0
- `money_changed` fires on every cash change with old and new values
- Daily log tracks all sales and expenses, resets on new day
- `get_daily_summary()` returns correct format with day, revenue, expenses, items_sold array, customers_served, customers_lost
- Customer served/lost counts match actual `customer_left` signal emissions

## Test Plan

1. Initialize EconomySystem with sports store definition — verify starting cash is $500
2. Call `get_market_value` on items at each condition level — verify multiplier math
3. Call `get_suggested_price` — verify it returns market_value × 1.35
4. Call `complete_sale` — verify cash increases, signals fire, daily log updated
5. Call `deduct_expense` with amount > cash — verify returns false, cash unchanged
6. Call `deduct_expense` with valid amount — verify cash decreases, signal fires
7. Emit `day_started` — verify daily log resets, customer counters reset
8. Emit `day_ended` — verify rent deducted from cash
9. Emit `customer_left` with purchased=true/false — verify counters update
10. Call `get_daily_summary()` after sales and customer events — verify all fields populated correctly