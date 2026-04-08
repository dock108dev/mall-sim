# Issue 075: Implement rental lifecycle for video rental store

**Wave**: wave-5
**Milestone**: M5 Store Expansion
**Labels**: `gameplay`, `store:rentals`, `phase:m4plus`, `priority:medium`
**Dependencies**: issue-042, issue-052

## Why This Matters

Rental lifecycle is the video store's fundamental difference from sales-based stores.

## Scope

Full rental lifecycle: customer rents item, item leaves inventory, returns after N days. Late returns incur fees. Some items damaged on return. Wear tracking reduces condition over time.

## Deliverables

- Rental tracking: item_id, customer, due_date, returned
- Return processing on day_started
- Late fee calculation and collection
- Damage chance on return (condition reduction)
- Tape wear: condition degrades with each rental cycle
- Lost item handling (rare, insurance cost)

## Acceptance Criteria

- Rented items leave inventory
- Items return on or after due date
- Late fees are collected
- Condition degrades over multiple rentals
- Lost items are handled gracefully
