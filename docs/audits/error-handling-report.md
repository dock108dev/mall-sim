# Error Handling Report

**Pass date:** 2026-05-01
**Scope:** every `push_warning` / `push_error`, silent early return, default
fallback, defensive duck-typing, and `assert()` tripwire reachable from the
gameplay surface, with an emphasis on the changed files on the working branch
(shelf placement hint UI, orthographic camera mode, MALL_OVERVIEW HUD cash
visibility, retro-games register prompt swap, save-load numeric hardening,
and content-registry path traversal sanitization) and the in-source
justifications already cited elsewhere in the tree.

This document is the canonical home for every report section ID referenced
from the codebase via the literal string `error-handling-report.md`. If you
add a new in-code citation, add the matching section here.

## Changes made this pass (round 2)

| Path | Change | Section |
|---|---|---|
| `game/scripts/stores/retro_games.gd` | Boot-time `push_warning` in `_ready` when `checkout_counter/Interactable` is missing. The per-frame `_refresh_checkout_prompt` silent return is now paired with a one-shot startup signal — without it, a scene edit that drops the Interactable would silently leave the register prompt stuck on its initial label, which the player would read as "the register is broken" rather than as a wiring regression. | EH-07 |
| `game/scenes/mall/mall_overview.gd` | Added rationale comments on three silent guards: `_refresh_card` early-event arrival, `_moments_log_has_content` / `_completion_has_progress` UI button-gating, and `_on_customer_purchased`'s unknown-store counter increment. None of these are behavior changes — each describes an existing bounded silent path so a future reader can see the contract instead of guessing. | EH-08 |

## Changes made this pass (round 1)

| Path | Change | Section |
|---|---|---|
| `game/scripts/ui/inventory_shelf_actions.gd` | Split the `if not item or not inventory_system:` short-circuits in `place_item`, `remove_item_from_shelf`, and `move_to_backroom` so a missing `inventory_system` (programming error) emits `push_warning` while a null `item` stays a silent caller no-op. Added a docstring on `enter_placement_mode` documenting why the optional-item path is intentional. | EH-02, EH-04 |
| `game/scripts/ui/inventory_shelf_actions.gd` | When `enter_placement_mode` is called with an `ItemInstance` whose `definition` is null, emit `push_warning` instead of silently falling back to the generic hint — that combination is malformed inventory data, not an expected legacy path. | EH-03 |
| `game/scripts/ui/placement_hint_ui.gd` | Added a docstring on `_on_placement_hint_requested` citing EH-02 so the empty-string-fallback is recognisable as a documented contract rather than a missing log. | EH-02 |
| `game/scenes/ui/close_day_preview.gd` | `show_preview` now `push_warning`s when `_get_snapshot` is invalid instead of silently running the dry-run against an empty array. Without the warning, a wiring regression would surface as "No customers today" even when the shelves are full — a misleading UX outcome that hid the misconfiguration. | EH-05 |
| `tests/gut/test_close_day_preview.gd` | The two unit tests that instantiate `CloseDayPreview` directly (confirm flow, cancel flow) now wire an empty-snapshot callback before calling `show_preview()` so the EH-05 warning stays a real signal, not test noise. | EH-05 |
| `game/scenes/ui/hud.gd` | `_open_close_day_preview` now `push_warning`s before falling through to the direct `EventBus.day_close_requested.emit()` when the `CloseDayPreview` child is missing. The HUD scene ships the modal, so reaching the fallback is a scene-edit regression that should be loud. | EH-06 |
| `game/scenes/world/game_world.gd` | Documented the silent-return on `GameManager.State.GAME_OVER` in `_on_day_summary_mall_overview_requested` with a `§F-55` comment — the early return is intentional (terminal state must not be yanked back to MALL_OVERVIEW by a stray button press) and was previously undocumented. | §F-55 |

No behavior changes outside those listed. The remaining justified suppressions
(EH-01, EH-AS-1, §F-* and §J-* below) were reviewed and left as-is — each
already carries an in-source comment that points to its section here.

## Executive summary

- **Counts (post-pass).** Critical: 0. High: 0. Medium: 1 (Escalations §E1 —
  pack-open card-loss rollback gap, tracked, not introduced by this pass).
  Low: 0. Notes (intentional, documented suppressions): 25 (four new this
  round — EH-07 retro-games register-prompt boot warning, EH-08 mall-overview
  bounded silent guards, §J4 HUD state-fallthrough default, §DR-08
  scene-path traversal hardening; plus §SR-09 save-load numeric hardening
  added in the underlying diff).
