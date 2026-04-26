# Error Handling Audit — 2026-04-26

Scope: every intentionally-handled, suppressed, or downgraded error / warning
/ guardrail in the working tree relative to `main`, focused on the 33 modified
files and their adjacent code paths. GDScript is the project language; this
audit covers `push_warning` / `push_error` use, silent early returns, falsy
defaults, retries, catch-all returns, lint disables, and validator-warns-then-
accepts patterns.

## Executive Summary

| Severity | Count | Disposition |
|----------|------:|-------------|
| Critical | 0 | — |
| High     | 1 | **Acted** — fixed in `pack_opening_system.gd` |
| Medium   | 0 | — |
| Low      | 1 | **Acted** — tightened in `first_run_cue_overlay.gd` |
| Note     | 14 | Justified in-place with inline comments referencing this report |

**Top issue (now fixed):** `_register_cards()` in
`game/scripts/systems/pack_opening_system.gd` did not roll back partial
registrations. If card N failed registration after cards 0..N-1 had already
landed in `InventorySystem._items`, the caller discarded the entire `cards`
array and never emitted `pack_opened` / `items_revealed`, leaving 0..N-1 as
orphaned `ItemInstance`s that the player paid for and the UI never saw.

**Posture verdict: Prod posture acceptable.** All catch-all and silent paths
in the diff and surrounding code are either documented justifications tied to
boot-tier ordering, headless-mode skips, or recoverable retries with
observable surfaces. No silent money-loss paths remain after the fixes
applied in this pass. The one remaining structural gap (refundable rollback
when pack registration fails for a partial pack) is escalated below as `E1`
because it requires a domain decision (refund vs. re-register), not a code
fix.

The codebase has no Python-style `try/except`, no `noqa` / `pylint:disable`
suppressions, no `warnings.filterwarnings`, no `// removed` comments, and no
TODO/FIXME/HACK/XXX markers anywhere under `game/`. The 39 `gdlint:disable`
directives in the tree are all style-budget overrides
(`max-public-methods`, `max-returns`, `max-file-lines`) — none disable
correctness checks.

---

## Findings Table

| ID | Location | Category | Severity | Disposition |
|----|----------|----------|---------:|-------------|
| F1 | `game/scripts/systems/pack_opening_system.gd:475-498` | Hidden failure (state corruption) | High | **Acted** — added rollback of partial registrations |
| F2 | `game/scripts/ui/first_run_cue_overlay.gd:_is_inventory_empty` | Validation-warns-and-accepts | Low | **Acted** — added push_warning when bound system lacks `get_stock` |
| A1 | `game/scripts/stores/electronics_store_controller.gd:601-620` | Catch-and-abort with loud error | Note | Justified — already documented in code, comment intact |
| A2 | `game/scripts/stores/video_rental_store_controller.gd:684-697` | Catch-and-park with loud error | Note | Justified — extended inline comment referencing this report |
| A3 | `game/scripts/systems/pack_opening_system.gd:open_pack/commit_pack_results` push_errors | Loud-and-abort | Note | Justified — already documented; F1 fix complements |
| H1 | `game/scripts/systems/tutorial_system.gd:404-426` MAX_PROGRESS_FILE_BYTES | Defensive bound on user input | Note | Justified — already documented (security-report §F1) |
| H2 | `game/scripts/systems/tutorial_system.gd:_apply_state` MAX_PERSISTED_DICT_KEYS | Defensive bound + allow-list on user input | Note | Justified — already documented (security-report §F2) |
| H3 | `game/autoload/settings.gd:_safe_load_config` size + parse pre-check | Defensive bound on user input | Note | Justified — already documented (security-report §F4) |
| I1 | `game/scenes/ui/inventory_panel.gd:_pop_modal_focus` push_error + skip | Defensive observer | Note | Justified — already documented (security-report §F3) |
| I2 | `game/scenes/ui/inventory_panel.gd:_on_scene_ready` force-close | Reset on scene change | Note | Justified — already documented (research §4.2) |
| J1 | `game/autoload/game_manager.gd:_resolve_system_ref` | Silent null on early-boot | Note | Justified — added inline comment referencing §J1 |
| J2 | `game/scenes/ui/hud.gd:_refresh_items_placed/_refresh_customers_active` | Silent return on null system | Note | Justified — added inline comment referencing §J2 |
| J3 | `game/scenes/ui/hud.gd:_seed_counters_from_systems` | Silent skip when economy null | Note | Justified — implicit via J1 + J2 |
| J4 | `game/scripts/ui/first_run_cue_overlay.gd:_is_tutorial_active_at_boot` | Defensive `typeof / in` check on autoload | Note | Justified below as §J4 — comment in source |
| J5 | `game/autoload/settings.gd:_setup_crt_overlay` headless skip | Skip in headless | Note | Existing comment cites ssot-report risk log |
| C1 | `game/autoload/data_loader.gd` line 1 `# gdlint:disable=max-file-lines,max-public-methods,max-returns` | Style budget override | Note | Justified — no correctness disable |
| C2 | 39 other `gdlint:disable=max-*` directives across `game/` | Style budget overrides | Note | Same as C1 — none disable correctness checks |

