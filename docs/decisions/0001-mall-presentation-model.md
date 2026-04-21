# Decision 0001: Management Hub (Click-to-Enter) as the 1.0 Presentation Model

**Date:** 2026-04-21
**Status:** Accepted
**Supersedes:** None

## Decision

Mallcore Sim 1.0 ships as a **management hub**: a stylized, clickable mall map
where each storefront is a discrete hotspot that transitions to a dedicated
in-store management scene via Godot's scene-swap pattern. There is no walkable
player controller, no avatar embodiment, and no continuous traversal of mall
space. Any ambient foot-traffic rendered on the hub is read-only atmosphere,
never an interaction surface.

The **walkable mall** alternative — embodied player controller, physical
traversal between stores, interact volumes on storefront doors — is explicitly
rejected for 1.0.

## Context

The game's north star (`CLAUDE.md` §8.1) is: *"If a screen doesn't answer 'what
can I do right now?' in under 3 seconds, the screen is wrong."* The Phase 0
interaction audit (`tools/interaction_audit.md`, ISSUE-001 through ISSUE-003)
showed that the partially implemented walkable layer was the dominant source of
FAIL rows: input focus conflicts, invisible interact prompts, camera state
mismatches, and a spawn screen that did not communicate any decision.

Phase 1 therefore requires committing to **one** presentation model so the rest
of the roadmap (visual grammar, objective rail, vertical slice) can stop
supporting both simultaneously.

## Alternatives Considered

### A. Management hub, click-to-enter (**chosen**)

Top-down/isometric mall map. Stores are clickable cards or hotspots. Entering
a store is a scene swap to that store's management scene. Autoloads hold game
state across the transition. Ambient shoppers on the hub are decorative only.

- **Pros:** First click lands on a mechanic. Per-store state (revenue,
  reputation, alerts) can be surfaced directly on the hub card, turning the hub
  into a strategic dashboard. Pattern is well-established in Godot 4 via
  `change_scene_to_packed` + autoload state (see research).
- **Cons:** Store identity must carry through art direction alone (palette,
  fixture style, music) since the player never physically walks in. Atmosphere
  is narrower than a walkable space.

### B. Walkable mall (**rejected**)

Embodied player controller navigates a mall interior. Storefront doors are
interact volumes; entering a store is either a scene swap or a sub-scene load
triggered by proximity.

- **Pros:** Strong sense of place, organic pacing between stores, room for
  environmental storytelling.
- **Cons:** Forces us to own a full movement/collision/camera stack and an
  interact-prompt system before the first sale can happen. Every UI panel has to
  coexist with gameplay input, which is exactly the failure mode surfaced by
  the audit (`docs/research/godot-focus-input-conflicts.md`). Onboarding cost is
  higher — the player must learn to move before learning to run a store.
- **Why rejected:** The scope the walkable model demands (pathfinding, interact
  volumes, focus arbitration, collision tuning) would consume the Phase 2–4
  budget without producing a single additional mechanical decision. The audit
  evidence is unambiguous: the walkable prototype is the *cause* of most
  current FAIL rows, not a neutral presentation choice.

### C. Hybrid — walkable mall with hub fallback (**rejected**)

Ship both, let the player choose. Considered briefly because the walkable
scaffolding already exists in the repo.

- **Cons:** Doubles every UI audit. Forces every feature (objective rail,
  interact prompts, tutorial state) to work in two input contexts. The SimCity
  2013 postmortem (`docs/research/management-vs-walkable-case-studies.md`) is
  the cautionary case: a walkable surface that doesn't faithfully represent
  underlying state *actively harms* legibility rather than being neutral.
- **Why rejected:** Doubles cost, halves polish, and keeps the very FAIL-row
  generator the audit identified. Parkitect's "read-only tourist camera" model
  shows that if a walkable view ever returns, it must be cosmetic and optional,
  not a parallel interaction surface.

## Rationale

Supporting research:

- `docs/research/management-vs-walkable-case-studies.md` — post-launch case
  studies (Mall Tycoon 2, Two Point Hospital, Game Dev Tycoon, Parkitect,
  SimCity 2013, Stardew Valley, Supermarket Simulator) consistently show that
  hub models produce higher launch legibility for *mechanics-heavy* sims, while
  walkable models pay off only when world motion carries diagnostic information
  across ~30+ simultaneous entity types. Mallcore has five stores and a handful
  of shoppers — the signal-to-cost ratio does not justify walkable.
- `docs/research/godot4-click-to-enter-management-hub.md` — documents the
  canonical Godot 4 scene-swap pattern (`change_scene_to_packed`,
  autoload-held state, `Area2D`/`TextureButton` hotspots) that aligns with the
  existing autoload topology (`EventBus`, `GameManager`, `ContentRegistry`,
  `StoreStateManager`) and the current `GameWorld` → store-scene wiring.
- `docs/research/management-hub-ui-patterns.md` and
  `docs/research/management-vs-walkable-case-studies.md` together argue that
  per-store health surfaced on hub cards is the dominant legibility win — a
  lever only the hub model can pull cheaply.

The hub model also aligns with the two active constraints in `CLAUDE.md`:
rule 1 (legibility before depth) and rule 3 (management hub, not walkable
world — player-controller movement belongs only in explicitly feature-flagged
walkable scenes).

## Consequences

- The storefront "fake 3D" approach scene is removed from the player flow
  (Phase 1 follow-up issue).
- The walkable mall scene is gated behind a `debug.walkable_mall` flag and
  defaulted off. Its scripts stay in-repo as a debug-only reference; they do not
  ship in the 1.0 build path.
- New Game lands the player directly on the management hub — no spawn,
  no traversal, no entrance prompt.
- Store entry is a single click on a hub card, transitioning to the store scene
  via the existing `GameManager` + `StoreStateManager` wiring.
- Exiting a store returns to the hub, not to a mall interior.
- All future UI work (objective rail, interaction prompts, store-accent
  theming) targets the hub + store-scene surfaces only. Contributors should not
  add features that assume a walkable context.
- Ambient shopper sprites on the hub, if added, are cosmetic-only and must not
  expose click/interact handlers.

## Rollback Path

This decision is reversible but costly. Rollback would be triggered only by
evidence that the hub model fails a specific legibility or retention goal that
a walkable view would demonstrably fix.

1. **Trigger:** a Phase 4+ playtest shows that ≥50% of new players cannot
   identify per-store health from the hub within 3 seconds, *and* a prototype
   walkable strip demonstrably closes that gap (not merely looks nicer).
2. **Action:** open ADR-000X superseding this decision. Do not mutate this
   document — add a new ADR that marks this one `Superseded`.
3. **Code path:** the walkable scaffolding remains in git history and behind
   `debug.walkable_mall`. Re-enabling it requires wiring player-controller
   movement, interact volumes, and focus arbitration — all treated as new work,
   not a silent flag flip.
4. **Art/UX:** store scene internals do not change on rollback; only the
   mall-level navigation layer does. This is by design so a rollback does not
   invalidate the vertical slice (see ADR-0002).
