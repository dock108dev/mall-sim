# Roadmap

Mallcore Sim is in a finalization phase. The goal is to close the gap between
scaffolded systems and player-visible functionality before adding new features.

The customer-voice state assessment that informs this roadmap is
`BRAINDUMP.md` at the repository root.

## Current state

The core transaction loop (stock → price → sell → haggle → day close →
summary) is implemented end-to-end. Two stores have real signature mechanics:
retro games refurbishment and Pocket Creatures pack opening, meta shifts, and
tournaments. Three stores (video rental, electronics, sports memorabilia) have
scaffolded mechanics that are not yet player-facing.

The meta-narrative layer (secret threads, ambient moments, completion tracker)
is wired to the signal bus but has no player-facing UI surface.

## Phase 0 — Triage

**Goal:** Kill-or-commit decisions on every stubbed system.

- video rental: finish `rent_item()` / return / overdue / late-fee flow, or cut
  the store to four stores
- electronics: finish warranty dialog and demo-unit designation, or remove
  warranty from checkout and reshape electronics around lifecycle alone
- sports memorabilia: turn authentication into a real mechanic with grading
  states, cost, and partial information, or accept it as a flavor checkbox
- delete remaining legacy content path duplicates

Exit criteria: zero stubbed `return false` or `return null` store methods in
the active store controllers.

### Phase 0.1 — UI integrity and SSOT cleanup

> **Complete.** Three SSOT tripwire scripts —
> `scripts/validate_translations.sh`, `scripts/validate_single_store_ui.sh`,
> and `scripts/validate_tutorial_single_source.sh` — are checked in and
> invoked by `tests/run_tests.sh`. The shipping store roster is fixed at
> five (`sports`, `retro_games`, `rentals`, `pocket_creatures`,
> `electronics`) per `game/content/stores/store_definitions.json`.

**Goal achieved:** Every duplicated UI system collapsed down to one source
of truth before any new feature work. The SSOT outcomes for this batch are
recorded in [`docs/audits/ssot-report.md`](audits/ssot-report.md).

Exit criteria met: CI green, no raw translation keys on screen, exactly
five store cards in the mall overview, each store entry shows the 3D
interior with a camera framed on the storefront.

## Phase 1 — Store Completion

**Goal:** Every remaining store has a fully functional signature mechanic.

- video rental: tape wear tracking, rental duration, overdue processing,
  late-fee checkout
- electronics: warranty dialog wired into checkout, demo-unit designation in
  the electronics controller
- sports memorabilia: multi-state authentication with risk, cost, partial
  information, and outcome multiplier

## Phase 2 — Architecture Hardening

**Goal:** Close structural debt that compounds during later work.

- consolidate all price multipliers through a single `PriceResolver` with an
  audit trace exposed in the HUD
- enforce `type` field in content JSON; remove heuristic type-detection
  fallbacks
- delete duplicate store controller classes (one controller per store)
- collapse milestone UI to a single component (popup, banner, or panel, not all
  three)
- lock canonical content paths and delete any remaining root-level JSON
  duplicates

## Phase 3 — Mall Overview and Events

**Goal:** Treat the mall as the unit of play, not five separate stores.

- first-class mall overview scene with per-store KPI cards (reputation tier,
  day revenue, inventory health, active events)
- live event telegraph feed with severity color grammar and a short forecasting
  window for upcoming market, seasonal, and meta events

## Phase 4 — Narrative Surface

**Goal:** Make the meta-narrative layer player-facing or remove it.

- if secret threads are kept: add a stories/regulars tab showing thread state
  and phase progression
- if ambient moments are kept: add a moments log with recall, not just
  transient notifications
- if either is removed: clean out system code, signals, and content files

Exit criteria: either a player can see thread and moment state, or the systems
are deleted.

## Phase 5 — UI Texture

**Goal:** Push 2000s mall identity into the visual chrome.

- period typography and jewel-tone color palette applied to HUD and panels
- outline highlight shader for interactable objects (shipped)
- CRT warmth or scanline shader on appropriate UI surfaces
- mall-map style for the mall overview
- unified `ActionDrawer` pattern for all in-store actions (haggle, refurbish,
  authenticate, warranty)

## Phase 6 — Content Volume

**Goal:** Ship enough content that the game feels specific, not thin.

- 20+ ambient moments if the system is kept from Phase 4
- 4+ secret threads with real payoffs if the system is kept from Phase 4
- 4 full seasons with distinct event profiles
- minimum item counts per store sufficient for real browsing variety
- parameterized GUT tests over every content file

## Phase 7 — Endings and Verification

**Goal:** Golden-path test coverage and unverified-issue burn-down.

- deterministic test per ending condition (13 endings)
- AIDLC-tracked issues verified against actual behavior
- 0 CI failures on main

## Phase 8 — 1.0 Ship Criteria

**Goal:** Final checklist against every phase's exit criteria.

- no stubbed `return false` in store controllers
- no duplicate controllers, no duplicate content paths
- all five stores have a real, legible signature mechanic
- mall overview exists and shows per-store health
- either narrative layer is surfaced or cleanly removed
- price model is fully traceable via `PriceResolver` audit output
- 2000s visual identity is visible in the chrome
- CI passes, exports build, save/load round-trips on current save version

---

## Cross-cutting rules

These apply at every phase, not just the one you are currently working on.

- **No real brands, trademarks, copyrighted characters, or real people.** All
  store names, console names, game titles, team names, athlete names, box art,
  logos, and flavor text must be original. Boot-time content validator is the
  enforcement mechanism.
- **Every new screen must pass the 3-second test** before merge: primary focus,
  current mode, next action visible in under 3 seconds.
- **Every interactable must have hover feedback and an input hint.** No silent
  click targets.
- **Never re-enable the walkable mall** unless it clears the same playability
  audit from Phase 0 in a dedicated proposal.
- **One PR = one phase objective.** Do not bundle a Phase 1 store mechanic with
  a Phase 3 event system.