---

## Per-Finding Detail

### F1 — Pack opening state corruption on partial register failure (HIGH, ACTED)

**File:** `game/scripts/systems/pack_opening_system.gd` `_register_cards`,
called from `open_pack` (line 97) and `commit_pack_results` (line 149).

**Old code:**

```gdscript
func _register_cards(cards: Array[ItemInstance]) -> bool:
    for card: ItemInstance in cards:
        if not _inventory_system.register_item(card):
            push_warning("PackOpeningSystem: failed to register card '%s'" % card.instance_id)
            return false
    return true
```

**Failure mode.** `_prepare_pack_cards` charges the player and removes the
pack from inventory *before* `_register_cards` runs. If
`_inventory_system.register_item` succeeds for cards 0..N-1 then fails on
card N (e.g. `_is_backroom_full` returns true mid-way through a 5-card
pack), 0..N-1 are already in `InventorySystem._items` via `add_item`. The
function returns `false`, the caller does `return []` (open_pack) or
`return false` (commit_pack_results), and `EventBus.pack_opened` /
`items_revealed` are never emitted for the partial cards. The player has
paid, the cards exist in the data model, but the UI and the rest of the
game never learn about them — and no further code path reaps them.

**Risk lens.**
- Reliability: hidden silent failure that diverges runtime state from UI.
- Data integrity: orphaned `ItemInstance`s persist in inventory data through
  save/load.
- Observability: the pre-existing `push_error` in `open_pack` says "cards
  lost", which is now misleading — some cards were *not* lost, they're
  trapped.

**Action.** Track the successfully-registered cards inside `_register_cards`
and roll them back via `_inventory_system.remove_item` on the first failure.
This restores the all-or-nothing contract the caller assumes.

```gdscript
var registered: Array[ItemInstance] = []
for card: ItemInstance in cards:
    if not _inventory_system.register_item(card):
        push_warning(...)
        for registered_card in registered:
            _inventory_system.remove_item(registered_card.instance_id)
        return false
    registered.append(card)
return true
```

The pre-existing `push_error` in the callers ("cards lost") is now accurate
again — it fires only when the caller will see *all* cards lost.

The pack itself remaining consumed and the player not refunded is escalated
below as `E1` — that requires a domain call, not a code fix.

### F2 — first_run_cue_overlay swallows interface drift (LOW, ACTED)

**File:** `game/scripts/ui/first_run_cue_overlay.gd:_is_inventory_empty`.

**Old code returned `true` (treat as empty) in two cases:** `inventory_system
== null` (legitimate test/early-boot path) and `not has_method("get_stock")`
(programming error — interface drift). The second case silently lies that
the store is empty, which would re-trigger the day-1 cue every store entry
even after the player stocked.