- **Posture verdict.** Acceptable. Every silent path that survives is paired
  with either a typed return contract (EH-01), a runtime tripwire on the same
  code path (EH-AS-1), or an explicit doc comment that names the boundary
  where the failure becomes observable (every §F-* and §J-* entry). The
  silent fallback in `close_day_preview.gd` (callback unwired) and the silent
  fallback in `hud.gd` (preview child missing) are `push_warning`s (EH-05,
  EH-06); the day-summary `GAME_OVER` guard in `game_world.gd` is documented
  (§F-55). The retro-games register-prompt now warns once at boot when its
  Interactable is missing (EH-07) instead of silently no-op-ing on every
  queue tick. The save-loading hot path in `economy_system.gd` and
  `inventory_system.gd` now coerces NaN/Inf and out-of-range numerics on a
  hand-edited save (§SR-09); without it, a single corrupt field would lock
  every "do you have enough cash?" comparison to false and read as a process
  hang. `content_registry.gd` rejects `..` and `//` path components in
  registered scene paths (§DR-08) so the prefix sandbox can't be bypassed by
  an authoring typo.
- **Lens scoring.** Reliability: ok — no class of error is being swallowed
  end-to-end. Data integrity: ok with one caveat (Escalations §E1, an
  inventory-rollback gap during pack opening that the code now `push_error`s
  loudly but cannot atomically recover). Security: n/a — this is a
  single-player simulator with no auth surface. Observability: ok — every
  log-and-continue site logs at the appropriate severity (warning for
  recoverable, error for state-corruption-detected).

## Findings still needing follow-up

| ID | Severity | File | Outcome | Note |
|---|---|---|---|---|
| §E1 | Medium | `game/scripts/systems/pack_opening_system.gd` | **Escalation** (see bottom) | Pack consumed + cash charged → register failure → cards lost. `push_error` surfaces it but rollback is not atomic. Needs an explicit refund + pack re-register transaction; can't be tightened without changing `InventorySystem.register_item` to a two-phase API. |

Everything else in this report is either an **act** (code change above) or a
**justify** (typed contract / paired tripwire / documented boundary) and
needs no further work.

## Per-item rationale

### EH-01 — `ShelfSlot.place_item` / `remove_item` typed-bool / typed-string contracts

`game/scripts/stores/shelf_slot.gd:122-141`. `place_item` returns `false` when
the slot is already occupied; `remove_item` returns `""` when the slot is
empty. Both call sites (`InventoryShelfActions.place_item` and
`remove_item_from_shelf`) inspect the return and convert it to a localized
notification via `EventBus.notification_requested` or treat it as the
caller's signal to bail. This is a typed contract, not a silent failure: the
return type carries the outcome, and there is a UI surface for the
"occupied" branch. No log is appropriate because both rejection paths are
expected at runtime (player can right-click or press-E into an occupied
slot).

### EH-02 — `InventoryShelfActions.enter_placement_mode(item = null)` and `PlacementHintUI` fallback prompt

`game/scripts/ui/inventory_shelf_actions.gd:9-33`,
`game/scripts/ui/placement_hint_ui.gd:24-33`. The default-null `item`
parameter is required for legacy / test invocations
(`tests/gut/test_press_e_interaction_routing.gd:61, 107`). When the helper
is called without an item, we still emit
`EventBus.placement_hint_requested.emit("")` so `PlacementHintUI` flips
visible — the empty payload is a documented signal to the UI to show its
generic prompt (`_DEFAULT_PROMPT`) instead of the per-item one. The empty
fallback is intentional UX behavior, not a swallowed error. Both call sites
now carry comments that point here.

### EH-03 — `ItemInstance` without an `ItemDefinition` is malformed (push_warning)

`game/scripts/ui/inventory_shelf_actions.gd:21-32`. Distinct from EH-02: a
*non-null* `ItemInstance` whose `definition` is null is not an expected
legacy-path payload — it indicates an entry in the inventory that bypassed
`ContentRegistry` resolution. We previously fell straight through to the
generic hint, hiding the data corruption. The pass now emits a
`push_warning` with the offending `instance_id` so the divergence shows up
in CI / telemetry, while the UI still degrades gracefully to the generic
prompt rather than crashing.

### EH-04 — `InventoryShelfActions` requires a wired `inventory_system` (push_warning)

