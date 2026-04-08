# Issue 021: Implement multiple customer profiles with distinct behaviors

**Wave**: wave-2
**Milestone**: M2 Core Loop Depth
**Labels**: `gameplay`, `phase:m2`, `priority:high`
**Dependencies**: issue-011, issue-020

## Why This Matters

Customer variety creates the strategic depth that makes pricing decisions meaningful.

## Scope

CustomerSystem spawns from the defined customer type pool. Different types browse different categories, have different budgets and patience. Spawn rates vary by time of day.

## Deliverables

- CustomerSystem reads customer types from DataLoader
- Spawns appropriate types based on store_type and time of day
- Each customer uses its type's budget, patience, preferences
- Max simultaneous customers capped (8-10)

## Acceptance Criteria

- Multiple customer types visibly appear
- Collectors browse high-value items, kids browse cheap items
- Morning has fewer customers than midday
- Cap is enforced
