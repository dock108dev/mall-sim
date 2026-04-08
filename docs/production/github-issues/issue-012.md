# Issue 012: Implement purchase flow at register

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `phase:m1`, `priority:high`
**Dependencies**: issue-010, issue-011

## Why This Matters

This closes the core loop: stock -> price -> customer buys -> money.

## Scope

Customer waits at register with item. Player interacts with register. Confirmation UI shows item, price, customer. Player confirms or rejects. On confirm: cash added, item removed from inventory, customer leaves happy. On reject: customer leaves, small reputation penalty.

## Deliverables

- Register interaction triggers checkout UI
- UI shows: item name, condition, sale price, customer type
- Confirm button: completes sale via EconomySystem
- Reject button: customer leaves
- EventBus.item_sold signal on completion
- Customer patience timer (leaves if ignored too long)

## Acceptance Criteria

- Customer at register: interact shows checkout UI
- Confirm: cash increases, item removed, customer leaves
- Reject: customer leaves, no cash change
- Ignored too long: customer leaves automatically
