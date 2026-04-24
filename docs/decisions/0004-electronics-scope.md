# Decision 0004: Consumer Electronics — Commit to Warranty + Demo-Unit + Lifecycle

**Date:** 2026-04-23
**Status:** Accepted
**Related:** ISSUE-007 (this ADR), ISSUE-028 (follow-on), ADR 0003 (parallel pattern), roadmap.md Phase 0 exit criteria. Store roster: superseded by ADR 0007 — the shipping roster is five stores, not six.

## Decision

**Commit (Option A)** to keeping Consumer Electronics with warranty, demo-unit
designation, and product lifecycle as its three distinguishing mechanics. All
three are substantively wired today; no core verb is stubbed. Remaining work
is verification, audit-checkpoint coverage, and polish — filed as
**ISSUE-028**.

Option (B) — strip warranty + demo-unit and reshape the store around product
lifecycle alone — is rejected because it would delete working code whose
wiring is already complete, in exchange for a narrower mechanic set that
makes the store less distinct from Retro Games and Sneaker Citadel (both of
which already carry a condition/rarity-driven pricing loop).

## Context

ISSUE-007 framed the electronics store as having "stubbed warranty dialog and
demo-unit designation." A walk of the current code shows that framing is
stale:

| Surface | File | State |
|---|---|---|
| Controller | `game/scripts/stores/electronics_store_controller.gd` (533 LOC) | `attempt_purchase()`, `present_warranty_offer()`, `can_demo_item()`, `place_demo_item()`, `remove_demo_item()`, `_process_demo_degradation()` all implemented. Every `return false` is a guard clause (failed precondition), not a stub. Zero `return null` stubs on core verbs. |
| Warranty dialog | `game/scenes/ui/warranty_dialog.tscn` + `game/scripts/ui/warranty_dialog.gd` (202 LOC) | Live. Tier buttons rendered from `ItemDefinition.warranty_tiers`; falls back to single-button when no tiers. |
| Checkout wiring | `game/autoload/checkout_system.gd` | `set_warranty_dialog()` (L117–124) connects `warranty_accepted` / `warranty_declined`. `_should_show_warranty()` (L312–316) checks eligibility; `_show_warranty_dialog()` (L533–549) opens with tiers; `_on_warranty_accepted()` (L553–574) calls `WarrantyManager.add_warranty()`. |
| Demo-unit system | `ItemInstance.is_demo` + `ItemInstance.demo_placed_day` + `ElectronicsStoreController._demo_item_ids` tracking array | Eligibility (8 guards), placement, degradation every 10 days, removal. Not a stub — a full mini-system. |
| Lifecycle engine | `game/scripts/stores/electronics_lifecycle_manager.gd` (309 LOC) | Four phases (PEAK / DECLINE / CLEARANCE / OBSOLETE) with per-day price multipliers, generation tracking via `product_line` / `generation`, pending launch queue, availability gating. Operational. |
| Scene | `game/scenes/stores/consumer_electronics.tscn` (~214 nodes, 1,216 lines) | Real fixtures: shelves, glass gadget case, accessory pegboard, 2× demo stations, counter, NavMesh, lighting. Not a brown-void scene (contrast ISSUE-005). |
| Config | `game/content/stores/store_definitions.json` (L238–293) | `unique_mechanics: ["demo_units", "product_lifecycle", "warranty_upsell"]`, `max_demo_units: 2`, `demo_interest_bonus: 0.20`, 8 fixture types / 48 shelf slots / 120 backroom. |
| Items | `game/content/items/consumer_electronics.json` + `items_electronics.json` (34 items) | Every item carries `warranty_tiers` array and `can_be_demo_unit` flag. `product_line` / `generation` fields populated for lifecycle. |

Electronics sits at 533 controller LOC / 1,216 scene lines — on the same
order as Video Rental (ADR 0003: 766 / 1,292). Like Video Rental, its core
loop is implemented and the remaining gate is audit coverage, not mechanic
authoring.

## Rationale

**Dev cost to commit is low.** The three mechanics are wired end-to-end.
Remaining work is integration: named `AuditLog` checkpoints for
`warranty_offered` / `warranty_purchased` / `demo_placed` / `demo_degraded` /
`lifecycle_phase_changed`, GUT coverage for the warranty accept/decline
branch and lifecycle phase transitions, an `ObjectiveRail` wiring so demo
slots and phase-clearance items surface as objectives, and interactable
polish on the demo stations to meet the ISSUE-003 visible-identity standard.

**Dev cost to cut warranty + demo-unit is non-trivial and destroys work.**
Option B would require deleting the warranty dialog scene + script (278 LOC),
the `set_warranty_dialog` / `_on_warranty_accepted` wiring in
`CheckoutSystem`, the `WarrantyManager` usage, the `_demo_item_ids`
accounting and `_process_demo_degradation` loop in the controller, the
`warranty_tiers` and `can_be_demo_unit` fields across 34 catalog items, the
two demo-station fixtures from the scene, and the `demo_units` /
`warranty_upsell` entries from `unique_mechanics`. It also weakens store
differentiation: without warranty and demo, electronics becomes
"lifecycle-priced inventory" — a flavor of Sneaker Citadel's condition
multiplier.

**Mechanic distinctiveness.** Warranty is the only post-sale revenue tail in
the product; every other store closes its margin at checkout. Demo units are
the only voluntary inventory degradation (trading condition for customer
interest) — the rest of the game treats degradation as passive. Lifecycle is
the only time-of-launch-relative pricing axis; other stores use
condition/rarity/trend. Cutting warranty + demo would collapse three
distinct axes into one.

**Non-negotiable alignment.** Per `docs/design.md` §"One complete loop
before five partial ones": Consumer Electronics is closer to "one complete
loop" than to "partial." All three of its mechanics run end-to-end in code
today. Committing honors that non-negotiable; cutting would discard a loop
that is already near the finish line.

**Parallel with ADR 0003.** ADR 0003 committed Video Rental under the same
evidence pattern (large controller, real scene, populated catalog, zero
stubs on core verbs). The same pattern holds here. Cutting electronics
after keeping video rental would be inconsistent treatment of equivalent
code states.

## Consequences

- **ISSUE-028** is filed to close out verification and polish (audit
  checkpoints for warranty / demo / lifecycle, GUT coverage, `ObjectiveRail`
  wiring, demo-station interactable polish matching ISSUE-003, roadmap text
  update). It is scoped to *verify and integrate*, not re-implement.
- `docs/roadmap.md` §Phase 0 text about "warranty+demo-unit or lifecycle-only"
  will be updated by ISSUE-028 to reflect that all three mechanics are
  wired and the remaining gate is audit-checkpoint coverage.
- Store count for shipping remains six. `store_definitions.json` and the
  `unique_mechanics` list do not change.
- Per the ISSUE-007 acceptance criterion, the electronics store controller
  must have zero `return false` / `return null` stubbed methods after
  ISSUE-028 ships. Today's audit finds none; ISSUE-028 preserves that
  invariant and documents the existing `return false` lines as guard
  clauses, not stubs.
- No trademarks: existing parody-name coverage in `validate.yml` already
  applies to the electronics catalog; this ADR imposes no new content
  constraints.
- If ISSUE-028 verification reveals a load-bearing gap (e.g., `WarrantyManager`
  persistence missing from `SaveManager`, or lifecycle phase rollover not
  surviving save/load), this ADR should be revisited rather than silently
  expanded.
