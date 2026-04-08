# Issue 081: Implement clue delivery hooks in existing systems

**Wave**: wave-6
**Milestone**: M6 Long-tail + Secret Thread
**Labels**: `gameplay`, `secret-thread`, `phase:m4plus`, `priority:low`
**Dependencies**: issue-079, issue-080

## Why This Matters

Clues must feel like part of the world, not bolted on.

## Scope

Hook clue delivery into: event system (hidden event variants), customer spawner (suspicious customer type), inventory system (anomalous delivery item), time system (temporal triggers). Clues check thread_phase before spawning.

## Deliverables

- EventSystem checks for hidden clue events on day_started
- CustomerSystem can spawn 'suspicious' customer variant
- Inventory delivery can include anomalous item
- Clue spawning gated by thread_phase
- Each delivery increments awareness_score

## Acceptance Criteria

- Clues appear in-game at correct cadence
- Clues respect thread_phase (dormant = no clues)
- Delivery feels organic (not forced)
- Core systems not visibly modified
- Clue delivery works in all stores
