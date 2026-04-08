# Issue 010: Implement EconomySystem with cash tracking and transactions

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `tech`, `phase:m1`, `priority:high`
**Dependencies**: issue-001

## Why This Matters

Money is how the player knows if they're winning or losing.

## Scope

EconomySystem tracks player cash. Processes sales (add cash, remove item). Processes expenses (rent deduction on day end). Emits money_changed signal.

## Deliverables

- EconomySystem tracks cash balance (starts at Constants.STARTING_CASH)
- complete_sale(item_instance, sale_price) -> adds cash, emits item_sold
- deduct_expense(amount, reason) -> subtracts cash
- Daily rent deduction connected to day_ended signal
- EventBus.money_changed signal

## Acceptance Criteria

- Starting cash is $5000
- Sale adds correct amount
- Rent deducts at day end
- Cash cannot go below 0 (warning, not crash)
- money_changed fires on every change
