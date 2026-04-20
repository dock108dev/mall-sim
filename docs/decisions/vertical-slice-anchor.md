# Decision: Retro Games as Vertical Slice Anchor

**Date:** 2026-04-20
**Status:** Accepted

## Decision
Retro Games is the anchor store for Phase 4 (vertical slice gate). All other store mechanics are deferred until ISSUE-006 is complete and passing the interaction audit.

## Rationale
- Refurbishment (Clean/Repair/Restore) is deterministic: three tiers, no async wait, no RNG pack resolution.
- Produces a complete stock→price→sell→summary loop exercising CheckoutSystem, PriceResolver (condition multiplier), and ReputationSystem without store-specific async state.
- Pocket Creatures (pack RNG + meta shifts) and Sports Cards (grade return on day N+1) introduce async state that complicates the first slice and defers the audit PASS.

## Criteria met
- Shortest path to a passing interaction audit (five checkpoints: boot, store_entered, refurb_completed, transaction_completed, day_closed)
- Exercises five PriceResolver multiplier paths (condition, reputation, trend, seasonal, variance)
- No dependency on other store drawers

## Consequences
- Pocket Creatures, Video Rental, Electronics, and Sports Cards mechanics depend on ISSUE-006 green.
- All Retro Games item names must be invented (no Nintendo, Sega, Atari, Sony IP).
