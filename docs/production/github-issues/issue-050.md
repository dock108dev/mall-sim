# Issue 050: Implement trend system with hot/cold item categories

**Wave**: wave-3
**Milestone**: M3 Progression + Content Expansion
**Labels**: `gameplay`, `balance`, `phase:m3`, `priority:medium`
**Dependencies**: issue-024, issue-034

## Why This Matters

Trends create the buy-low-sell-high timing game.

## Scope

Trend system shifts item category demand over time. Hot categories see increased customer interest and willingness-to-pay. Cold categories see decreased demand. Trends rotate on multi-day cycles.

## Deliverables

- TrendSystem tracks hot/cold categories
- Trend shifts on day boundaries
- Hot: demand modifier increases
- Cold: demand modifier decreases
- UI indicator showing current trends
- Trends affect all stores with matching categories

## Acceptance Criteria

- Trends visibly shift demand
- Hot items sell faster at higher prices
- Cold items sit longer
- Trend rotation is visible to player
- Cross-store trends work correctly
