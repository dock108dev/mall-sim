# Issue 018: Implement ReputationSystem with score tracking and tier calculation

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `tech`, `phase:m1`, `priority:medium`
**Dependencies**: issue-010, issue-012

## Why This Matters

Reputation drives customer flow and progression unlocks.

## Scope

ReputationSystem tracks per-store reputation (0-100). Modifies on sales (fair pricing = positive, gouging = negative). Calculates tier (Unknown/Local Favorite/Destination Shop/Legendary). Emits reputation_changed signal.

## Deliverables

- ReputationSystem with get_reputation(store_id), modify_reputation(store_id, delta)
- Tier calculation based on thresholds from pricing_config
- Reputation modifiers from sales: compare sale price to market value
- EventBus.reputation_changed signal
- Reputation decay if store understocked (checked at day end)

## Acceptance Criteria

- Fair-priced sale: reputation increases
- Overpriced sale: reputation decreases or no change
- Tier changes at correct thresholds
- Signal fires on change
