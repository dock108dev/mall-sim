# Decision 0005: Sports Memorabilia — Authentication as a Real Mechanic

**Date:** 2026-04-23
**Status:** Accepted
**Related:** ISSUE-008 (this ADR), ISSUE-029 (follow-on), ADR 0003 and ADR 0004
(parallel patterns), roadmap.md Phase 0 exit criteria. Store roster:
superseded by ADR 0007 — the shipping roster is five stores, not six.

## Decision

**Commit (Option A)** to authentication as a real mechanic. The store keeps
three distinguishable states layered on every card — raw condition, letter-grade
authentication (provenance-score driven), and ACC numeric grading (day-delayed
RNG with condition-bounded ranges) — each of which feeds a different multiplier
slot through `PriceResolver`. Remaining work is verification, audit-checkpoint
coverage, and polish, filed as **ISSUE-029**.

Option (B) — reduce authentication to a flavor checkbox — is rejected because
the multi-state machine, the pending-grade lock, day-boundary delivery, cost
(auth fee + grading submission), risk (reject below threshold, variable numeric
grade), and partial information (player sees condition before submitting, not
final grade) are already implemented end-to-end. Downgrading to a flag would
delete working code and collapse the store's signature mechanic into
condition-priced inventory — a flavor of Sneaker Citadel.

## Context

ISSUE-008 framed sports memorabilia authentication as "currently a stub." A
walk of the current code shows that framing is stale:

| Surface | File | State |
|---|---|---|
| Controller | `game/scripts/stores/sports_memorabilia_controller.gd` (589 LOC) | `authenticate_card()` (L296), `send_for_grading()` (L402), `_deliver_pending_grades()` (L432), `_deliver_single_grade()` (L443), `_roll_numeric_grade()` (L478), `_compute_grade()` (L325), `_restore_pending_grade_locks()` (L489) all implemented. Every `return` is a guard clause; zero stubbed core verbs. |
| Authentication dialog | `game/scenes/ui/authentication_dialog.tscn` + `game/scenes/ui/authentication_dialog.gd` (159 LOC) | Live modal: reads fee from `AuthenticationSystem.get_auth_fee()`, shows item name + condition + cost, confirm → `authenticate(item.instance_id)`, success/failure routed through `EventBus.authentication_completed`. |
| State machine | `ItemInstance` fields: `authentication_status` ∈ {`unsubmitted`, `authenticated`, `rejected`}; `is_graded` / `card_grade` ∈ {`S`,`A`,`B`,`C`,`D`,`F`}; `is_grading_pending` (ACC lock); `numeric_grade` ∈ 1–10 (ACC). Three orthogonal progressions per card. |
| Risk | `AUTH_THRESHOLD = 0.5` (controller L11): cards with `provenance_score < 0.5` are rejected outright. ACC numeric grade is a seeded RNG (`hash(item_id + day)`) bounded by condition via `_CONDITION_GRADE_RANGES` (poor → 1–3, mint → 7–10). |
| Partial information | Player sees `condition` before submitting ACC grading, but the returned numeric grade is RNG-bounded — not deterministic from condition. Players trade the grading fee for a chance at a higher `NUMERIC_GRADE_MULTIPLIERS` slot. |
| Cost | Authentication fee surfaced via `AuthenticationSystem.get_auth_fee()` in the dialog (L110). ACC submission locks the card from sale until day N+1 (`_pending_grades` accounting + `_restore_pending_grade_locks` on save/load). |
| Pricing integration | Controller L80–134: `PriceResolver.resolve_for_item` receives a multipliers array where `numeric_grade` supersedes `card_grade` supersedes `condition`. Each state layer has its own label/detail in the audit chain. |
| Events | `EventBus.card_authenticated`, `card_rejected`, `card_graded`, `grade_submitted`, `grade_returned`, `grading_day_summary`, `provenance_requested`/`accepted`/`rejected`/`completed`, `card_condition_selected` all wired. |
| Save/load | `get_save_data()` / `load_save_data()` (L138–156) persist `_pending_grades` across save/load; legacy `"authentication"` key silently ignored for forward compatibility. |

Sports Memorabilia sits at 589 controller LOC — on the same order as Video
Rental (ADR 0003: 766) and Consumer Electronics (ADR 0004: 533). Like both, its
signature mechanic is implemented end-to-end and the remaining gate is audit
coverage, not mechanic authoring.

## State table

The card authentication state is the product of three orthogonal axes. A card
can advance independently on each.

### Axis 1 — Provenance authentication (letter grade)

```
Unsubmitted ──authenticate_card()── provenance_score >= 0.5 ──► Authenticated ──_compute_grade── S|A|B|C|D|F
             │
             └─ provenance_score < 0.5 ──► Rejected  (terminal; item unsaleable as authenticated)
```

Fields: `authentication_status`, `is_authenticated`, `card_grade`, `grade_value`,
`is_graded`.

### Axis 2 — ACC numeric grading (day-delayed)

```
Ungraded ──send_for_grading()──► Pending (locked from sale; _pending_grades[id] = current_day)
                                   │
                                   └─ day_started(current_day + 1) ──► Graded (numeric_grade ∈ 1..10)
```

Fields: `is_grading_pending`, `numeric_grade`. Roll is `rng.seed = hash(instance_id + day)`,
bounded by `_CONDITION_GRADE_RANGES[condition]`.

### Axis 3 — Condition (pre-existing; player-selectable via `_on_card_condition_selected`)

```
{poor | fair | good | near_mint | mint}
```

Applies `ItemInstance.CONDITION_MULTIPLIERS` when neither numeric nor letter
grade is set.

### Price resolution precedence

Within `get_item_price()`:

