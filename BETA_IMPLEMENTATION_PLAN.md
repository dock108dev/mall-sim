# Mall Sim / Game Store Beta Implementation Plan

## Goal
Deliver a playable one-store first-person beta (Thanksgiving to Christmas 2005 framing) with a complete Day 1 vertical slice first, then scale to a 30-day skeleton.

## 15-Minute Beta Definition (Scope Lock)
This project is "beta-complete" when one player can start a run and play for 15 minutes without confusion, dead prompts, or required dev knowledge.

Required loop for this beta (only):
- Start new game -> spawn in retro store -> clear first objective.
- Resolve 2-3 customer decision cards (not just one).
- Complete one restock/action objective between customer events.
- End day -> read summary -> continue to next day.
- Repeat once (reach Day 2), then return to menu safely.

Explicitly out of scope until this passes:
- Extra store props/zones not used by the loop.
- Additional systems (build mode, broad inventory variants, deep hidden-thread branches).
- Large visual polish passes outside gameplay readability.

## Finish Order (Indie Priority Stack)
Do not work out of order.

1. Playability and clarity (must finish first)
- One objective at a time on screen.
- Only interactables needed for objective are enabled.
- Remove all dead/no-op prompts.

2. Core progression reliability
- Deterministic Day 1 and Day 2 event flow.
- Day summary always reflects run state.
- New run always resets state correctly.

3. Content minimum for 15 minutes
- 3 customer archetypes total.
- 8-12 decision cards total (distributed over Days 1-2 for now).
- 3-5 repeatable store actions (restock, inspect, checkout, hold-shelf, close-day).

4. Visual readability pass (targeted)
- Keep store sparse but coherent.
- Replace only the most distracting placeholder blocks in player path.
- Ensure customer bodies are visible and readable at a distance.

## Production Rhythm (Solo-Dev Safe)
- Weekly cadence:
  - Mon-Tue: implement one thin feature slice.
  - Wed: integration + bug fixing only.
  - Thu: manual playtest and trim scope.
  - Fri: stabilize and tag a playable build.
- Daily rule: 70% reliability work, 20% content, 10% visual polish.
- Scope discipline: no new system starts until current acceptance gate passes.

## Next 10 Working Sessions
1. Lock objective-driven interactable gating for Day 1.
2. Add 2 more customer events (total 3 on Day 1).
3. Add Day 2 event file with 3-4 lightweight cards.
4. Wire objective manager text to active event step.
5. Add one restock objective between customer cards.
6. Validate day-end and summary values against run state.
7. Add fail-safe: if event data missing, skip safely and continue loop.
8. Playtest for 15 minutes, log confusion points.
9. Remove/disable remaining noisy scene nodes in player path.
10. Run full manual QA pass and publish first beta candidate.

## Completion Gate for Beta Candidate v0.1
All must be true:
- 15-minute run is possible with no dead ends.
- At least 5 meaningful decisions made during run.
- Day 1 -> Day 2 transition works every run.
- No blocking errors in headless boot and no interaction soft-locks in manual QA.
- Player feedback can be gathered without explaining controls/objective flow verbally.

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