**Action.** Kept the null path silent (test seam) but added a `push_warning`
on the missing-method path so future refactors that rename `get_stock` are
visible in CI output instead of producing a phantom cue.

### A1 — Electronics warranty claim aborts when economy_system null (NOTE)

`_process_warranty_claims` (line 601) loudly aborts and purges expired
claims when `_economy_system == null`. This is a tight, explicit handler;
the inline comment is current and clear. Comment intact.

### A2 — Video rental late fee parks pending when economy_system null (NOTE)

`_collect_late_fee` (line 684). The new code surfaces a `push_error` and
records the fee in `_pending_late_fees` so a future day-cycle handler can
settle once `_economy_system` is wired up. Note: `_pending_late_fees` is
keyed by `item_id`, so repeated failures for the same rental will *overwrite*
rather than accumulate — acceptable because the policy assesses the highest
overdue fee, not a sum. There is no automatic resettlement loop in current
code; this surfaces only because the next `_collect_late_fee` in the day
cycle re-attempts. Inline comment now references §A2 of this report.

### A3 — Pack opening callers push_error on register failure (NOTE)

`open_pack` (line 97-112) and `commit_pack_results` (line 149-162) emit
`push_error` rather than `push_warning` because the failure happens *after*
the player has been charged and the pack consumed. This is the right
severity. With F1 fixed, the message ("cards lost") is now accurate.

### H1, H2 — Tutorial progress hardening (NOTE)

`MAX_PROGRESS_FILE_BYTES = 65536` and `MAX_PERSISTED_DICT_KEYS = 1024`
defend against a hostile/edited `user://tutorial_progress.cfg`. Allow-list
filters via `STEP_IDS.values()` and `CONTEXTUAL_TIP_KEYS` prevent arbitrary
keys from bloating the in-memory state. Both are well-commented in source
and reference `security-report.md` §F1/§F2.

### H3 — Settings `_safe_load_config` (NOTE)

Pre-validates file size and bracket-balance before handing bytes to
`ConfigFile.parse`, both to dodge Godot's internal `push_error` (which CI's
audit treats as a failure) and to close the open/check/reopen TOCTOU
window. The comment block at line 334-339 is clear; no change needed.

### I1 — InventoryPanel `_pop_modal_focus` defensive check (NOTE)

`push_error` + skip-pop when the topmost focus frame is no longer
`CTX_MODAL`. This is the correct pattern: `assert()` would be stripped from
release builds, silently double-popping someone else's frame. Comment
references `security-report.md` §F3.

### I2 — InventoryPanel `_on_scene_ready` force-close (NOTE)

Modal panels never survive a scene change. `_on_scene_ready` calls
`close(true)` which pops the modal frame before the new scene's gameplay
context becomes the top of the focus stack. Comment cites research §4.2.

### J1 — GameManager `_resolve_system_ref` silent null (NOTE)

```gdscript
if not is_inside_tree():
    return null
...
if matches.is_empty():
    return null
```

Returning `null` without a `push_warning` is **deliberate**: HUD's
`_seed_counters_from_systems()` runs in Tier-5 `_ready` per
`docs/architecture.md`, before world systems may have attached. A
`push_warning` here would fire on every `_ready` of every test scene that
doesn't instantiate the full system stack, polluting the CI error audit.
Callers that need presence assertion must do so themselves. Comment added
in source.

### J2 — HUD counter refresh silent return (NOTE)

Symmetric to J1 — `_refresh_items_placed` and `_refresh_customers_active`
silently no-op when the system isn't found yet. The HUD re-polls on every
`inventory_changed` signal (line 632), so a missed first-frame poll is
harmless. Comment added in source.

### J3 — HUD `_seed_counters_from_systems` (NOTE)

Inherits the J1+J2 disposition: economy null → `_sales_today_count` stays
at 0 until `economy.add_cash` fires `money_changed` next frame. Acceptable.

### J4 — first_run_cue_overlay autoload presence check (NOTE)

