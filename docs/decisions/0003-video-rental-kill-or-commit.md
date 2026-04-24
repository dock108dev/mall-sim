# Decision 0003: Video Rental — Commit to Rent/Return/Overdue Loop

**Date:** 2026-04-23
**Status:** Accepted
**Related:** ISSUE-006 (this ADR), roadmap.md Phase 0 exit criteria. Store
roster: superseded by ADR 0007 — the shipping roster is five stores, not six
(Sneaker Citadel removed).

## Decision

**Commit** to keeping the Video Rental store and finishing the
rent → return → overdue → late-fee loop as a first-class mechanic. The store
stays in the roster; the product continues to ship with five stores
(Retro Games, Sneaker Citadel, Sports Memorabilia, Pocket Creatures,
Consumer Electronics, Video Rental — six total with Video Rental).

Follow-on implementation / verification work is filed as **ISSUE-027**.

## Context

`docs/roadmap.md` §Phase 0 lists:

> "video rental: finish `rent_item()` / return / overdue / late-fee flow, or
> cut the store to four stores"

The roadmap language assumes the rental loop is largely stubbed. A walk of
the current code shows that framing is stale:

| Surface | File | State |
|---|---|---|
| Controller | `game/scripts/stores/video_rental_store_controller.gd` (766 lines) | `process_rental()` (L107), `_handle_return()` (L395), `get_overdue_rentals()` (L156), `_collect_late_fee()` (L475), `_apply_degradation()` (L436) all implemented. Every `return false` is a guard clause, not a stub. |
| Scene | `game/scenes/stores/video_rental.tscn` (1,292 lines, ~260 nodes) | Real fixtures: halogen + neon lighting rig, counter, returns bin with interactable, genre shelves, CRT, navmesh. Not a brown-void scene (contrast ISSUE-005). |
| Config | `game/content/stores/video_rental_config.json` | Rental period, grace period, late-fee curve, wear-per-rental, per-category fees all set with real numbers. |
| Items | `game/content/items/video_rental.json` | 30 items across VHS classic, new-release, cult, DVDs, with `rental_fee` / `late_fee_per_day` / `lifecycle_phase` fields populated. |
| Registration | `game/content/stores/store_definitions.json` | id `rentals`, aliases `["video_rental"]`, wired into customer archetypes (4 profiles) and seasonal pricing. |

Video Rental is in fact the **largest** store controller in the codebase
(766 LOC vs. Sports 589, Electronics 532, Pocket Creatures 326). It has zero
`return null` stubs on core verbs.

## Rationale

**Dev cost to commit is low.** The rental loop is already substantively
wired. The remaining work is verification + integration — audit checkpoints,
objective-rail wiring, a returns-bin interactable matching ISSUE-003 visual
standards, GUT coverage for overdue/late-fee math, and confirmation that the
loop exits through the same `transaction_completed` / `day_closed` audit
checkpoints as every other store.

**Dev cost to cut is non-trivial and destroys work.** Cutting would require
deleting the controller (766 LOC), the scene (1,292 lines of hand-placed
fixtures), a 30-item catalog, a config file, and auditing every reference in
`store_definitions.json`, customer archetypes, seasonal pricing, and tests —
then shipping with only five stores. The Phase 0 motivation for "or cut"
(stubbed code rot) does not apply.

**Mechanic distinctiveness.** Rental is the only multi-day, state-carrying
transaction in the product: the same item leaves the store, accrues wear,
may come back late or lost, and can be re-rented. Every other store closes
its loop within a single day. Even though
`docs/research/retail-sim-reference-games.md` does not call out rental by
name, the multi-day carry is exactly the kind of loop the reference games
use to make day-over-day progression feel meaningful. Cutting it reduces
mechanic variety without removing dev cost.

**Non-negotiable alignment.** Per `docs/design.md` §"One complete loop
before five partial ones": Video Rental is closer to "one complete loop"
than to "partial." Committing honors that non-negotiable; cutting would
waste a loop that is already near the finish line.

## Consequences

- **ISSUE-027** is filed to close out verification/polish (audit
  checkpoints, returns-bin interactable polish, overdue/late-fee GUT
  coverage, objective-rail wiring, roadmap text update). It is scoped to
  *verify and integrate*, not re-implement.
- `docs/roadmap.md` §Phase 0 language will be updated by ISSUE-027 to
  reflect that the rental flow is implemented and the remaining gate is
  audit-checkpoint coverage, not core code.
- Store count for shipping remains six. `store_definitions.json` and
  customer archetypes do not change.
- No trademarks: the existing banned-terms regex in `validate.yml` already
  covers the item catalog; this ADR imposes no new content constraints.
- If ISSUE-027 verification reveals a load-bearing gap that would require
  substantial new mechanic work (e.g., a multi-day calendar system that
  does not yet exist), this ADR should be revisited rather than
  silently expanded.
