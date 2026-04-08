# Issue 023: Implement haggling mechanic

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `gameplay`, `phase:m2`, `priority:medium`
**Dependencies**: issue-012

## Why This Matters

Haggling adds tension to every sale and rewards knowledge of item values.

## Scope

Some customer types counter-offer instead of accepting sticker price. Player can accept, reject, or counter. Rejection causes customer to leave with small reputation impact. Collector types haggle more aggressively.

## Deliverables

- Haggling state in checkout flow
- Customer generates counter-offer based on type and price gap
- UI shows offer/counter-offer
- Accept/reject/counter buttons
- Reputation impact on reject

## Acceptance Criteria

- Price-sensitive customer makes counter-offer
- Player can accept lower price
- Player can reject (customer leaves)
- Collectors haggle for condition-appropriate premium