`game/scripts/ui/inventory_shelf_actions.gd:44-119`. The helper's
`inventory_system` is wired by `InventoryPanel.open()`
(`game/scenes/ui/inventory_panel.gd:158`), which itself `push_warning`s and
bails early if it has no system. So the only way `place_item`,
`remove_item_from_shelf`, or `move_to_backroom` execute with
`inventory_system == null` is a caller that constructed the helper directly
and skipped wiring — a programming error worth surfacing. The pass split the
combined `if not item or not inventory_system:` checks into two: null
`item` stays a silent no-op (legitimate guard), missing
`inventory_system` now `push_warning`s.

### EH-05 — `CloseDayPreview.show_preview` warns when the snapshot callback is unwired

`game/scenes/ui/close_day_preview.gd:72-87`. The dry-run simulator runs
against `Array[ItemInstance]` from the active store's shelves, supplied by
`HUD._get_active_store_snapshot` via `set_snapshot_callback`. If the wiring is
ever missed (the HUD scene loaded without the modal child, or the modal
was instantiated outside the HUD-driven path), `_get_snapshot.is_valid()` is
false. Previously the preview silently used an empty array and reported "No
customers today — stock up and try tomorrow.", which masquerades as a real
"no traffic" outcome and hides the misconfiguration. We now `push_warning`
before continuing, so the dry-run still completes (and the player can still
close the day) but the wiring regression is loud in CI / telemetry. The two
direct-instantiation tests (`test_preview_confirm_emits_day_close_requested_once`,
`test_preview_cancel_does_not_emit_day_close_requested`) wire an empty
snapshot before calling `show_preview()` so the warning is a real signal.

### EH-06 — `HUD._open_close_day_preview` warns and falls through when the modal child is missing

`game/scenes/ui/hud.gd:230-247`. `hud.tscn` ships a `CloseDayPreview` child;
reaching the fallback (direct `EventBus.day_close_requested.emit()` without
the dry-run preview) means the scene was edited to remove the modal or the
HUD was constructed outside the canonical scene path. We do not block the
day-close — pulling the only path to advance the day on a tooling regression
would be worse than the dry-run being skipped — but we `push_warning` so the
regression shows up in CI rather than degrading silently to the old
no-preview behavior.

### EH-07 — `RetroGames._refresh_checkout_prompt` paired boot-time warning

`game/scripts/stores/retro_games.gd:54-67, 332-346`. The retro-games
controller caches a reference to `checkout_counter/Interactable` in `_ready`
and uses it from `_refresh_checkout_prompt` to swap the prompt label
between "No customer waiting" and "Checkout Counter — Press E to checkout
customer" as `EventBus.queue_advanced` fires. Per-frame guards inside
`_refresh_checkout_prompt` are intentionally silent — the function runs on
every queue tick, so a `push_warning` there would flood the log on a busy
register. The boot-time `push_warning` in `_ready` (added this pass) covers
the wiring contract: `retro_games.tscn` ships the Interactable, so a missing
node means the scene was edited without the register fixture and the player
will see a stuck label. The single startup warning surfaces that regression
in CI / telemetry without per-tick noise.

### EH-08 — `MallOverview` bounded silent guards (cards / panels / counters)

`game/scenes/mall/mall_overview.gd`. Three silent paths in this scene are
intentional and now annotated rather than tightened:

- `_refresh_card` returns silently for store ids missing from `_cards`.
  Signals such as `inventory_updated` and `customer_purchased` can fire
  for stores that have not been added to the card grid yet (pre-`setup`,
  hub-side events tied to unowned slots, locked-store debug hooks). A
  `push_warning` on every miss would fire during normal mall startup and
  add no signal beyond a redraw that has nothing to redraw.
- `_moments_log_has_content` and `_completion_has_progress` return `false`
  when the panel/tracker is unwired. They drive the visibility of optional
  bottom-row buttons (Moments Log, Completion) — hiding the button until the
  underlying system reports content is the documented UX contract (the
  alternative is a button that opens an empty/all-Locked placeholder
  panel). `set_moments_log_panel` / `set_completion_tracker` are the wiring
  hooks; they re-poll the visibility check immediately on assignment, so
  the silent-`false` window is bounded by `game_world._setup_deferred_panels`.
- `_on_customer_purchased` increments `_store_sold_today[key]` even when
  the store has no card. The dict is reset by `_on_day_started` and only
  read through `_cards`, so unknown-store entries are bounded by one day
  and never surface to the UI.

