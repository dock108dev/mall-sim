# Issue 025: Implement stock ordering system

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `gameplay`, `ui`, `phase:m2`, `priority:high`
**Dependencies**: issue-005, issue-010, issue-014

## Why This Matters

Ordering is how the player grows their business beyond starting inventory.

## Scope

Player can order new inventory from a catalog. Orders placed during evening phase. Delivered next morning. Cost deducted immediately. Catalog shows available items based on supplier tier.

## Deliverables

- Catalog UI panel (available items, prices, quantities)
- Order placement deducts cash
- Orders tracked as pending
- Delivery on next day_started signal
- Delivered items appear in backroom

## Acceptance Criteria

- Open catalog: see available items with prices
- Place order: cash deducted
- Next morning: items in backroom
- Can't order if insufficient cash
- Catalog respects supplier tier limits
