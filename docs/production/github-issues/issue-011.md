# Issue 011: Implement one customer with browse-evaluate-purchase state machine

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `phase:m1`, `priority:high`
**Dependencies**: issue-004, issue-005, issue-009

## Why This Matters

Customers are the revenue source. M1 needs at least one working customer to complete the buy-sell loop.

## Scope

Single customer type. CharacterBody3D with capsule mesh. Spawns at store entrance. Walks to shelf via NavigationAgent3D. Browses items. Evaluates price vs willingness. Walks to register or leaves. State machine: ENTERING -> BROWSING -> DECIDING -> PURCHASING -> LEAVING.

## Deliverables

- Customer scene (CharacterBody3D + NavigationAgent3D + capsule mesh)
- State machine with 5 states
- Browse: walk to random shelf, pause, pick item
- Decide: compare price to budget/preference
- Purchase: walk to register, wait for player
- Leave: walk to exit, queue_free
- CustomerSpawner node spawns one customer on timer

## Acceptance Criteria

- Customer walks in, browses shelves, picks an item
- If price acceptable: walks to register
- If too expensive: leaves
- Customer frees itself after exiting
- No crashes with empty shelves