None of these surfaces a real failure to the player; tightening them to
`push_warning` would create CI noise without revealing a bug. The comments
make the boundary auditable so a future change that breaks one of the
bounding assumptions (e.g. a non-day-1 reset of `_store_sold_today`, or a
store-card lifecycle that allows entries to appear and disappear mid-day)
can fall back here for the documented contract.

### EH-AS-1 — `assert()` calls across ownership autoloads are paired tripwires

`game/autoload/audit_log.gd:6-9` and the rest of the autoload roster
(`scene_router.gd`, `store_director.gd`, `camera_authority.gd`,
`input_focus.gd`). GDScript strips `assert()` from release builds, so a
naked assert would silently disappear. Every assert here is paired with a
runtime `push_error` / `AuditLog.fail_check` on the same code path: the
assert is a debug tripwire that catches the violation immediately in editor
/ headless tests, and the runtime check keeps the failure observable in
release. Stripping in release is the correct posture because the runtime
check still fires.

### §F-16 — `game_world.gd` load-validation `push_error` but continue

`game/scenes/world/game_world.gd:1378-1385`. After a save load, residual
content registry mismatches are surfaced via `push_error`. The game does
not abort to the menu because the alternative (kicking the player back to
main menu mid-day) is worse than degraded gameplay — most validation
errors are non-fatal (e.g. an item ID that no longer exists in
`ContentRegistry` falls back to a placeholder). The error path is loud
enough for CI to catch any regression that introduces routine validation
failures.

### §F-36 — `PlayerController._resolve_camera` returns null silently

`game/scripts/player/player_controller.gd:166-180`. If neither
`StoreCamera` nor `Camera3D` exists as a child, the resolver returns null.
Adding a `push_error` here would double-fire on the same contract violation
that `CameraAuthority` and `StoreReadyContract` already enforce: those two
fail loudly when no `current` camera is registered on `store_ready`. Two
log lines for one fault makes incident triage harder, not easier.

### §F-50 — Store-camera pivot bounds are constants, not store-specific

`game/scripts/systems/store_selector_system.gd:13-28`. `_STORE_PIVOT_BOUNDS_*`
and `_STORE_ZOOM_*` clamp the orbit pivot and zoom to the navigable floor
of every shipping store interior (±3.2 X, ±2.2 Z, zoom 2-5 m). A future
store with a larger nav footprint will silently over-clamp pan range. This
is acceptable today because every shipping store fits the constants, but
the comment in the source flags the contract loudly so the next store
author has to either fit it or hoist these into a per-store override.

### §F-51 — `_move_store_camera_to_spawn` no-ops on missing entry marker

`game/scripts/systems/store_selector_system.gd:261-275`. Every shipping
store ships a `PlayerEntrySpawn`, `EntryPoint`, or `OrbitPivot` Marker3D —
this is verified by `tests/gut/test_store_entry_camera.gd`. If a marker is
missing, the camera defaults to `_pivot = Vector3.ZERO`, which frames the
store center for any interior that straddles origin. The silent no-op is
the documented contract because the test suite catches the marker
omission before it ships.

### §F-52 — `DayCycleController._on_day_close_requested` Day-1 rejection emits push_warning

`game/scripts/systems/day_cycle_controller.gd:82-101`. HUD / MallOverview
emit `critical_notification_requested` to the player before the request
reaches the bus, but non-HUD callers (debug, automation, future AI
director, `close_day_preview.gd` if reopened outside gated paths) bypass
that UI. The `push_warning` ensures any unexpected rejection by this
controller looks like a real signal in logs rather than a no-op.

### §F-53 — `InteractionRay._build_action_label` returns "" silently

`game/scripts/player/interaction_ray.gd:212-230`. Returns "" when both the
verb and display name are blank. `Interactable.display_name` defaults to
"Item" and `prompt_text` auto-resolves from `PROMPT_VERBS`, so reaching this
branch requires deliberate scene-author blanking. A `push_warning` would
fire every frame the cursor enters that interactable, drowning logs while
adding no signal beyond the visibly-empty prompt panel.

### §F-55 — `_on_day_summary_mall_overview_requested` silent return on GAME_OVER

