# Issue 072: Implement refurbishment mechanic for retro game store

**Wave**: wave-5
**Milestone**: M5 Store Expansion
**Labels**: `gameplay`, `store:video-games`, `phase:m4plus`, `priority:medium`
**Dependencies**: issue-041, issue-045

## Why This Matters

Refurbishment is the retro store's unique value-creation mechanic.

## Scope

Broken/damaged consoles and scratched games can be refurbished. Takes time, costs materials, has failure chance. Successful refurb improves condition (and value). Failure destroys item.

## Deliverables

- Refurbishment interaction on eligible items
- Time delay (1-2 game days)
- Cost (materials/money)
- Success rate based on item type
- Success: condition improves
- Failure: item destroyed

## Acceptance Criteria

- Can initiate refurbishment on damaged items
- Takes time (not instant)
- Success improves condition and value
- Failure removes item
- Risk/reward feels balanced
