# Mall Sim / Game Store Beta Implementation Plan

## Goal
Deliver a playable one-store first-person beta (Thanksgiving to Christmas 2005 framing) with a complete Day 1 vertical slice first, then scale to a 30-day skeleton.

## Current Status Snapshot (2026-05-06)
- Phase 0 safety branch: COMPLETE
  - Branch: `beta/store-vertical-slice-recovery`
  - Baseline commit captured from `main`: `224e6e125a188e0822d4fbb5735787078119e2dd`
- Phase 1 audit docs: COMPLETE
  - `docs/BETA_CODEBASE_AUDIT.md`
  - `docs/QUARANTINED_SYSTEMS.md`
  - `docs/BETA_VALIDATION_LOG.md`
  - `docs/BETA_MANUAL_QA.md`
- Immediate stability fix: COMPLETE
  - Defensive GameManager resolution added in `game/autoload/data_loader.gd` to stop freed-instance assignment spam.
- Day 1 end-to-end beta route: IN PROGRESS

## Non-Negotiable Beta Shape
- Engine: Godot only.
- View: first-person, walkable, one real store.
- Scope: playable Day 1 first, then structured expansion.
- Interaction style: world interaction + decision cards for complex choices.

## Phase Board

## Phase 0 - Safety Baseline (Done)
- [x] Create safety branch.
- [x] Record starting commit hash.
- [x] Avoid destructive cleanup before audit.

## Phase 1 - Codebase Audit (Done)
- [x] Identify launch path, movement path, state ownership, day loop.
- [x] Identify preserve/quarantine targets.
- [x] Produce required audit docs.

## Phase 2 - Cleanup for Day 1 (Next)
- [ ] Establish a single beta gameplay route (menu -> beta root -> retro store).
- [ ] Ensure no non-beta overlay traps movement/input.
- [ ] Narrow active systems to Day 1-critical path.
- [ ] Confirm player spawns reliably in retro store.

## Phase 3 - Beta Store Scene Readability
- [ ] Keep `retro_games.tscn` as base and finalize required functional landmarks:
  - entrance, checkout/register, used shelves, trade-in area, backroom marker, signage slots, day-end trigger.
- [ ] Validate collision and navigation points.

## Phase 4 - Interaction Foundation
- [ ] Ensure all Day 1 interactables are explicit and non-fake.
- [ ] Add interactable registry/debug listing for active scene.
- [ ] Validate register/shelf/customer prompt behavior.

## Phase 5 - Run State / Day State
- [ ] Define single-source beta run state owner contract.
- [ ] Ensure day summary reads only from authoritative run state.
- [ ] Verify new-game reset consistency.

## Phase 6 - Day 1 Customer + Decision Slice
- [ ] Implement Day 1 parent wrong-console event with 3+ choices.
- [ ] Apply effects to money/reputation/manager trust/hidden-thread signal.
- [ ] Ensure movement resumes after card resolution.

## Phase 7 - Day Summary and Day 2 Placeholder
- [ ] Confirm day summary visibility and values.
- [ ] Confirm continue advances to Day 2 placeholder without crash.

## Phase 8 - 30-Day Skeleton
- [ ] Create day definitions for days 1-30.
- [ ] Ensure graceful handling of missing optional event content.

## Phase 9+ (Content/Hidden Thread/Endings/Customization/Polish)
- [ ] Expand archetypes, events, products, hidden-thread routes, endings.
- [ ] Implement framed ending rule for zero hidden interactions.
- [ ] Add lightweight store customization with persistence.

## Acceptance Gates
- Day 1 must pass before broad content expansion:
  - New game -> spawn in store -> move/look -> interact -> decision card -> state change -> day end -> summary -> Day 2 placeholder.
- If this fails, no progression to higher phases.

## Immediate Next Slice (Execution Order)
1. Build a constrained beta runtime path that launches directly into retro store Day 1 without nonessential overlays.
2. Wire one deterministic Day 1 customer decision event.
3. Validate end-to-end Day 1 via manual QA checklist and update `docs/BETA_VALIDATION_LOG.md`.