`game/scenes/world/game_world.gd:828-838`. Day Summary's "Return to Mall"
button calls `_on_day_summary_mall_overview_requested`, which transitions
to `MALL_OVERVIEW`. If the day cycle has already routed into `GAME_OVER`
(e.g. the player went bankrupt on the day that just closed), the button
must not yank the FSM out of the terminal state — game-over UI owns the
"what next" choice from there. The early return is therefore intentional
and now carries a `§F-55` comment so the silent branch is auditable. A
log here would fire on the happy GAME_OVER path and add noise.

### §F-54 — HUD notification forwarding shim drops messages when no listener

`game/scenes/ui/hud.gd:530-540`. `ToastNotificationUI` is a child of the
HUD; when the HUD is absent (MAIN_MENU, DAY_SUMMARY) `toast_requested` has
no listener and the message drops. This mirrors the prior in-HUD prompt
path's behavior — the reachable failure surface is unchanged by adopting
the toast forwarder, and the alternative (queuing toasts across scene
swaps) would risk leaking stale notifications into menu screens.

### §J1 — `GameManager._resolve_system_ref` returns null silently

`game/autoload/game_manager.gd:329-353`. Tier-5 UI ready (HUD
`_seed_counters_from_systems`, KPI strip, etc.) runs before world systems
have attached, and headless tests routinely call these resolvers without
the systems present. A log here would generate `push_warning` spam that
would break CI's error audit. Callers that *need* the system must assert
its presence themselves; readers should null-check.

### §J2 — `HUD._refresh_items_placed` / `_refresh_customers_active` silent null returns

`game/scenes/ui/hud.gd:756-794`. HUD is a Tier-5 init scene; on the very
first frame and during headless setup, `inventory_system` and
`customer_system` may legitimately be null. The HUD re-polls on every
`inventory_changed` / `customer_entered` / `customer_left` signal anyway,
so an early null is self-healing as soon as the systems publish their
first change.

### §J3 — `KPIStrip._try_load_milestone_total` silent null return

`game/scripts/ui/kpi_strip.gd:75-86`. `data_loader` is null during
pre-gameplay init frames. `_on_gameplay_ready()` re-polls once all systems
are live, so the silent return is bounded and self-healing.

### §A2 — `VideoRental._collect_late_fee` parks pending fees and emits push_error

`game/scripts/stores/video_rental_store_controller.gd:680-700`. Without
an `_economy_system`, the cash never lands. Emitting `late_fee_collected`
and bumping daily totals here would lie about revenue and silently drop
the pending fee. We instead `push_error`, write the fee into
`_pending_late_fees` so a downstream day-cycle handler can settle it once
the system is wired, and emit `EventBus.rental_late_fee` so the
notification UI still surfaces the fee.

### §F1 — `PackOpeningSystem._register_cards` partial-rollback loop

`game/scripts/systems/pack_opening_system.gd:475-494`. If the third card
in a pack fails to register (e.g. backroom hits capacity mid-loop), the
first two cards are already in `InventorySystem._items` but are about to
be discarded by the caller (no signal emitted, no UI update). Without
the rollback loop, a backroom-capacity boundary would leave orphaned
ItemInstances stuck in inventory while the UI thinks the open failed.
The rollback loop now removes them before bubbling the failure.

### §F2 — `FirstRunCueOverlay._is_inventory_empty` distinguishes test path vs. interface drift

`game/scripts/ui/first_run_cue_overlay.gd:152-169`. Null `inventory_system`
is the legitimate test / early-boot path; treat as empty so the cue still
fires when the eligibility timing window opens. A *bound* system that
lacks `get_stock`, however, is interface drift (a programming error),
and we `push_warning` once per call rather than silently lying about
emptiness.

### §J4 — `HUD._apply_state_visibility` default state fall-through

`game/scenes/ui/hud.gd:303-360`. The `match` over `GameManager.State` has
explicit branches for `MAIN_MENU` / `DAY_SUMMARY` (hidden), `MALL_OVERVIEW`
(visible, KPI strip owns cash), and `STORE_VIEW` (in-store HUD). The
default `_:` branch is a deliberate `pass`: `PAUSED`, `LOADING`, `BUILD`, and
any future intermediate state inherit the visibility established by the
last explicit transition. Implicit inheritance is correct because the HUD
should not flicker mid-pause or mid-load — the previous state's wiring
already reflects the right surface for the player. Any new
`GameManager.State` value that needs a distinct HUD presentation must be
added explicitly to the match; a CI-grep of "match state:" across hud.gd
catches drift.

