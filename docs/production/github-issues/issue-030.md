# Issue 030: Implement daily operating costs and expense tracking

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `gameplay`, `balance`, `phase:m2`, `priority:medium`
**Dependencies**: issue-009, issue-010

## Why This Matters

Operating costs create the financial pressure that makes revenue meaningful. Without daily expenses, the player has no incentive to optimize — they can just wait indefinitely. Rent is the clock that drives urgency without being punitive (Pillar 3: Cozy Simulation — no fail states).

## Current State

- `pricing_config.json` defines `daily_rent`: 50.00 (flat value, single size)
- `store_definitions.json` defines each store with a `daily_rent` field that overrides the global default
- EconomySystem (issue-010) has `deduct_expense(amount, reason)` and tracks daily expenses in the transaction log
- The day summary (issue-014) already reads `expenses` from `get_daily_summary()`

### Rent Values Per Store (from store_definitions.json)

| Store | daily_rent |
|---|---|
| sports | $50 |
| retro_games | $55 |
| rentals | $60 |
| pocket_creatures | $45 |
| electronics | $65 |

These values come from the store definition JSON, not hardcoded constants.

## Implementation Spec

### Rent Deduction Flow

Rent is deducted at the start of each day (on `day_started`), not at `day_ended`. This way the player sees their available cash for the day after rent is paid.

```gdscript
# In EconomySystem or a lightweight OperatingCostsManager:
func _on_day_started(day_number: int) -> void:
    var store_def := _data_loader.get_store(_current_store_id)
    if store_def:
        var rent := store_def.daily_rent
        deduct_expense(rent, "Rent")
```

### Integration with EconomySystem

EconomySystem already has the expense tracking infrastructure from issue-010:

```gdscript
func deduct_expense(amount: float, reason: String) -> void:
    _cash -= amount
    _daily_log.total_expenses += amount
    _daily_log.expenses.append({"amount": amount, "reason": reason})
    EventBus.money_changed.emit(_cash + amount, _cash)
```

This issue adds the automatic daily trigger — no new class needed. The rent deduction is wired directly into EconomySystem's `day_started` handler.

### Negative Cash Handling

Per Pillar 3 (Cozy Simulation, no fail states), the game does NOT end when cash hits zero:

- Cash can go negative (the player is "in debt")
- A warning notification fires when cash drops below $0: `EventBus.notification_requested.emit("Warning: You're in the red! Consider lowering prices to boost sales.")`
- A second warning at -$200: `"Debt is mounting. You may need to sell some backroom stock."`
- Cash display in HUD turns red when negative
- No additional penalties — the player can recover by selling inventory
- This is intentionally forgiving; the debt acts as feedback, not punishment

### Daily Expense Breakdown (for Day Summary)

The day summary already shows total expenses. With this issue, the `expenses` array in the daily log includes itemized entries:

```gdscript
# In get_daily_summary():
"expenses_breakdown": [
    {"amount": 50.0, "reason": "Rent"},
    {"amount": 120.0, "reason": "Stock Order"},  # From issue-025
]
```

The day summary screen can optionally show this breakdown (tooltip or expandable section).

### Future Extensibility

This issue only implements rent. Future costs (tracked but not built here):
- Utilities (wave-3, scales with store size and fixture count)
- Staff wages (wave-4, issue-064)
- Event hosting fees (wave-3, issue-053)

All future costs will use the same `deduct_expense(amount, reason)` API.

### Signal Wiring

No new signals needed. Uses existing:
- `EventBus.day_started` → trigger rent deduction
- `EventBus.money_changed` → HUD updates
- `EventBus.notification_requested` → debt warnings

## Deliverables

- Rent deduction on `day_started` using store definition's `daily_rent` value
- Debt warning notifications at $0 and -$200 thresholds
- HUD cash display turns red when negative (coordinate with issue-013)
- Expense entries include reason strings for day summary breakdown

## Acceptance Criteria

- Rent deducts automatically at the start of each day
- Rent amount matches the current store's `daily_rent` from store_definitions.json
- Day summary shows rent as a line item in expenses
- Cash can go below zero without crashing or ending the game
- Warning notification appears when cash first drops below $0
- Second warning at -$200
- HUD shows negative cash in red
- `money_changed` signal fires with correct old/new values after rent

## Test Plan

1. Start new game with $500 — verify $50 rent deducted on day 1 start (cash = $450)
2. Advance 10 days with no sales — verify cash = $500 - (50 × 10) = $0
3. Advance one more day — verify cash = -$50, warning notification appears
4. Advance to -$200 — verify second warning
5. Sell an item — verify cash increases and warnings don't re-fire until next threshold crossing
6. Check day summary — verify rent appears in expense breakdown
7. Save and reload — verify cash balance (including negative) persists correctly
8. Open a different store type — verify that store's specific `daily_rent` is used