1. `numeric_grade >= 1` → `NUMERIC_GRADE_MULTIPLIERS[grade]` (supersedes all)
2. else `is_graded and card_grade not empty` → `GRADE_MULTIPLIERS[card_grade]`
3. else `CONDITION_MULTIPLIERS[condition]`

Plus additive modifiers: season demand (`BOOSTED_CATEGORIES` × `season_boost_value`
when `_season_boost_active`), vintage trend (`MarketTrendSystemSingleton.get_trend_modifier(&"vintage")`).

### Cost / risk parameters

| Parameter | Source | Value |
|---|---|---|
| Authentication fee | `AuthenticationSystem.get_auth_fee()` | configured by AuthenticationSystem |
| Authentication threshold | `sports_memorabilia_controller.gd:11` | `AUTH_THRESHOLD = 0.5` |
| Letter-grade cutoffs | `_compute_grade()` | `>=0.95 S · >=0.85 A · >=0.75 B · >=0.65 C · >=0.55 D · else F` |
| ACC condition ranges | `_CONDITION_GRADE_RANGES` | `mint [7,10]` · `near_mint [6,9]` · `good [4,7]` · `fair [2,5]` · `poor [1,3]` |
| ACC delivery delay | `_deliver_pending_grades` | `day_started(day > submission_day)` — i.e., next day open |
| ACC price slots | `PriceResolver.NUMERIC_GRADE_MULTIPLIERS` | per-grade multipliers in `PriceResolver` |

## Rationale

**Dev cost to commit is low.** All three axes run end-to-end in code today.
Remaining work is integration: named `AuditLog` checkpoints for
`card_authenticated` / `card_rejected` / `grade_submitted` / `grade_returned` /
`grading_day_summary`, GUT coverage for the accept/reject branch of
`authenticate_card` and the day-boundary delivery in `_deliver_pending_grades`,
`ObjectiveRail` wiring so "Authenticate <item>" / "Send <item> for ACC grading" /
"Pick up returned grades" surface as objectives when eligible inventory exists,
and interactable polish on the authentication desk / grading drop-off to meet
the ISSUE-003 visible-identity standard.

**Dev cost to cut to flavor is non-trivial and destroys work.** Option B would
require deleting or no-op-ing `authenticate_card`, `send_for_grading`,
`_deliver_pending_grades`, `_deliver_single_grade`, `_roll_numeric_grade`,
`_compute_grade`, `_restore_pending_grade_locks`, `AuthenticationDialog`
(159 LOC) and its `CheckoutSystem`/store wiring, the two pricing branches in
`get_item_price` that read `numeric_grade` and `card_grade`, `ItemInstance`
state fields (`authentication_status`, `is_graded`, `card_grade`, `grade_value`,
`is_grading_pending`, `numeric_grade`), `PriceResolver.NUMERIC_GRADE_MULTIPLIERS`
and `GRADE_MULTIPLIERS` tables, six `EventBus` signals, and the save/load
persistence for `_pending_grades`.

**Mechanic distinctiveness.** Sports is the only store where a single inventory
item can exist on three orthogonal quality axes simultaneously. Authentication
is the only provenance-driven binary gate (pass/fail below threshold) in the
product; ACC grading is the only multi-day, RNG-resolved inventory action
(parallel in structure to Video Rental's multi-day carry per ADR 0003, but
resolving into a grade tier rather than a return). Collapsing to flavor would
delete both — the store would reduce to condition-priced inventory, a flavor of
Sneaker Citadel.

**Non-negotiable alignment.** Per `docs/design.md` §"One complete loop before
five partial ones": sports memorabilia's authentication + grading loop is
closer to "one complete loop" than to "partial." All three axes run end-to-end
in code today. Committing honors that non-negotiable; cutting would discard a
loop near the finish line.

**Parallel with ADR 0003 and ADR 0004.** Both prior ADRs committed under the
same evidence pattern (large controller, real scene, populated catalog, zero
stubs on core verbs). The same pattern holds here. Cutting sports after
keeping Video Rental and Electronics would be inconsistent treatment of
equivalent code states.

## Consequences

- **ISSUE-029** is filed to close out verification and polish (audit
  checkpoints for authenticate / reject / submit / return / summary, GUT
  coverage for `authenticate_card` accept/reject and `_deliver_pending_grades`
  day-boundary delivery, `ObjectiveRail` wiring for the three surfaced
  objectives, authentication-desk and grading-drop-off interactable polish
  matching ISSUE-003, roadmap text update). It is scoped to *verify and
  integrate*, not re-implement.
- `docs/roadmap.md` §Phase 0 language about "authentication into a real
  mechanic … or accept it as a flavor checkbox" will be updated by ISSUE-029
  to reflect that the mechanic is wired and the remaining gate is
  audit-checkpoint coverage. The Phase 1 line "multi-state authentication with
  risk, cost, partial information, and outcome multiplier" already matches
  the implemented design and is retained as-is until ISSUE-029 verifies it.
- Per the ISSUE-008 acceptance criterion, the sports memorabilia controller
  must have zero stubbed `return false` / `return null` authentication methods
  after ISSUE-029 ships. Today's audit finds none; ISSUE-029 preserves that
  invariant and documents the existing early-return guards as guard clauses,
  not stubs.
- Store count for shipping remains six. `store_definitions.json` does not
  change.
- No trademarks: existing parody-name coverage in `validate.yml` already
  applies to the sports catalog; this ADR imposes no new content constraints.
  The in-game grading service name "Apex Card Certification (ACC)" is the
  established parody term and is preserved.
- If ISSUE-029 verification reveals a load-bearing gap (e.g., `AuthenticationSystem`
  persistence missing from `SaveManager`, or the pending-grade lock not
  surviving a mid-submission save/load round-trip beyond the existing
  `_restore_pending_grade_locks` coverage), this ADR should be revisited
  rather than silently expanded.
