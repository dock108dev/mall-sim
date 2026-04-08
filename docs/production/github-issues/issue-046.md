# Issue 046: Implement store unlock system

**Wave**: wave-3
**Milestone**: M3 Progression + Content Expansion
**Labels**: `gameplay`, `progression`, `phase:m3`, `priority:high`
**Dependencies**: issue-018, issue-036

## Why This Matters

Store unlocks are the primary long-term progression hook.

## Scope

ProgressionSystem checks unlock conditions on day boundaries. Unlocks new store types when reputation + revenue thresholds are met. Store selection UI for choosing which store to manage.

## Deliverables

- ProgressionSystem checks unlock conditions
- Unlock notification shown to player
- Store selection UI (choose between unlocked stores)
- Store switching: unload current interior, load new one

## Acceptance Criteria

- Start with one store
- Meet threshold: unlock notification appears
- Can switch between unlocked stores
- Each store maintains its own inventory and reputation