### §DR-08 — `ContentRegistry._sanitize_scene_path` rejects `..` and `//`

`game/autoload/content_registry.gd:591-635`. `register_entry` runs
`_sanitize_scene_path` on every registered scene path and emits `push_error`
plus returns `""` if the path begins outside `res://game/scenes/`, does not
end in `.tscn`, contains `..` segments, contains `//` (empty path
components), or — for `content_type == "store"` — escapes the
`res://game/scenes/stores/` sub-prefix. The `..` / `//` clause is the
addition this pass: `res://` is engine-sandboxed, but a path like
`res://game/scenes/stores/../mall/mall_overview.tscn` would route a store
registration to a non-store scene while still satisfying the prefix lock,
and a doubled slash collapses into different resolved path strings depending
on consumer (`ResourceLoader.exists` vs grep tooling). Rejecting both at
registration time keeps the prefix sandbox, the boot-time
`validate_all_references()` check, and the runtime audit grep all aligned.

### §SR-09 — Save-load numeric hardening (NaN / Inf / out-of-range)

`game/scripts/systems/economy_system.gd:266-360` and
`game/scripts/systems/inventory_system.gd:579-895`.
`EconomySystem._apply_state` and `InventorySystem._apply_state` route every
numeric field loaded from save data through `_safe_finite_float`,
`_safe_finite_int`, or `_safe_finite_price`. Each helper rejects unsupported
Variant types, rejects NaN and Inf via `is_nan` / `is_inf`, and clamps to
configured bounds (e.g. cash ∈ [-1e9, 1e9], rent ∈ [0, 1e9], price ∈ [0,
1e9], time-minutes / sold-counts ∈ [0, 1_000_000]). Without this, a
hand-edited save with `player_cash = NaN` would propagate through every
"do you have enough cash to buy X?" comparison: `NaN >= cost` is always
`false`, so every purchase silently fails and the player reads it as a hang
on the buy button. Bounds are chosen well above any reachable in-game value
so honest saves are unaffected; the fallback default returns the field's
canonical starting value (e.g. `Constants.STARTING_CASH`) so the run can
continue with a clean numeric core after a corrupt save. `_safe_finite_*`
helpers are private to each system because the bounds are domain-specific —
inventory price ceiling differs from cash ceiling.

## Escalations

### §E1 — Pack-open card loss is loud but not atomic

**Location.** `game/scripts/systems/pack_opening_system.gd:97-112` (in
`open_pack`) and `:149-162` (in `commit_pack_results`).

**Symptom.** When `_register_cards` fails after `_prepare_pack_cards` has
already (a) removed the pack ItemInstance and (b) deducted cash, the
player ends up with no pack and no cards. The current code surfaces this
loud via `push_error` so it shows up in CI / telemetry instead of being a
silent loss.

**Why it can't be tightened in this pass.** Atomic rollback would require:

1. Refunding the pack purchase price to `EconomySystem`.
2. Re-registering the consumed pack ItemInstance back into
   `InventorySystem` at the same `instance_id`.
3. Re-emitting whatever signals the pack consumption emitted, in reverse.

`InventorySystem.register_item` does not currently expose a "register at a
specific id" path, and `EconomySystem.add_cash` is fine for the refund leg
but the pack-purchase event would need a paired refund signal so listeners
(quests, telemetry) don't double-count. This is a real architectural
change, not a code-comment fix.

**Smallest concrete next action.**

- Promote the partial-state to a typed `PackOpenOutcome` enum returned
  from `open_pack` / `commit_pack_results`: `OK`, `NO_CARDS`,
  `REGISTER_FAILED_CARDS_LOST`. Listeners can branch on the
  loss case and the UI can show a refund-pending toast.
- Then add `InventorySystem.register_item_with_id(id, item)` as the
  reservation primitive a future rollback would build on.

**Owner.** Inventory / pack-opening system owner. Not this pass.

## Severity glossary

- **Critical** — likely hides serious prod failures, security issues, or
  data loss. (None this pass.)
- **High** — meaningful prod risk, fix soon. (None this pass.)
- **Medium** — acceptable for now; tighten when convenient. (One: §E1.)
- **Low** — minor blind spot. (None this pass.)
- **Note** — intentional, low-risk, documented and done. (Twenty-five,
  including EH-05, EH-06, EH-07, EH-08, §F-55, §J4, §DR-08, and §SR-09
  introduced or formally documented in this pass.)
