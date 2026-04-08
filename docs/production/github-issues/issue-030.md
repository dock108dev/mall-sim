# Issue 030: Implement daily operating costs and expense tracking

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `gameplay`, `balance`, `phase:m2`, `priority:medium`
**Dependencies**: issue-009, issue-010

## Why This Matters

Operating costs create the financial pressure that makes revenue meaningful.

## Scope

Rent deducted daily based on store size (from pricing_config daily_rent_per_size). Track daily expenses separately for summary screen. Future: utilities, staff wages.

## Deliverables

- Rent deducted on day_ended signal
- Rent amount based on store size category
- Daily expense total tracked for summary
- EventBus.expense_incurred signal

## Acceptance Criteria

- Rent deducts each day
- Small store: $50/day, medium: $120, large: $250
- Day summary shows correct expense total
- Cash can't go negative (warning logged)