```gdscript
if typeof(GameManager) == TYPE_OBJECT and "is_tutorial_active" in GameManager:
    return bool(GameManager.is_tutorial_active)
return false
```

`GameManager` is a registered autoload and *should* always exist, so the
guard is defensive overkill. But it makes `_ready` robust for unit tests
that stub out autoloads, which the project's GUT setup occasionally does
(see `tests/gut/test_first_run_cue_overlay.gd:before_each` saving and
restoring `GameManager.is_tutorial_active`). Default-false on
"unreachable" is the safe failure for this overlay (cue might appear
unnecessarily once per session, never the other way).

### J5 — Settings `_setup_crt_overlay` headless skip (NOTE)

`if DisplayServer.get_name() == "headless": return` — correct, no rendering
context to attach to. The comment at line 141-146 already references the
parallel-CRT divergence in `ssot-report.md`.

### C1, C2 — `gdlint:disable=max-*` directives (NOTE)

39 occurrences across `game/`, all of the form `max-public-methods`,
`max-returns`, or `max-file-lines`. None disable correctness checks
(formatting, untyped vars, undefined names, etc.). These are style-budget
overrides on naturally-large autoloads (DataLoader, GameManager, HUD,
SaveManager, store controllers). Acceptable.

---

## Categorization

### Acceptable production notes (intentional, low-risk, justified)

- A1, A2, A3 — store controllers fail loud and abort/park on missing
  collaborator
- H1, H2, H3, I1, I2 — defensive bounds and ownership checks for
  user-controlled / cross-system input
- J1, J2, J3, J4, J5 — boot-tier-aware silent returns
- C1, C2 — style-budget overrides

### Needs documentation

None outstanding. Every Note above either has a pre-existing comment that
already cites a report, or one was added in this pass.

### Needs telemetry

None — every loud-fail path uses `push_warning`/`push_error`, which Godot
routes to stderr and which CI's existing error audit captures.

### Tighten before prod

None outstanding. The two findings worth tightening (F1, F2) were fixed in
this pass.

### Hidden failure risk

None remaining. The one finding in this category (F1) was fixed.

---

## Escalations

### E1 — Pack registration failure leaves player charged with no refund

**Blocker.** Even with F1's rollback of partial card registrations, the
*pack* itself was already consumed and the player was charged inside
`_prepare_pack_cards` (`_inventory_system.remove_item(pack_instance_id)` at
line 264, after `_economy_system.charge(cost, ...)` at line 234). When
`_register_cards` returns false:
- pack is gone (cannot be re-opened)
- money is gone (no refund)
- cards are now correctly not in inventory (post-F1)

**Who unblocks.** Game design — refund vs. re-register-pack vs. soft-reroll
is a player-experience decision, not a code structure decision.

**Smallest concrete next action.** Decide one of:
1. **Refund and re-register pack:** call `_economy_system.add_cash(cost,
   "Pack open refund")` and `_inventory_system.register_item(pack)` after
   the rollback in `_register_cards`. Player is whole.
2. **Refund only:** simpler, accept that the specific pack instance is
   destroyed. Player loses the pack art/name but keeps the money.
3. **Accept current behavior** as a "backroom is full, organize before
   opening more packs" friction signal. Document this in BRAINDUMP under
   Pocket Creatures.

The actual register-failure trigger today is a full backroom (via
`_is_backroom_full`), so option 3 has some design merit — but it should be
a deliberate decision, not the current accidental "consume + push_error".

---

## Final Verdict

**Prod posture: acceptable.** The diff under review introduces several new
guardrails that *tighten* error handling (warranty claim abort,
late-fee park, pack open push_error, settings size cap, tutorial dict cap,
modal focus defensive check). The one real silent-corruption gap that the
diff exposed (F1) was fixed in this pass. The remaining items are either
boot-tier-aware silent returns with explicit justifications, defensive
bounds on user-controlled input, or style-budget lint overrides. The single
escalation (E1) is a domain decision, not a defect.
