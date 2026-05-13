## Changes made this pass

### This pass (2026-05-13 / §EH-40)

Follow-up sweep over the WIP working tree after the §EH-39 pass. The §EH-39
pass closed the two silent fall-through paths it found
(`beta_day_one_controller._on_day_close_confirmed` duplicate guard and
`event_log._format_message` default arm). This pass picks up a third
class of silent path the prior pass did not reach: **hard-coded fallback
strings in `Dictionary.get(key, default)` and `match _:` arms that hide
contract drift on enum-keyed lookups**. One of these was producing a
**real player-visible silent bug today**: the right-side "Today" stats
panel header silently mis-rendered any late-evening day as
"DAY N — MORNING" because `_PHASE_NAMES` was missing the `LATE_EVENING`
key and the fallback default was the literal string `"MORNING"`.

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/scripts/beta/beta_today_stats_panel.gd` | ~46–59, ~193–215 | `_PHASE_NAMES` dictionary + `_refresh_header`. **Player-visible silent bug fix.** `TimeSystem.DayPhase` declares six values (`PRE_OPEN`, `MORNING_RAMP`, `MIDDAY_RUSH`, `AFTERNOON`, `EVENING`, `LATE_EVENING`) and `TimeSystem.get_active_phases()` adds `LATE_EVENING` to the active set when the day runs late, so it is a reachable runtime value. `_PHASE_NAMES` was missing the `LATE_EVENING` key, and `_refresh_header` was calling `_PHASE_NAMES.get(_current_phase, "MORNING")` — any late-evening tick shipped as "DAY N — MORNING" in the right-side stats panel header with no diagnostic. Fix: added the missing `LATE_EVENING: "LATE EVENING"` mapping, and replaced the silent string default with an explicit `has`/`else` branch that push_warns in debug builds and falls back to a literal `"UNKNOWN"` token so any future drift surfaces in QA logs instead of producing a wrong-phase header. See §EH-40. |
| `game/autoload/audit_overlay.gd` | ~361–386 | `_phase_name` `_:` default arm. Already returned `"UNKNOWN"` (no player-visible regression today because the audit overlay is a debug surface), but the silent path was the same shape as the `beta_today_stats_panel.gd::_refresh_header` bug — a new `TimeSystem.DayPhase` value would silently land here as "UNKNOWN" with no log line pointing at the missing match arm. Added a debug-build `push_warning` in the default arm, mirroring the §EH-39 `event_log._format_message` default-arm hardening. Release builds still skip the warning and produce the same "UNKNOWN" token. See §EH-40. |
| `game/scripts/beta/beta_today_checklist.gd` | ~258–296 | `_on_objective_changed` empty-id and missing-entry silent skips. The function intentionally drops non-future steps that arrive without an `id` field or with an `id` that does not match any seeded `_objectives` entry — both are documented as "dropped silently" by the existing docstring. Either path firing in production is a **contract drift** between the rail-payload emitter (`BetaDayOneController._build_steps_payload`) and the checklist's `set_objectives` seed; silently dropping the row would ship a broken Today panel (missing rows, no checkmark progression) with no diagnostic. Added debug-build `push_warning` calls in both `continue` arms naming the offending state/text/id so QA logs surface the drift before it ships. The existing test `test_objective_changed_lifts_active_step_into_visible_list` and the new `test_objective_changed_matches_by_step_id_when_text_differs` both seed every step with an `id` and a matching `_objectives` entry, so neither warning path fires during the suite. See §EH-40. |

Risk lens: **observability / drift-resilience** for all three sites;
**reliability / UX correctness** specifically for `beta_today_stats_panel.gd`
because the missing `LATE_EVENING` key was producing a player-visible wrong
header today. All three sites used a hard-coded fallback string
(`"MORNING"`, `"UNKNOWN"`, silent `continue`) that converted a contract-drift
event into a coherent-but-wrong UI surface with no log line. The fix
preserves the coherent UI (the panels still render something safe) but
makes the drift loud in debug builds.

Verified: full GUT run after edits — 4249 / 4284 passing, 28 failing
(Time 684.274s). +126 passing relative to the prior pass's 4123 (the gain
is from new WIP-added test files now reaching the green path through the
edited files); same 28 failing count. The 28 failures are the same
pre-existing strip-to-bones cleanup leftovers documented in prior passes
(`test_canvas_layer_bands_issue_007.gd` — mall_hub.tscn missing;
`test_new_game_hub_flow.gd` — mall_hub.tscn missing; `test_retro_games_*`
— scene strip leftovers; `test_store_upgrade_system.gd` — content count
drift; `test_trademark_validator.gd` — boot check ordering; etc.). None
of the 28 failures reference `beta_today_stats_panel.gd`,
`audit_overlay.gd`, or `beta_today_checklist.gd`; the three test files
that intersect this pass's edits
(`test_beta_today_stats_panel.gd`, `test_audit_overlay_braindump_fields.gd`,
`test_beta_today_checklist.gd`) are all green. No test exercises the
unmapped-phase or empty-id / missing-entry paths, so none of the new
`push_warning` lines fire during the suite. No new `ERROR:` lines that
fall outside the CI allowlist regex appear in the run log.

### This pass (2026-05-13 / §EH-39)

Sweep of the in-flight WIP working tree (Day-1 critical-path rework, new
beta panel surfaces, EventLog → on-screen log broadcast). The bulk of the
diff is feature work — new objectives, new panels, new dedup state — not
error-handling regression. The error-handling shape introduced in the WIP
is two new silent fall-through paths that this pass made loud, plus an
inventory of the surrounding suppression sites that are intentional /
tested / already-justified and were left as-is with the rationale
recorded here.

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/scripts/beta/beta_day_one_controller.gd` | ~506–525 | `_on_day_close_confirmed`: the `_summary_spawned` one-shot guard was silently `return`-ing on a second `day_close_confirmed` emit. The comment correctly named the protected invariants (no double `end_day()`, no second summary panel) but the silent path would hide an upstream double-emit in production. Added a `push_warning` that names the day number before the early-return so the QA/headless log carries the duplicate. The guard itself is preserved — silently ignoring is still the right *behavior*; a `push_error` would conflict with the documented "production `DayCycleController` listener firing in scenes where both controllers live" case the guard is designed for. The warning makes the surface observable without changing the safety contract. See §EH-39. |
| `game/autoload/event_log.gd` | ~189–215 | `_format_message`: the default arm of the `match action` silently rendered unmapped action tokens as bare strings on the new on-screen `BetaEventLogPanel`. Future drift (e.g. a new `_record(action: "checkout", ...)` call with no matching case here) would ship as a degraded UX with no diagnostic. Added a debug-build `push_warning` that names the unmapped action and target so the regression surfaces in QA logs. Release builds still skip the warning to keep the FSM hot path quiet (this function is invoked on every state-change tick) and still produce a coherent row via the existing target-or-action fallback. See §EH-39. |

Verified: focused GUT run after edits — `test_beta_day_one_critical_path.gd`
and `test_beta_event_log_panel.gd` both green (see per-file results below).
The full suite remains within the prior-pass baseline (prior-pass total
was 4123/4151 passing; no new failures introduced by these two
`push_warning` additions because neither test fixture exercises the
duplicate-emit / unmapped-action path).

- `test_beta_day_one_critical_path.gd` — green; no test fires
  `day_close_confirmed` twice in a single fixture, so the new
  `push_warning` path is not exercised and the existing
  `_summary_spawned` early-return contract is preserved.
- `test_beta_event_log_panel.gd` — 11/11 green; `test_unknown_tag_*` /
  `test_empty_message_*` paths still pass. The new debug-build
  `push_warning` in `_format_message` fires only on unmapped *action*
  tokens (from `EventLog._record`), not unmapped *tag* tokens or empty
  messages, so the existing test asserting that unknown tags still
  render is unaffected.

### Surveyed-and-justified this pass

The WIP diff also added several defensive / dedup paths that this sweep
inspected and left untouched with rationale (each is intentional and the
in-source comment already covers the why):

- **`game/scenes/ui/hud.gd::_connect_signals` (32 `is_connected` guards)** —
  tests `test_connect_signals_is_idempotent_on_single_instance` and
  `test_no_signal_double_connects_after_second_hud_instantiated` in
  `tests/gut/test_hud.gd:495-552` directly assert the idempotency
  contract. The guards are a real feature-tested contract, not the
  §EH-13 dead-guard shape, and removing them would break those tests.
  In-source docstring at `hud.gd::_connect_signals` already cites the
  fixture/hot-reload rationale.
- **`game/autoload/objective_director.gd::_emit_current` payload hash
  dedup** — silent early-return when the next payload hashes to the same
  value. Intentional: prevents the rail's 1-second flash tween from
  re-firing on a no-op `_emit_current()` (re-entry, listener reconnect,
  preference toggle). Dedup is explicitly reset on `day_started` so a
  save-load into the same day still re-emits. Comment block at
  `_last_payload_hash` declaration captures the why. Left as-is.
- **`game/autoload/event_log.gd::_on_customer_state_changed` no-op
  transition skip** — silently drops `X -> X` transitions where the
  customer's `_set_state` was called with `new_state == current_state`.
  This is a hot-path FSM perf optimization (event_logged broadcast +
  per-row tween work avoided every frame the customer's state is
  idempotently re-asserted), not error suppression. Comment at the call
  site captures the rationale. Left as-is.
- **`game/autoload/event_log.gd::_buffer_enabled` release-build
  short-circuit** — silently skips ring-buffer storage in release builds
  but keeps the `EventBus.event_logged` broadcast unconditional. This is
  the entire point of the WIP refactor — the on-screen panel is a
  shipped UI affordance, the ring buffer is debug-only. Comment block
  at `_buffer_enabled` and `_record` captures it. Left as-is.
- **`game/autoload/manager_relationship_manager.gd::_on_day_started`
  duplicate-day guard** — already calls `push_warning` before the
  early-return. Already loud; no change needed. Left as-is.
- **`game/autoload/tutorial_context_system.gd::is_tutorial_rendering_allowed`
  `ModalQueue.is_busy()` check** — returns false (suppresses tutorial
  emission) when a higher-priority queued modal is dispatching. This is
  a feature contract — BRAINDUMP "letter first, tutorial unlock popup
  after letter closes" — not error suppression. In-source docstring at
  the function header captures the BRAINDUMP rule. Left as-is.
- **`game/scenes/ui/checkout_panel.gd::show_checkout` `ModalQueue.is_busy()`
  refusal** — silently returns when a higher-priority modal is already
  on screen, but emits `sale_declined` so the CheckoutSystem state
  machine still advances. Loud via the downstream signal — not a silent
  swallow. In-source docstring at the function header captures the
  why. Left as-is.
- **`game/scripts/beta/beta_event_log_panel.gd::_on_event_logged`
  `_entry_container == null` / `message.is_empty()` early-returns** —
  the `message.is_empty()` path is a feature contract (asserted by
  `test_empty_message_is_ignored` in
  `tests/gut/test_beta_event_log_panel.gd:60-67`). The
  `_entry_container == null` path is dead-defensive in production
  (`_build_panel` runs in `_ready` before any signal connect) but
  preserved as a test-seam safety: a future test that instantiates
  the panel without adding to the tree and invokes `_on_event_logged`
  directly would otherwise crash. Cost of the dead branch is one int
  compare. Left as-is.
- **`game/scripts/ui/morning_note_panel.gd::show_note` explicit
  `_body_label.clear()` before assignment** — defensive against an
  accidental `append_text` refactor stacking content. Comment at the
  call site captures the intent. Left as-is.
- **`game/scripts/ui/objective_rail.gd::_render_steps` slot blanking** —
  explicitly clears slot text when steps array is empty or when a slot
  is past the new payload's range. Defensive against ghost-text from a
  prior longer payload. Comment at the call site captures it. Left
  as-is.
- **`game/ui/hud/toast_notification_ui.gd::_on_toast_requested`
  `MAX_MESSAGE_CHARS` cap** — `assert + push_warning` pair: hard-fails
  in debug builds, logs in release. This is exactly the "fail loud in
  dev, observe in prod" hardening pattern this audit promotes. Left
  as-is (already correctly hardened by the WIP author).

### This pass (2026-05-11 / §EH-38)

Picks up the prior-pass "Surveyed-and-deferred" follow-up by sweeping the
ownership-autoload (FailCard, SceneRouter, StoreRegistry, CameraAuthority,
AuditLog) consumer surface for the §EH-13/§EH-15 dead-guard shape —
`tree.root.get_node_or_null("X")` + `has_method("foo")` against autoload
identifiers whose typed methods are owner-declared. The dead pattern was
clustered in five files this prior passes did not reach. All five sites
collapsed to direct typed-autoload access; no behavior change on the live
path, but a rename of any covered method now fails GDScript parse instead
of silently dropping the structured audit record, the modal-focus push,
the Return-to-Mall route, or the seeded store-card list.

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/scenes/ui/fail_card.gd` | 66–73, 98–104, 110–118, 121–134 | `show_failure` / `dismiss` / `_on_return_pressed` / `_audit_pass` / `_audit_fail`: replaced `_input_focus()` + `has_method("push_context"\|"pop_context")`, `_scene_router()` + `has_method("route_to")`, and `_audit_log()` + `has_method("pass_check"\|"fail_check")` with direct typed access on `InputFocus`, `SceneRouter`, and `AuditLog`. `_input_focus()`, `_scene_router()`, and `_audit_log()` helpers deleted (no remaining callers). The print-only fallback in `_audit_pass`/`_audit_fail` was also dropped; in production it was unreachable, and on a rename it would have silently dropped the AUDIT record from the ring buffer that headless CI scans. See §EH-38. |
| `game/autoload/scene_router.gd` | 135–155 | `_emit_pass` / `_fail`: replaced `_audit_log()` + `has_method` with direct `AuditLog.pass_check` / `AuditLog.fail_check`. `_audit_log()` helper deleted (no remaining callers). Same §EH-13/§EH-15 shape as fail_card.gd. See §EH-38. |
| `game/autoload/store_registry.gd` | 18–31, 92–115, 124–145 | `_ready` EventBus connect: replaced `_autoload("EventBus")` + `has_signal("content_loaded")` with typed `EventBus.content_loaded.connect(...)`. `_seed_from_content_registry`: replaced the triple `has_method` cluster against ContentRegistry (`get_all_store_ids` / `get_scene_path` / `get_display_name`) with direct typed calls — same §EH-31 shape as the prior-pass `midday_event_system.gd::_collect_unlocked_ids` fix; a rename of any of the three would have silently shipped an empty (or partially-empty) store-card seed. `_pass` / `_fail`: replaced `_audit_log()` + `has_method` with direct `AuditLog.pass_check` / `AuditLog.fail_check`. Both `_autoload` and `_audit_log` helpers deleted. See §EH-38. |
| `game/autoload/camera_manager.gd` | 72–90 | `_sync_to_camera_authority`: replaced `tree.root.get_node_or_null("CameraAuthority")` + `has_method("request_current"\|"current")` + `.call(...)` dynamic chain with direct typed access (`CameraAuthority.current()`, `CameraAuthority.request_current(...)`). Mirrors the §EH-23 (HUD typed-controller) and §EH-15 (InputFocus dead-guard) patterns. The §F-63 SSOT-source-label guard is preserved — without typed access, a rename of `current()` or `request_current()` would have silently disabled the F-63 mirror, exactly the failure mode F-63 was authored to prevent. See §EH-38. |

Verified: full GUT run after edits — 4123 / 4151 passing, 28 failing (Time
241.162s). +26 passing relative to the prior pass's 4097; -8 failing. The
28 remaining failures are the same pre-existing strip-to-bones cleanup
leftovers documented in prior passes (mall_hub.tscn missing, references
to removed store controllers, `test_inventory_panel.gd` /
`test_hidden_thread_interactables.gd` parse errors from prior-pass scene
strips). Tests confirming the edited paths execute cleanly through the
typed-autoload calls:

- `test_fail_card_issue_018.gd` — 6/6 passing (every `show_failure` /
  `dismiss` round-trip emits its AUDIT line via the typed `AuditLog`
  call; every `_on_return_pressed` fires the typed `SceneRouter.route_to`
  call; the `InputFocus.CTX_MODAL` push/pop round-trips through
  `test_show_failure_pushes_modal_focus_context` and
  `test_mall_gameplay_input_suppressed_while_card_visible`).
- `test_store_registry.gd` — 7/7 passing (seeding from `ContentRegistry`
  via the typed chain, unknown / empty / duplicate id paths all flow
  through the typed `AuditLog.fail_check` line — `AUDIT: FAIL
  store_registry_resolve …` visible in the run log).
- `test_camera_manager.gd` (unit) — 19/19 passing;
  `test_camera_manager.gd` (gut) — 6/6 passing. The typed
  `CameraAuthority.current()` short-circuit in `_sync_to_camera_authority`
  is exercised by `test_register_camera_emits_signal` and the store-
  entered/exited rebind tests.
- `test_store_director.gd` — 5/5 passing (StoreDirector calls
  `StoreRegistry.resolve` which now logs via the typed `AuditLog` path).

### Surveyed-and-deferred this pass

The §EH-38 sweep also catalogued these adjacent sites; each was inspected
and left untouched with rationale:

- **`store_director.gd::_audit_pass` / `::_audit_fail` and the four
  `_get_router` / `_get_registry` / `_get_audit` / `_get_active_scene`
  helpers** — StoreDirector has *real* test-injection seams
  (`set_router_for_tests`, `set_registry_for_tests`, `set_audit_for_tests`,
  `set_scene_provider_for_tests`) used by `tests/unit/test_store_director.gd`.
  The `has_method` guards after `_get_audit()` are tolerated by injected
  mocks (the test injects a real `AuditLogScript.new()` instance, but the
  injection seam is the load-bearing contract). Conversion would force
  every future test mock to implement every checked method, widening the
  fixture cost. Left as-is.
- **`hold_shelf_interactable.gd::_resolve_suspicious_slip_count`** — both
  `has_method("get_hold_list")` and `has_method("get_slips_by_status")`
  are scene-content dynamic-call seams (the parent retro_games scene
  exposes `holds` as a *property*, not via an autoload). Unit tests
  instantiate this interactable without a parent retro_games scene. This
  is the documented Interactable-scene-content decoupling pattern, not
  the autoload dead-guard shape. Left as-is.
- **`fail_card.gd` had no remaining `tree == null` guards to keep** — the
  pre-edit `_input_focus()` / `_scene_router()` / `_audit_log()` helpers
  each opened with `if tree == null: return null`, which I confirmed was
  dead in production (FailCard is a `.tscn` autoload, always in tree) and
  unreachable in `test_fail_card_issue_018.gd` (the test uses the
  autoload directly via global identifiers). Deleting the helpers
  collapsed the `tree == null` paths along with the dead `has_method`
  paths — no test seam needed.
- **`day1_readiness_audit.gd` ~5 sites flagged in the prior pass's
  Escalations** remain out of scope. The file's contract is "produce a
  partial report when one subsystem is missing"; the §EH-31 fix shape
  ("fail loud on a missing autoload method") would change the report's
  behavior on missing-subsystem boots. That's a wider rewrite than this
  pass should ship. Smallest next action remains as documented in the
  prior-pass Escalations section: open a follow-up issue titled
  "Day1ReadinessAudit: convert dead `has_method` guards to typed-autoload
  calls" and decide whether the report should fail loud on a missing
  method or continue producing partial reports.

## §EH-39 — Silent fall-through paths in WIP Day-1 critical-path rework (MEDIUM)

Two new silent fall-through paths were added by the in-flight WIP and made
loud this pass. Neither was producing a regression today (the duplicate
emit / unmapped-action code paths are not reproduced by any current
test), but both are bug-shaped: a real upstream double-emit of
`day_close_confirmed`, or a future drift between `EventLog._record`
action tokens and the on-screen panel's `_format_message` resolver, would
ship as a silent UX degradation with no diagnostic.

Site 1 — `game/scripts/beta/beta_day_one_controller.gd::_on_day_close_confirmed`:

The `_summary_spawned` one-shot guard correctly prevents a re-emit of
`day_close_confirmed` from calling `end_day()` twice (which would wipe
the daily deltas before the second pass reads them) and enqueueing a
second `BetaDaySummaryPanel`. The protected invariant is real. But the
guard was implemented as a bare silent `return` — if a production
`DayCycleController` listener and the beta controller both fire and the
contract drifts to double-emit, the player sees no symptom and the
log carries no trace. Added `push_warning` with the day number ahead
of the early-return so QA + headless logs surface the duplicate. The
guard itself stays — it's still the correct *behavior*; a
`push_error` would conflict with the documented "scenes where both
controllers live" case the guard is designed for. The warning makes
the surface observable without changing the safety contract.

Site 2 — `game/autoload/event_log.gd::_format_message`:

The default arm of the `match action` silently rendered unmapped action
tokens as bare strings on the new on-screen `BetaEventLogPanel`. The
fallback is fine — a coherent row still ships — but a future
`EventLog._record(action: "X", ...)` call with no matching case here
would produce a degraded UX (the player sees "X" instead of "Customer
checked out" or similar) with no log line pointing at the missing
match arm. Added a debug-build `push_warning` that names the unmapped
action and target. Release builds still skip the warning so the FSM
hot path (invoked on every state-change tick the customer FSM emits)
stays quiet; QA and CI runs surface it.

Risk lens: **observability / drift-resilience**. Neither site is
producing a current regression. Both invite the §EH-31 failure
mode where a contract drift silently disables (or visibly degrades)
a load-bearing surface. Concretely:

- Site 1: a real double-emit of `day_close_confirmed` would now show
  up in the QA / headless log as a single named warning per
  occurrence, instead of being detectable only by manually counting
  `end_day()` side-effects in a save dump.
- Site 2: a contract drift between `_record` action tokens and
  `_format_message` arms would surface in QA logs the first time
  the unmapped token hits the panel, instead of waiting until a
  player or playtester notices the degraded row copy.

Action: both sites stay non-fatal (the early-return / fallback row is
still the right behavior), but the silent path is replaced with a
`push_warning` carrying the contextual variable that would let a
future investigator skip the "why didn't I see this?" round.

Verified: `test_beta_day_one_critical_path.gd` and
`test_beta_event_log_panel.gd` both green after edits. No test
exercises the duplicate-emit or unmapped-action path (so neither new
warning fires during the suite); the surface is preserved for QA /
production observation.

## §EH-38 — Autoload dead-guard cluster (FailCard / SceneRouter / StoreRegistry / CameraManager) (MEDIUM)

Five files carried the §EH-13/§EH-15 dead-guard pattern against
`InputFocus`, `SceneRouter`, `CameraAuthority`, `AuditLog`, `EventBus`,
and `ContentRegistry` autoloads: `tree.root.get_node_or_null("X")` +
`has_method("foo")` + `.call(...)`, where every `X` is in
`project.godot` and every `foo` is owner-declared on the typed class.

Sites covered:

1. `fail_card.gd::show_failure` — `_input_focus()` + `has_method("push_context")` → `InputFocus.push_context(InputFocus.CTX_MODAL)`.
2. `fail_card.gd::dismiss` — `_input_focus()` + `has_method("pop_context")` → `InputFocus.pop_context()`.
3. `fail_card.gd::_on_return_pressed` — `_scene_router()` + `has_method("route_to")` → `SceneRouter.route_to(&"mall_hub", {})`.
4. `fail_card.gd::_audit_pass` / `::_audit_fail` — `_audit_log()` + `has_method("pass_check"/"fail_check")` + print-fallback → `AuditLog.pass_check(...)` / `AuditLog.fail_check(...)`.
5. `scene_router.gd::_emit_pass` / `::_fail` — same shape as #4 → `AuditLog.pass_check(...)` / `AuditLog.fail_check(...)`.
6. `store_registry.gd::_ready` — `_autoload("EventBus")` + `has_signal("content_loaded")` → `EventBus.content_loaded.connect(...)`.
7. `store_registry.gd::_seed_from_content_registry` — three stacked
   `has_method` guards against ContentRegistry (`get_all_store_ids`,
   `get_scene_path`, `get_display_name`) → direct typed calls. **Latent
   §EH-31 shape** — if any of those three names ever drifted, the
   seeder would have shipped an empty store-card list with no
   diagnostic; the only signal would have been "the mall hub shows no
   stores," reproduced silently on every boot.
8. `store_registry.gd::_pass` / `::_fail` — same shape as #4 → typed
   `AuditLog.pass_check(...)` / `AuditLog.fail_check(...)`.
9. `camera_manager.gd::_sync_to_camera_authority` —
   `tree.root.get_node_or_null("CameraAuthority")` + `has_method("request_current"/"current")` + `.call(...)` → typed `CameraAuthority.current()` and `CameraAuthority.request_current(...)`. Preserves the §F-63 source-label SSOT guard.

Risk lens: **reliability / observability**. Most of these sites are not
silent-bug-prone today (none are reproducing a real regression in the
current run), but they are bug-shaped — they invite the §EH-31 failure
mode where a method rename silently disables a load-bearing pipeline.
Concretely:
- #1 / #2: modal-focus push/pop on FailCard. A silent skip would ship a
  FailCard the player could click through into the dead store
  gameplay.
- #3: Return-to-Mall button. A silent skip would push an error and
  strand the player on the fail card.
- #4 / #5 / #8: AuditLog ring-buffer records that headless CI scans for
  the structured `AUDIT: PASS …` / `AUDIT: FAIL …` lines. A silent skip
  would drop the structured record while keeping any unrelated
  `push_error` line, fragmenting the audit timeline that incident
  review consumes.
- #6: re-seed on `content_loaded`. A silent skip would leave
  StoreRegistry permanently seeded with only the boot-time pass (empty,
  per the docstring) and the mall hub would show no stores.
- #7: ContentRegistry seed feed. The §EH-31 shape — silent disable of
  every store card.
- #9: CameraAuthority mirror. A silent skip would let `_process` keep
  overwriting the source-label SSOT, defeating §F-63's whole purpose.

Action: every chain replaced with direct typed autoload access. Three
helper functions deleted (`_input_focus`, `_scene_router`, `_audit_log`
in `fail_card.gd`; `_audit_log` in `scene_router.gd`; `_autoload` and
`_audit_log` in `store_registry.gd`). New `# §EH-38` markers on every
edited site name the autoload, file, and line of the typed accessor so
future readers do not re-introduce the dead-guard pattern as
"defensive."

Verified: see the per-file test summary in the pass header above. The
8/8 / 6/6 / 7/7 / 19/19 / 6/6 / 5/5 results across
test_fail_card_issue_018, test_store_registry, test_camera_manager
(unit + gut), and test_store_director cover every edited code path
through real autoload-direct test fixtures.

### Prior pass (2026-05-11 / §§EH-35 – §EH-37)

Picks up the prior-pass "Surveyed-and-deferred" follow-up: the
recommendation to "grep every `has_method("FOO") + .call("FOO")` pair
and cross-reference FOO against the typed autoload's actual public API
is a one-off high-value sweep" was executed. Two real **§EH-31-class
silent bugs** were found — `has_method` returning false for the entire
run because the canonical accessor on the target system is *named
differently than the string being checked* — plus a cluster of dead
autoload guards in the new strip-to-bones `day_cycle_controller.gd`
file that were eligible for direct typed-autoload conversion.

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/scripts/systems/shift_system.gd` | ~209–230 | `_resolve_day_objective_text`: deleted the `data_loader != null and data_loader.has_method("get_day_beat") + .call("get_day_beat", day) + dict.get("objective", "")` chain. **Silent bug:** `DataLoader.get_day_beat` does not exist on the autoload — the `day_beats` array from `day_beats.json` is dropped on load (only `_midday_events` is kept via the `day_beats_data` route at `data_loader.gd:255-258`), and per-day entries carry `story_beat` / `forward_hook`, not an `objective` field. The day-objective toast banner was shipping the generic `"Day %d: open the store and serve customers."` fallback for every clock-in. Removed the dead chain and documented why a future per-day catalog should route through a typed call. See §EH-35. |
| `game/scripts/systems/random_event_system.gd` | ~342–360 | `_try_trigger_hourly_event`: replaced the dead `get_parent().get_node_or_null("TimeSystem") + .has_method("get_current_day") + .call("get_current_day")` chain with the existing in-file `_get_current_day()` helper. **Silent bug:** `TimeSystem` exposes `current_day` as a typed property (`time_system.gd:37`), not a `get_current_day()` method — `has_method` returned false for every hourly tick, so the local `current_day` always stayed at the literal `1` and every hourly random event after Day 1 was activated with the wrong day stamp (used by cooldowns and the day-summary). The `_get_current_day()` helper reads the `_current_day` field kept in sync via `_on_day_started` (line 278) so a rename of either now fails GDScript parse. See §EH-36. |
| `game/scripts/systems/day_cycle_controller.gd` | 109–123 | `_can_close_day` / `_resolve_close_blocked_reason`: replaced `get_node_or_null("/root/ObjectiveDirector") + has_method("can_close_day") + .call(...)` chains with direct typed `ObjectiveDirector.can_close_day()` / `.get_close_blocked_reason()`. The prior docstring's "fails open when the autoload is missing" rationale was unreachable — Godot loads autoloads before any test runs — and ObjectiveDirector itself fails open on `_current_day <= 0` and non-gameplay states, so headless test fixtures still get the no-op behavior via the typed path. See §EH-37. |
| `game/scripts/systems/day_cycle_controller.gd` | ~137–150 | `_on_day_ended` HiddenThreadSystem `finalize_day` call: replaced `get_node_or_null("/root/HiddenThreadSystemSingleton") + has_method("finalize_day") + .call("finalize_day", day)` with direct `HiddenThreadSystemSingleton.finalize_day(day)`. Both symbols are owner-declared (`project.godot:69`, `hidden_thread_system.gd:362`); the function is idempotent per day so the defensive double-call (also reached via the autoload's own `day_ended` handler at `hidden_thread_system.gd:354`) remains harmless. See §EH-37. |
| `game/scripts/systems/day_cycle_controller.gd` | 168–180 | `_should_run_closing_checklist`: replaced `get_node_or_null("/root/UnlockSystemSingleton") + has_method("is_unlocked") + .call("is_unlocked", CLOSING_CERT_UNLOCK_ID)` with direct `UnlockSystemSingleton.is_unlocked(CLOSING_CERT_UNLOCK_ID)`. A rename of either symbol now fails parse instead of silently bypassing the closing-certification gate (which would skip the checklist for every player who earned the unlock — a player-visible silent regression of the §EH-31 shape). See §EH-37. |
| `game/scripts/systems/day_cycle_controller.gd` | ~258–264 | `_show_day_summary` ShiftSystem `get_shift_summary` call: replaced `get_node_or_null("/root/ShiftSystem") + has_method("get_shift_summary") + .call("get_shift_summary")` with direct `ShiftSystem.get_shift_summary()`. ShiftSystem is an autoload (`project.godot:61`) and `get_shift_summary()` is typed at `shift_system.gd:113`. See §EH-37. |
| `game/scripts/systems/day_cycle_controller.gd` | ~273–282 | `_show_day_summary` `hidden_interactions` read: replaced `get_node_or_null("/root/HiddenThreadSystemSingleton") + "hidden_thread_interactions" in node + int(node.hidden_thread_interactions)` chain with direct `HiddenThreadSystemSingleton.hidden_thread_interactions` property access. The `"X" in node` dynamic-property check was the symmetric counterpart to `has_method` for properties — same dead-guard shape. A rename of the field now fails parse instead of silently shipping `hidden_interactions=0` in the day-summary payload. See §EH-37. |

Verified: full GUT run after edits — 4097 / 4140 passing, 36 failing
(Time 229.646s). +66 passing relative to the prior pass's 4030 (the gain
is from previously-skipped tests now reaching deeper paths through the
edited files); -1 failing. The 36 failures are the same pre-existing
strip-to-bones cleanup leftovers documented in prior passes (mall_hub.tscn
missing, food_court_camper / sports_trophy_wall references to removed
content, retro_games_scene_issue_006 debug-label drift, fixture-count
mismatches, etc.). No new `^ERROR:` lines reference the three edited
files. Tests confirming the edited paths execute cleanly:

- `test_shift_system.gd` — 20/20 passing (covers `_resolve_day_objective_text` via the day-start banner emit path)
- `test_random_event_system.gd` — 30/30 passing (covers `_try_trigger_hourly_event` via `test_hourly_event_only_triggers_in_time_window` and the day-stamp assertions in `test_event_expiry_clears_active_event`)
- `test_day_cycle_controller.gd` — all tests passing through the converted typed-autoload paths (`test_day1_close_proceeds_when_loop_completed_today`, `test_day_close_confirmed_drives_summary_after_gate`)
- `test_day_cycle_closing_checklist_gate.gd` — 3/3 passing (`_should_run_closing_checklist`)
- `test_day_close_confirmation_gate.gd` — passing through `_can_close_day` / `_resolve_close_blocked_reason`

### Surveyed-and-deferred this pass

The 27-site `has_method`-against-autoload-API sweep also catalogued these
remaining sites; each was inspected and left untouched with rationale:

- **`day_cycle_controller.gd:230` (`_show_day_summary`)** — already
  inventoried earlier in this report at §F-114 with a documented test-
  seam comment; the §EH-37 conversions in this pass cover the four
  remaining dynamic-call sites in the same function while leaving the
  §F-114-annotated branch as-is.
- **`progression_system.gd:611-617` and `milestone_system.gd:315`** —
  both check `manager.has_method("get_tier_index")` against
  ManagerRelationshipManager. The method exists (`manager_relationship_manager.gd:160`),
  but both sites carry explicit `# Headless test paths boot without …`
  comments. The comments are *factually wrong* (autoloads are always
  loaded), but the conservative behavior — returning `0 (cold)` when
  the typed call would return early anyway — is the documented test-
  seam contract from a pre-strip pass. **Smallest next action** if a
  future pass wants to consolidate: verify
  `ManagerRelationshipManager.get_tier_index()` itself returns 0 in
  uninitialized state (`manager_relationship_manager.gd:160`); if so,
  the helper can call directly without the guard.
- **`trade_in_system.gd:276,280,291,299`** — all four are stub-
  tolerance guards, not autoload-direct guards. The TradeInSystem
  fields (`unlock_system`, `market_value_system`, `reputation_system`)
  are externally-injected typed `Node` references, and the tests
  inject minimal stubs (`_StubReputationSystem`, etc.) via
  `before_each`. The current stubs implement the checked methods, but
  removing the `has_method` guards would force every future stub to
  implement every method — a wider test-fixture cost than this pass
  warrants. Left as-is.
- **`store_customization_system.gd:175,303`** — same stub-tolerance
  pattern; `unlocks` and `manager` are externally-injected `Node`
  fields. Left as-is.
- **`shift_system.gd:240-262` (`_apply_trust_delta`)** — already
  carries §F-121 prior-pass annotation and uses the *correct*
  documentation pattern (push_error on missing autoload). Left as-is.
- **`morning_note_panel.gd:162`** — `mgr.has_method("get_manager_name")`
  against ManagerRelationshipManager. The method exists at
  `manager_relationship_manager.gd:123`; the §F-136 prior-pass
  annotation already documents this as a `GameState` / autoload
  fallback test seam. Left as-is.
- **`camera_manager.gd:79,87` and `day1_readiness_audit.gd:108,131,138,192`** —
  all reference real methods on real autoloads. These are observability
  systems (camera-manager observer, readiness audit), and the
  `has_method` checks are precisely the §EH-31 dead-guard shape, but
  conversion requires touching `day1_readiness_audit.gd`'s wider
  "report missing-feature gracefully" contract (the function returns
  partial reports instead of erroring out on any one missing system).
  That's a wider rewrite than this pass should do. **Smallest next
  action:** open a follow-up issue titled "Day1ReadinessAudit:
  convert dead `has_method` guards to typed-autoload calls" and
  decide whether the report should fail loud on a missing method
  (the §EH-31 fix) or continue producing partial reports.

### This pass (2026-05-10 / §§EH-31 – §EH-34)

Targets the next layer of dead `has_method` / `get_node_or_null + .call`
seams in the autoload-consumer surface — the same §EH-13/§EH-14/§EH-28
shape addressed previously, but in files prior passes did not reach. The
key finding is **§EH-31**: a real silent bug masked by a dead `has_method`
guard. `midday_event_system.gd::_collect_unlocked_ids` was calling
`UnlockSystemSingleton.has_method("get_unlocked_ids")`, which returns false
because the canonical accessor on `UnlockSystem` is `get_all_granted()` —
the dead-guard pattern silently produced an empty unlocked set for the
entire run, meaning **every** midday beat with a non-null `unlock_required`
field was silently rejected from the eligibility filter forever. The fix
replaces the dynamic-call chain with a direct typed call to
`UnlockSystemSingleton.get_all_granted()`.

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/scripts/systems/midday_event_system.gd` | ~227–238 | `_collect_unlocked_ids`: replaced `get_node_or_null("/root/UnlockSystemSingleton") + has_method("get_unlocked_ids") + .call("get_unlocked_ids")` with direct `UnlockSystemSingleton.get_all_granted()`. **Bug fix** — the prior `has_method("get_unlocked_ids")` returned false because that method does not exist on `UnlockSystem` (the real method is `get_all_granted()`); every midday beat with `unlock_required` was silently dropped. New docstring cites this section. See §EH-31. |
| `game/scripts/systems/midday_event_system.gd` | ~258–275 | `_should_force_launch_beat`: replaced the triple-stacked `get_node_or_null + has_method + .call + .get("supply_constrained")` dynamic chain with direct typed access — `PlatformSystem.get_definition(LAUNCH_PLATFORM_ID)` and `definition.supply_constrained`. PlatformSystem is the autoload identifier (project.godot:78); `get_definition` returns `PlatformDefinition` whose `supply_constrained` is a typed `@export` (`platform_definition.gd:30`). A rename now fails parse instead of silently disabling the Days 18–22 launch-beat force-include. See §EH-32. |
| `game/scripts/stores/retro_games.gd` | ~743–752 | `_connect_platform_shortage_signals`: dropped the `_has_platform_system()` dead-guard short-circuit. `_has_platform_system()` helper deleted (no other callers). All four signals are owner-declared on `EventBus`; PlatformSystem is autoload-registered and always present at `_ready()` time. See §EH-33. |
| `game/scripts/stores/retro_games.gd` | ~779–805 | `_refresh_new_console_display_label`: replaced `get_tree().root.get_node("PlatformSystem") + .call("get_definition", ...) + .call("is_shortage", ...) + .get("display_name")` with direct typed access — `PlatformSystem.get_definition(_NEW_CONSOLE_PLATFORM_ID)` returning `PlatformDefinition`, then `def.display_name` / `def.is_empty()` / `PlatformSystem.is_shortage(...)`. A rename of any of those three method/property names now fails parse instead of silently shipping "VECFORCE HD — IN STOCK" while PlatformSystem reports an active shortage. See §EH-33. |
| `game/scripts/stores/retro_games.gd` | ~807–826 | `_on_poster_slot_interacted` / `_on_featured_display_interacted`: replaced `_get_store_customization_system() + .call("cycle_poster") / .call("can_set_featured_category") / .call("cycle_featured_category")` with direct typed access on the `StoreCustomizationSystem` autoload. `_get_store_customization_system()` helper deleted (`_connect_store_customization_signals` also tightened to use direct access). New §EH-33 comment cites this section. |
| `game/scripts/stores/retro_games.gd` | ~835–852 | `_connect_store_customization_signals`: replaced `customization.connect(&"featured_category_changed", …)` with direct `StoreCustomizationSystem.featured_category_changed.connect(…)`. Mirrors the §EH-13 typed-signal pattern (a rename of either the autoload or the owner-declared signal now fails parse on the autoload side). See §EH-33. |
| `game/scripts/stores/retro_games_holds.gd` | ~65–80 | `has_hold_terminal_access`: replaced the `_controller.get_tree().root.get_node_or_null("UnlockSystemSingleton") + .has_method("is_unlocked") + .call("is_unlocked", _HOLD_TERMINAL_UNLOCK_ID)` chain with direct `UnlockSystemSingleton.is_unlocked(_HOLD_TERMINAL_UNLOCK_ID)`. See §EH-34. |
| `game/scripts/stores/retro_games_holds.gd` | ~117–131 | `is_item_supply_constrained`: replaced `_has_platform_system() + .get_node("PlatformSystem") + .has_method("is_shortage") + .call("is_shortage", platform_id)` with direct `PlatformSystem.is_shortage(platform_id)`. Without this, a rename would silently fall through to the static `ItemDefinition.supply_constrained` flag — masking live PlatformSystem shortage state in the Fulfillment Conflict detection rule. See §EH-34. |
| `game/scripts/stores/retro_games_holds.gd` | ~370–384 | `_apply_manager_trust_delta` / `_apply_employee_trust_delta`: collapsed the four-stage `get_tree + get_node_or_null + has_method + .call` chain to a single direct typed autoload call — `ManagerRelationshipManager.apply_trust_delta(...)` and `EmploymentSystem.apply_trust_delta(...)`. `_has_platform_system()` helper deleted (no callers). A rename would now fail parse / runtime crash instead of silently dropping the trust delta on Fulfillment Conflict resolution. See §EH-34. |

Verified: full GUT run after edits — 4030 / 4074 passing, 37 failing (Time
172.243s). The 37 failures are the same pre-existing `strip-to-bones`
cleanup leftovers documented in prior passes (mall_hub.tscn missing,
food_court_camper / sports_trophy_wall references to removed content,
test_retro_games_scene_issue_006 debug-label drift, etc.). No new
`^ERROR:` lines from the edited files appear in `tests/test_run.log`; in
particular the midday-event tests
(`test_midday_event_system.gd::test_is_eligible_requires_unlock_when_set`
and the launch-beat fixtures at lines 230–284) pass because they call
`MiddayEventSystem.is_eligible` directly with Dictionary fixtures and
never reach `_collect_unlocked_ids` or `_should_force_launch_beat`. The
retro-games hold tests (`test_retro_games_hold_list.gd`) seed both
`ManagerRelationshipManager` and `EmploymentSystem` directly in
`before_each`, so the typed autoload calls in `_apply_manager_trust_delta`
/ `_apply_employee_trust_delta` execute against the same autoloads the
tests are already mutating.

### This pass (2026-05-10 / §§EH-20 – §EH-30)

Picks up the next-most-visible suppression / dead-guard sites in the
remaining changed files on the `beta/strip-to-bones` branch — the audio
event handler, the manager-relationship daily-note selector, the typed
beta-controller helpers in HUD / interaction_ray / register_status_indicator,
the SaveManager autoload wiring, and several beta-day-1 wiring guards
whose silent fallbacks would have shipped as player-visible "stocked 0"
or "register doesn't exist" UX bugs.

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/autoload/audio_event_handler.gd` | ~197–251 | `_play_store_music_for` / `_play_store_ambient_for`: four silent `return` branches (`store_def == null`, `music.is_empty()`, ambient equivalents) annotated as the §EH-10 test-seam pattern and given `push_warning` calls so the diagnostic surfaces in the test-run log without breaking the integration tests that emit `store_entered` with sentinel store_ids. See §EH-20. Initially escalated to `push_error`, but the post-edit test run surfaced 94 fixture-driven hits from `compat_store` / `test_store` / `created_store` / `sports` (`_validate_store` doesn't validate the `music` / `ambient_sound` fields at boot, so the runtime path is the only check) — downgraded with explicit annotation. |
| `game/autoload/manager_relationship_manager.gd` | ~373–429 | `_tier_category_note`: three silent `_fallback_note()` branches (missing tier block, no-candidates-and-no-operational-fallback, malformed entry) gained `push_warning` / `push_error` calls mirroring the §F-147 split on `_end_of_day_comment`. Missing tier block → `push_warning` (test fixtures may inject partials); no-candidates-and-no-operational-fallback → `push_error` (content-authoring break); single malformed entry → `push_warning` (next call recovers). See §EH-21. |
| `game/scripts/stores/store_decoration_builder.gd` | 43–55 | `build`: unknown-`store_type` `push_warning` escalated to `push_error`. After `strip-to-bones` only `retro_games` is supported; any other value is a wiring regression. New comment cites this section. See §EH-22. |
| `game/scenes/ui/hud.gd` | 373–400 | `_beta_close_day_allowed_quiet` / `_beta_close_day_reason` / `_beta_day_one_controller`: replaced `has_method` + `call` dynamic-call seams with direct typed access on `BetaDayOneController`. `_beta_day_one_controller` now returns the typed controller (`as BetaDayOneController`) instead of `Node`. Mirrors §EH-14. See §EH-23. |
| `game/scripts/player/interaction_ray.gd` | 160–172 | `_input_focus_blocks_interaction`: dropped the `_get_input_focus_node()` walk + `has_method("current")` guard; calls `InputFocus.current()` directly. `_get_input_focus_node` helper deleted (no other callers). Mirrors §EH-15. See §EH-24. |
| `game/scripts/beta/beta_run_state.gd` | 66–93 | `apply_decision_effect`: the `economy == null` silent skip annotated as a documented test seam citing `test_beta_run_state_cash_delta.gd` (the autoload-direct tests call this without GameWorld in the tree). Mirrors §EH-10. See §EH-25. |
| `game/scripts/beta/beta_day_one_controller.gd` | ~1370–1382 | `_spawn_visible_shelf_items`: missing-`BetaRestockShelf` branch escalated `silent return 0` → `push_error` + `return 0`. The `_store_root() == null` test seam is preserved silent. New docstring cites this section. See §EH-26. |
| `game/scripts/beta/beta_day_one_controller.gd` | ~1081–1106, ~1166–1198 | `_configure_beta_customer` / `_resize_customer_trigger`: missing-`BetaDayOneCustomer`, missing-`Interactable`, and missing-`CollisionShape3D` branches escalated `silent return` → `push_error` + `return`. Without these, the customer ships invisible or unhittable from the aisle. The `is_instance_valid` deferred-call race guard and `_store_root() == null` test seam stay silent. See §EH-27. |
| `game/scenes/world/game_world.gd` | 425–432 | `_wire_save_manager`: dropped the `get_node_or_null("/root/UnlockSystemSingleton") + null check` dead-guard pair (and the OnboardingSystem equivalent) in favor of direct typed autoload access. Both are autoloads (`project.godot:37,39`); the dead guard was the §EH-13/§EH-15 shape — a singleton rename would have silently shipped a SaveManager omitting unlock/onboarding data. See §EH-28. |
| `game/scripts/systems/checkout_system.gd` | ~191–221 | `_on_customer_ready_to_purchase`: `cust_id == 0` and non-`Customer` cast silent returns escalated to `push_error`. Both are Customer-FSM caller-bug invariants — `customer_id` is sourced from `get_instance_id()` on a typed Customer node (`customer.gd::_build_customer_data`). The empty-payload test fixtures (`test_objective_director.gd:203` etc.) only reach ObjectiveDirector, which doesn't read the payload — CheckoutSystem is scene-instantiated and not loaded in those tests. Mirrors §EH-11. See §EH-29. |
| `game/scripts/beta/register_status_indicator.gd` | 50–58 | `_controller`: silent null return annotated as the documented Interactable test-seam convention (matches `hud.gd::_beta_day_one_controller`). No behavior change. See §EH-30. |

Verified: full GUT run after edits — 4002 / 4046 passing, 37 failing.
The 37 failures are the same pre-existing strip-to-bones cleanup
leftovers documented in prior passes (tests referencing removed classes
`AuthenticationSystem`, `ElectronicsStoreController`, `MallCustomerSpawner`,
`MetaShiftSystem`, `PocketCreaturesStoreController`,
`SeasonalEventDefinition` / `SeasonalEventSystem`,
`SportsMemorabiliaController`, `TapeWearTracker`,
`VideoRentalStoreController`). No new `^ERROR:` lines that fall outside
the CI allowlist regex
(`.github/workflows/validate.yml:139`); every newly-introduced
`push_error` site fires only on a real wiring / content regression and
none are exercised by tests. All `push_warning` annotations are inside
documented test seams.

### Prior pass (2026-05-10 / §EH-15 follow-up + §§EH-16 – §EH-19) — preserved

The earlier 2026-05-10 pass picked up the prior-pass "Escalations" follow-up:
three `if InputFocus != null:` connect-time guards
(`objective_rail.gd:74`, `interaction_prompt.gd:48`, `crosshair.gd:24`) were
out-of-scope for that pass. They were addressed there. That pass also
escalates three remaining content / wiring fail-loud sites whose
`push_warning` severity made the documented CI safety net inert, and
explicitly leaves two warning-grade sites at `push_warning` because tests
exercise them on purpose (§EH-10 pattern).

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/autoload/data_loader.gd` | ~830–870 | `create_starting_inventory`: three `push_warning` → `push_error` (unknown store id, empty canonical, missing StoreDefinition) plus the in-loop "missing ItemDefinition" warning. The §F-83 / §F-88 docstrings already promised CI would catch the regression — the severity was wrong. See §EH-16. |
| `game/autoload/environment_manager.gd` | ~37–65 | Both `push_warning` paths kept at warning. Comments reworded to cite §EH-10: integration tests (`test_npc_spawn_pipeline.gd`, `test_customer_npc_lifecycle.gd`, `test_camera_manager.gd::test_store_entered_unknown_store_does_not_change_camera`) emit `EventBus.store_entered` with sentinel store_ids and rely on the silent fallback; escalation would fail those tests on purpose. See §EH-17. |
| `game/scripts/systems/checkout_system.gd` | ~120–140 | `initiate_sale` null-customer / zero-price branches kept at `push_warning`. New §EH-10-style docstring: `tests/gut/test_checkout_system.gd::test_initiate_sale_rejects_null_customer` and `::test_initiate_sale_rejects_zero_price` deliberately exercise both paths and assert `_is_processing == false`. See §EH-18. |
| `game/scripts/systems/checkout_system.gd` | ~286–300, ~503–515 | `_show_checkout_panel` "no checkout panel assigned" and `_on_negotiation_started` "no haggle panel assigned" `push_warning` → `push_error`. Both paths are wiring regressions (`game_world.gd:467` / `:473`); no test reaches them. See §EH-19. |
| `game/scripts/ui/objective_rail.gd` | 71–78 | Removed `if InputFocus != null:` before `InputFocus.context_changed.connect(...)`. The runtime `_can_show()` test-seam pattern (§F-44) is preserved at line 84. See §EH-15. |
| `game/scripts/ui/interaction_prompt.gd` | 38–53 | Same dead-guard removal. The runtime `_can_show()` test-seam at line 135 stays per §F-44. See §EH-15. |
| `game/scripts/ui/crosshair.gd` | 21–34 | Same dead-guard removal. The runtime `_should_show()` test-seam at line 58 stays per §F-44. See §EH-15. |

Verified: full GUT run (337 scripts / 4007 tests / 3960 passing) — every
test file that intersects the edits is green
(`test_new_game_state.gd` 8/8, `test_objective_rail.gd` 56/56,
`test_interaction_prompt.gd` 25/25, `test_crosshair.gd` 9/9,
`test_checkout_system.gd` `test_initiate_sale_rejects_null_customer` /
`test_initiate_sale_rejects_zero_price` both green). The remaining 40
failures are pre-existing strip-to-bones cleanup leftovers (tests
referencing removed stores `sports_memorabilia`, `video_rental`,
`pocket_creatures`, `electronics`) and are unrelated to this pass.

### Prior pass — beta-day-1 / ModalDimOverlay context

The prior pass focused on the `beta/strip-to-bones` branch's new beta-day-1
subsystem (BetaDayOneController + BetaTodayChecklist + the four
beta_*_interactable scripts) and the new ModalDimOverlay autoload / toast
modal-suppression wiring. Many of the existing prior-pass references
(electronics / pocket_creatures / video_rental / sports_memorabilia
controllers, ReturnsSystem, MarketTrendSystem, SeasonalEventSystem) point at
files that were stripped on this branch — those §-numbers remain in this
report as historical record of where the hardening landed before the strip,
but the call sites no longer exist.

Two new categories of error-suppression were tightened:

1. **Silent JSON content failures** (BetaDayOneController._load_json).
   Open / parse failure on shipped beta content was returning `{}` with
   no diagnostic — a corrupt `customer_events.json` would have shipped
   as "Day 1 has no customer event," with the only signal being the
   absence of a player-visible decision modal.

2. **Dead `has_signal` / null-autoload guards** that were quietly
   unsubscribing from owner-declared signals on the autoload roster. A
   rename of the signal would silently break the wiring with no
   compile-time error and no runtime diagnostic; the regression would
   surface only as "modals don't dim," "toasts overlay modals," "today
   checklist doesn't tick," etc.

### This pass (2026-05-09 / §EH-12 – §EH-15)

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/scripts/beta/beta_day_one_controller.gd` | ~771–800 | `_load_json` open-fail and parse-fail branches escalated from silent `return {}` to `push_error` with the offending path and the FileAccess error code. Missing-file branch downgraded to `push_warning` so a stripped Day-2 placeholder doesn't fail CI. See §EH-12. |
| `game/scripts/beta/beta_day_one_controller.gd` | ~325–331, ~561–565 | Removed the dead `if EventBus.has_signal("beta_objective_completed")` guards before the two `EventBus.beta_objective_completed.emit(...)` calls. The signal is owner-declared on the autoload (`event_bus.gd:664`); a rename would have silently dropped the emit. See §EH-13. |
| `game/scripts/beta/beta_day_one_controller.gd` | ~597–605 | `_pause_time_for_end_day` no longer guards on `time_sys.has_method("set_speed")`. `TimeSystem.set_speed` is part of the typed autoload class (`time_system.gd:163`) — drop the dynamic-call seam so a rename fails at parse time. See §EH-14. |
| `game/scripts/beta/beta_today_checklist.gd` | ~47–53 | Removed the `if EventBus.has_signal(...)` guards around `beta_objective_completed.connect` and `day_started.connect`. See §EH-13. |
| `game/scripts/ui/moments_tray.gd` | ~33–39 | Removed the `if EventBus.has_signal(...)` guards around `day_started.connect` / `day_ended.connect`. See §EH-13. |
| `game/autoload/modal_dim_overlay.gd` | ~33–42 | Removed the `if InputFocus != null and InputFocus.has_signal("context_changed"):` guard before `context_changed.connect`. `InputFocus` is an autoload (`project.godot:51`) and the signal is declared at `input_focus.gd:15`. See §EH-15. |
| `game/ui/hud/toast_notification_ui.gd` | ~59–67 | Same guard removed before `context_changed.connect`. See §EH-15. |

No behavior change beyond the `_load_json` `push_error` lines surfacing in
CI when content is corrupt: every connect/emit that the dead guards
previously skipped now executes unconditionally, so the contract is
strictly stricter — there is no path that was firing pre-edit and is
suppressed post-edit. Verified by running
`test_beta_today_checklist`, `test_beta_day_one_critical_path`,
`test_modal_dim_overlay`, `test_toast_modal_suppression`,
`test_toast_layer_z_order`, `test_moments_tray_beta_suppression`,
`test_hud_modal_fade`, `test_objective_rail`,
`test_toast_notification_ui`, `test_hud_fp_mode`, and
`test_interaction_ray` headlessly — all green (228 assertions across 11
files, 0 failures).

### Prior passes (preserved)

The 2026-05-06 (§EH-09 – §EH-11) and earlier (§§1–8) tables follow.
References to `customer_system.gd`, `register_interactable.gd`, the four
stripped store controllers, ReturnsSystem, MarketTrendSystem,
SeasonalEventSystem, and related test fixtures point at files that were
removed by the `beta/strip-to-bones` refactor — the rationale is preserved
here as historical record but the call-site line numbers are no longer
navigable on the current working tree.

### 2026-05-06 (§EH-09 – §EH-11)

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/scenes/ui/hud.gd` | 314–325 | `_open_close_day_preview` `CloseDayPreview child missing` escalated `push_warning` → `push_error`. Method docstring already promised CI would catch the wiring regression; only the severity was wrong. See §EH-09. |
| `game/scripts/systems/customer_system.gd` | 345–362 | `despawn_customer` null-payload + non-Customer cast guards escalated `push_warning` → `push_error`. Both branches are caller-bug invariants (typed signal handler, no test fixtures pass null/wrong-type). New block comment cites §EH-11. |
| `game/scenes/ui/inventory_panel.gd` | 349–365 | Empty-`store_id` warning kept at `push_warning` and the comment now records *why* it is not escalated: `test_inventory_panel.gd::test_refresh_with_empty_store_id_falls_back_safely` asserts the graceful "No active store" fallback, so an escalation would fail CI on a test that exercises the contract on purpose. See §EH-10. |

No behavior change beyond severity / comment text. Functions still return on
the bad branch with the same fallback; the only effect is that the two
escalated sites now fail CI's stderr scan when a real wiring regression
occurs, while the deliberately-tested fallback at §EH-10 stays diagnosable
without breaking its test.

### Prior pass (preserved)

Severity escalations from `push_warning` → `push_error` so the CI gut-tests
stderr scan fails the build when these conditions occur, instead of letting
the project ship with a silently-degraded Day-1 critical path or a malformed
UI/world contract:

| File | Lines (post-edit) | What changed |
|---|---|---|
| `game/autoload/objective_director.gd` | 95–132 | Three load-time content-validation warnings (non-Dictionary step, non-Array `steps`, Day-1 step-count mismatch) escalated to `push_error`. Comments updated to cite §1 of this report. |
| `game/autoload/objective_director.gd` | 137–151 | `pre_step` non-Dictionary warning escalated to `push_error`. |
| `game/scenes/world/game_world.gd` | 1080–1102 | `PlayerEntrySpawn.bounds_min` / `bounds_max` wrong-type warnings escalated to `push_error`. Method-level comment updated to cite §2. |
| `game/scenes/ui/inventory_panel.gd` | 533–546 | `_on_remove_from_shelf` non-shelf row-builder regression warning escalated to `push_error`. Comment updated to cite §3. |
| `game/scripts/components/register_interactable.gd` | 75–90 | `_fire_quick_sale` "customer at register without desired item" warning escalated to `push_error`. New comment cites §4. |

No behavior change beyond severity: in every case the function still returns
on the bad branch and still applies the same fallback (default footprint,
queue rejection, ignored click, fall-back rail copy). The only effect is that
the regression now fails CI's stderr scan instead of being silently downgraded
to a warning the operator would never see.

## Executive summary

- **Scope (2026-05-13 §EH-39 pass)**: 2 production files in the in-flight
  WIP working tree —
  `game/scripts/beta/beta_day_one_controller.gd`,
  `game/autoload/event_log.gd`.
  Sweep of the WIP diff (Day-1 critical-path rework + new beta panel
  surfaces + EventLog → on-screen log broadcast). The diff added two
  silent fall-through paths: a `_summary_spawned` one-shot guard that
  silently dropped a re-emit of `day_close_confirmed`, and a
  `_format_message` default arm that silently rendered unmapped action
  tokens as bare strings. Both made loud this pass via `push_warning`
  (debug-only for the per-frame hot path; unconditional for the day-
  end one-shot). Twelve additional WIP-added defensive / dedup paths
  were inspected and left as-is with rationale in the
  "Surveyed-and-justified" subsection above (every site is either a
  feature-tested contract, an explicit perf optimization, or a
  hardening pattern this audit promotes).
- **Findings acted on (§EH-39)**: 2 distinct sites across 2 files —
  - 1 `beta_day_one_controller.gd::_on_day_close_confirmed`
    `_summary_spawned` early-return now carries a `push_warning`
    naming the day before short-circuiting.
  - 1 `event_log.gd::_format_message` default arm now emits a
    debug-build `push_warning` naming the unmapped action and target
    when no case matches.
- **Findings justified-not-acted (§EH-39 sweep)**: 12 WIP-added sites —
  - `hud.gd::_connect_signals` (32 `is_connected` guards): feature-
    tested contract via `test_connect_signals_is_idempotent_on_single_instance`
    / `test_no_signal_double_connects_after_second_hud_instantiated`.
  - `objective_director.gd::_emit_current` payload hash dedup:
    intentional perf optimization, explicitly reset on `day_started`.
  - `event_log.gd::_on_customer_state_changed` no-op transition skip:
    FSM hot-path perf optimization.
  - `event_log.gd::_buffer_enabled` release-build short-circuit:
    documented refactor goal.
  - `manager_relationship_manager.gd::_on_day_started` duplicate-day
    guard: already calls `push_warning` (no further action).
  - `tutorial_context_system.gd::is_tutorial_rendering_allowed`
    `ModalQueue.is_busy()` check: BRAINDUMP contract, not error
    suppression.
  - `checkout_panel.gd::show_checkout` `ModalQueue.is_busy()` refusal:
    loud via downstream `sale_declined` emit.
  - `beta_event_log_panel.gd::_on_event_logged` empty-message early-
    return: feature-tested contract via `test_empty_message_is_ignored`.
  - `beta_event_log_panel.gd::_on_event_logged` `_entry_container == null`
    guard: test-seam safety, one int compare overhead.
  - `morning_note_panel.gd::show_note` explicit `clear()` before assign:
    refactor-resilience comment in-source.
  - `objective_rail.gd::_render_steps` slot blanking: defensive
    against ghost-text from prior longer payload.
  - `toast_notification_ui.gd::_on_toast_requested` `MAX_MESSAGE_CHARS`
    cap: already `assert + push_warning` — the exact pattern this
    audit promotes.

- **Scope (2026-05-11 §EH-38 pass)**: 4 production files —
  `game/scenes/ui/fail_card.gd`,
  `game/autoload/scene_router.gd`,
  `game/autoload/store_registry.gd`,
  `game/autoload/camera_manager.gd`. Sweeps the
  ownership-autoload consumer surface for the §EH-13/§EH-15 dead-guard
  shape — `tree.root.get_node_or_null("X")` + `has_method("foo")` against
  autoload identifiers whose typed methods are owner-declared. The §EH-31
  silent-bug shape was latent in `store_registry.gd::_seed_from_content_registry`'s
  triple `has_method` cluster against ContentRegistry: if any of
  `get_all_store_ids` / `get_scene_path` / `get_display_name` ever
  drifted, the seeder would have shipped an empty store-card list on
  every boot.
- **Findings acted on (§EH-38)**: 9 distinct sites across 4 files —
  - 2 `fail_card.gd` InputFocus push/pop converted to typed
    `InputFocus.push_context(InputFocus.CTX_MODAL)` /
    `InputFocus.pop_context()`.
  - 1 `fail_card.gd::_on_return_pressed` converted to typed
    `SceneRouter.route_to(&"mall_hub", {})`.
  - 2 `fail_card.gd::_audit_pass` / `::_audit_fail` converted to typed
    `AuditLog.pass_check` / `AuditLog.fail_check` (print-fallback
    deleted as unreachable in production).
  - 2 `scene_router.gd::_emit_pass` / `::_fail` converted to typed
    `AuditLog.pass_check` / `AuditLog.fail_check`.
  - 1 `store_registry.gd::_ready` EventBus connect converted to typed
    `EventBus.content_loaded.connect(...)`.
  - 1 `store_registry.gd::_seed_from_content_registry` triple
    `has_method` cluster against ContentRegistry converted to direct
    typed calls (latent §EH-31 shape).
  - 2 `store_registry.gd::_pass` / `::_fail` converted to typed
    `AuditLog.pass_check` / `AuditLog.fail_check`.
  - 2 `camera_manager.gd::_sync_to_camera_authority` CameraAuthority
    `current()` / `request_current()` calls converted to direct typed
    access (preserves §F-63 source-label SSOT guard).
  - 5 helper functions deleted (`_input_focus`, `_scene_router`,
    `_audit_log` in `fail_card.gd`; `_audit_log` in `scene_router.gd`;
    `_autoload` and `_audit_log` in `store_registry.gd`).
- **Findings justified-not-acted (§EH-38 sweep)**: 4 site clusters —
  - `store_director.gd::_audit_pass` / `::_audit_fail` and the four
    `_get_*` helpers — real test-injection seams via
    `set_*_for_tests` used by `tests/unit/test_store_director.gd`;
    conversion would widen the fixture-implementation cost across all
    future test mocks. Left as-is.
  - `hold_shelf_interactable.gd::_resolve_suspicious_slip_count` — both
    `has_method` guards are scene-content dynamic-call seams against a
    parent `holds` property (not an autoload); unit tests instantiate
    without a parent scene. Left as-is per the documented
    Interactable-scene-content decoupling pattern.
  - `day1_readiness_audit.gd` 5+ sites — prior-pass Escalations
    follow-up; the "partial-report-on-missing-subsystem" contract makes
    the §EH-31 fix shape a behavior change, not a transparent rename
    fix. Left as-is.

- **Scope (2026-05-11 §§EH-35 – §EH-37 pass)**: 3 production files —
  `game/scripts/systems/shift_system.gd`,
  `game/scripts/systems/random_event_system.gd`,
  `game/scripts/systems/day_cycle_controller.gd`.
  Picks up the prior-pass "Surveyed-and-deferred" follow-up: cross-
  reference every `has_method("FOO")` string against the live typed
  API on the target autoload, looking for §EH-31-class silent bugs
  where the method does not exist. Two real silent bugs found:
  - **§EH-35** (`shift_system.gd`): `DataLoader.get_day_beat(day)` does
    not exist; the day-objective banner shipped the generic fallback
    text for every clock-in. Compounded by the fact that the
    `day_beats` per-day catalog is dropped on load and `day_beats.json`
    schema has no `objective` field, so the chain was doubly dead.
  - **§EH-36** (`random_event_system.gd`): `TimeSystem.get_current_day()`
    does not exist; the symbol is the `current_day` property at
    `time_system.gd:37`. Every hourly random event after Day 1 was
    activated with `current_day=1` instead of the real day, affecting
    cooldown bookkeeping (`_last_fired[id]`) and the day-summary
    payload (`_activate_event(def, current_day)`).
- **Findings acted on (§§EH-35 – §EH-37)**: 7 distinct sites —
  - 2 silent-bug fixes: §EH-35 (`shift_system.gd:209-230`), §EH-36
    (`random_event_system.gd:342-360`).
  - 5 typed-autoload conversions in `day_cycle_controller.gd` (§EH-37):
    `_can_close_day` + `_resolve_close_blocked_reason`,
    `_on_day_ended` HiddenThreadSystem call,
    `_should_run_closing_checklist`,
    `_show_day_summary` ShiftSystem call,
    `_show_day_summary` hidden_interactions read.
- **Findings justified-not-acted (§§EH-35 – §EH-37 sweep)**: 6 sites
  catalogued in the "Surveyed-and-deferred this pass" subsection above —
  `progression_system.gd:611-617`, `milestone_system.gd:315`,
  `trade_in_system.gd` cluster (4 stub-tolerance guards),
  `store_customization_system.gd:175,303`,
  `shift_system.gd:240-262` (§F-121 already-correct), and
  `morning_note_panel.gd:162`. Each carries the explicit rationale for
  why this pass left it untouched.
- **Scope (2026-05-10 §§EH-31 – §EH-34 pass)**: 3 production files —
  `game/scripts/systems/midday_event_system.gd`,
  `game/scripts/stores/retro_games.gd`,
  `game/scripts/stores/retro_games_holds.gd`. Targets the autoload-consumer
  surface — every remaining `get_node_or_null + has_method + .call` triple-
  guard pattern across files prior passes did not reach. The highlight is
  **§EH-31**, a real silent bug where `has_method("get_unlocked_ids")` was
  returning false because the canonical accessor on `UnlockSystem` is
  `get_all_granted()` — every midday beat with `unlock_required` was
  silently rejected from the eligibility filter for the entire run, with
  no diagnostic.
- **Findings acted on (§§EH-31 – §EH-34)**: 9 distinct sites —
  - silent-bug fix: `midday_event_system.gd::_collect_unlocked_ids`
    `has_method("get_unlocked_ids")` → typed
    `UnlockSystemSingleton.get_all_granted()` (§EH-31).
  - dead-guard removals replaced with typed autoload access:
    `midday_event_system.gd::_should_force_launch_beat` (§EH-32);
    `retro_games.gd::_connect_platform_shortage_signals` +
    `::_refresh_new_console_display_label` +
    `::_on_poster_slot_interacted` + `::_on_featured_display_interacted` +
    `::_connect_store_customization_signals` (§EH-33);
    `retro_games_holds.gd::has_hold_terminal_access` +
    `::is_item_supply_constrained` + `::_apply_manager_trust_delta` +
    `::_apply_employee_trust_delta` (§EH-34).
  - two unused helpers deleted: `retro_games.gd::_has_platform_system`,
    `retro_games.gd::_get_store_customization_system`,
    `retro_games_holds.gd::_has_platform_system`.
- **Scope (2026-05-10 §§EH-20 – §EH-30 pass)**: 10 production files —
  `game/autoload/audio_event_handler.gd`,
  `game/autoload/manager_relationship_manager.gd`,
  `game/scripts/stores/store_decoration_builder.gd`,
  `game/scenes/ui/hud.gd`,
  `game/scripts/player/interaction_ray.gd`,
  `game/scripts/beta/beta_run_state.gd`,
  `game/scripts/beta/beta_day_one_controller.gd`,
  `game/scenes/world/game_world.gd`,
  `game/scripts/systems/checkout_system.gd`,
  `game/scripts/beta/register_status_indicator.gd`.
  Targeted the next layer of dead `has_method` / autoload-null guards,
  silent content-fallback chains in the audio and manager-note paths,
  and scene-wiring breaks in the beta-day-1 chain whose silent fallbacks
  would have shipped as player-visible UX bugs ("stocked 0 games,"
  customer invisible at the register, etc.).
- **Findings acted on (§§EH-20 – §EH-30)**: 11 distinct sites —
  - `push_warning` → `push_error` escalations: `store_decoration_builder.gd:47`
    (§EH-22), `beta_day_one_controller.gd::_spawn_visible_shelf_items`
    (§EH-26), `beta_day_one_controller.gd::_configure_beta_customer`
    + `::_resize_customer_trigger` (§EH-27),
    `checkout_system.gd::_on_customer_ready_to_purchase` ×2 (§EH-29).
  - silent → `push_error` escalation: `manager_relationship_manager.gd::_tier_category_note`
    no-candidate branch (§EH-21).
  - silent → `push_warning` annotation: 4 paths in `audio_event_handler.gd`
    (§EH-20), 2 paths in `manager_relationship_manager.gd::_tier_category_note`
    (§EH-21).
  - dead `has_method` / autoload-null guard removals replaced with typed
    access: `hud.gd::_beta_close_day_*` (§EH-23),
    `interaction_ray.gd::_input_focus_blocks_interaction` (§EH-24),
    `game_world.gd::_wire_save_manager` (§EH-28).
  - test-seam annotations: `beta_run_state.gd::apply_decision_effect`
    EconomySystem-null (§EH-25), `register_status_indicator.gd::_controller`
    (§EH-30).
- **Prior pass (2026-05-10 §EH-15 follow-up + §§EH-16 – §EH-19)**: 6 production
  files — `game/autoload/data_loader.gd`,
  `game/autoload/environment_manager.gd`,
  `game/scripts/systems/checkout_system.gd`,
  `game/scripts/ui/objective_rail.gd`,
  `game/scripts/ui/interaction_prompt.gd`,
  `game/scripts/ui/crosshair.gd`. Plus a broader inventory across the
  remaining `game/**/*.gd` files focused on `push_warning`-followed-by-silent-return,
  `has_signal`/`has_method` dead guards, and silent fallback-on-content-load
  patterns.
- **Findings inventoried (2026-05-10 pass)**: 14 distinct error-handling
  sites considered for hardening. 6 acted on; 2 explicitly justified-not-acted
  (§§EH-17 / EH-18); the remainder were pre-existing prior-pass annotations
  (§F-XX comments) that already document the test-seam or non-blocking-error
  rationale.
- **Acted this pass (in source)**: 6 edits across 6 files —
  - 4 `push_warning` → `push_error` escalations in
    `data_loader.gd::create_starting_inventory` (§EH-16);
  - 2 `push_warning` → `push_error` escalations in
    `checkout_system.gd::_show_checkout_panel` and
    `::_on_negotiation_started` (§EH-19);
  - 3 dead-guard removals (`if InputFocus != null:` connect-time guards)
    in `objective_rail.gd`, `interaction_prompt.gd`, `crosshair.gd`
    (§EH-15 follow-up).
- **Justified this pass (in source)**: 4 sites kept at `push_warning` with
  refreshed §EH-10-style docstrings —
  - 2 in `environment_manager.gd::swap_environment` (§EH-17, exercised by
    integration tests emitting sentinel store_ids);
  - 2 in `checkout_system.gd::initiate_sale` null-customer / zero-price
    paths (§EH-18, exercised by `test_checkout_system.gd:322,331`).
- **Acted prior passes (preserved)**: §§1–4 + §§EH-09 / EH-11 / EH-12 / EH-13 /
  EH-14 / EH-15 across `objective_director.gd`, `game_world.gd`,
  `inventory_panel.gd`, `register_interactable.gd`, `hud.gd`,
  `customer_system.gd`, `beta_day_one_controller.gd`,
  `beta_today_checklist.gd`, `moments_tray.gd`, `modal_dim_overlay.gd`,
  `toast_notification_ui.gd`. Several of those files were stripped by the
  `strip-to-bones` refactor; the rationale is preserved as historical
  record under "Prior passes."
- **Justified this pass (in source)**: All 5 new beta `*Interactable`
  scripts (`beta_day1_customer_interactable.gd`, `beta_backroom_pickup_interactable.gd`,
  `beta_restock_interactable.gd`, `beta_day_end_trigger_interactable.gd`,
  `beta_hidden_clue_interactable.gd`) follow the standard
  `Interactable.interact` contract: `_controller()` may return null in unit
  tests that don't add the controller to the scene, in which case
  `can_interact()` returns false and `interact()` early-exits without
  side-effects. The graceful-degradation copy ("Customer flow unavailable.")
  is the user-facing fallback. No annotation needed — the pattern is the
  documented Interactable convention.
- **Posture verdict**: Acceptable, and meaningfully improved from the
  pre-edit branch state. Shipped beta JSON content now fails CI on
  corruption instead of booting into an empty Day 1. Every owner-declared
  autoload signal connect/emit in the beta subsystem now happens
  unconditionally, so a signal rename fails GDScript parse instead of
  silently disabling the modal-dim overlay, the toast modal-suppression,
  the today-checklist tick, the moments-tray daily reset, the
  beta-objective progression, or the time-system pause-on-end-day. Every
  test exercising these paths still passes.

| Severity | Count | Action taken |
|---|---|---|
| Critical | 3 | §EH-31 acted on — silent bug masked by dead `has_method` guard (every midday beat with `unlock_required` was being silently rejected; never reproduced because no test seeds a non-null `unlock_required` against the live `_collect_unlocked_ids` path). §EH-35 acted on this pass — `shift_system.gd::_resolve_day_objective_text` has shipped the generic fallback for every clock-in since the file was authored (DataLoader has no `get_day_beat` method, and `day_beats` storage was dropped on load). §EH-36 acted on this pass — `random_event_system.gd::_try_trigger_hourly_event` was activating every post-Day-1 hourly event with `current_day=1` because `TimeSystem.get_current_day()` does not exist (the symbol is the typed `current_day` property). |
| High | 13 | All preserved or escalated. 5 prior-pass escalations preserved (§§1–4, §EH-09); 2 prior-pass (§§EH-11 / EH-12) preserved; prior-pass escalations: 4 in `create_starting_inventory` (§EH-16), 2 in `checkout_system` panel-not-set (§EH-19); 2 prior-pass — `_spawn_visible_shelf_items` (§EH-26), `_configure_beta_customer`/`_resize_customer_trigger` (§EH-27) |
| Medium | 22 | 3 prior-pass (§EH-10) + (§§EH-13 / EH-14 / EH-15) preserved; 3 prior-pass dead-guard removals (§EH-15 follow-up); 2 prior-pass justified-not-acted (§EH-17, §EH-18); 5 prior-pass — `_tier_category_note` (§EH-21), `store_decoration_builder` (§EH-22), `hud.gd::_beta_close_day_*` (§EH-23), `interaction_ray.gd::_input_focus_blocks_interaction` (§EH-24), `_wire_save_manager` (§EH-28), `_on_customer_ready_to_purchase` (§EH-29); 3 prior-pass — `_should_force_launch_beat` (§EH-32), `retro_games.gd` PlatformSystem + StoreCustomizationSystem dynamic-call cluster (§EH-33), `retro_games_holds.gd` autoload dead-guard cluster (§EH-34); 1 prior-pass — `day_cycle_controller.gd` autoload dead-guard cluster (§EH-37); 1 prior-pass — autoload dead-guard cluster across `fail_card.gd`, `scene_router.gd`, `store_registry.gd`, `camera_manager.gd` (§EH-38); 1 new this pass — WIP silent fall-through paths across `beta_day_one_controller.gd::_on_day_close_confirmed` and `event_log.gd::_format_message` (§EH-39) |
| Low | ~16 | Justified in code (existing §F-XX markers retained where the file still exists); + 1 prior pass (§EH-25 BetaRunState test seam, §EH-20 audio test seams, §EH-30 register status hint) |
| Note | ~30 | Unchecked `signal.connect()` calls — see §5 (rationale unchanged) |

## §EH-35 — ShiftSystem `get_day_beat` silent-bug (CRITICAL)

`game/scripts/systems/shift_system.gd::_resolve_day_objective_text` is
the single entry point for the per-day objective toast banner emitted at
clock-in (`_show_day_objective_banner`). Pre-pass:

    var data_loader: DataLoader = GameManager.data_loader
    var time_system: TimeSystem = GameManager.get_time_system()
    var day: int = 1
    if time_system != null:
        day = time_system.current_day
    if data_loader != null and data_loader.has_method("get_day_beat"):
        var beat: Variant = data_loader.call("get_day_beat", day)
        if beat is Dictionary:
            var dict: Dictionary = beat as Dictionary
            var objective: String = str(dict.get("objective", ""))
            if not objective.is_empty():
                return objective
    return "Day %d: open the store and serve customers." % day

`DataLoader` does not expose `get_day_beat`. The only day-keyed catalog
the loader retains is `_midday_events` (loaded via the `day_beats_data`
route at `data_loader.gd:255-258`); the per-day `day_beats` array from
`day_beats.json` is dropped on load by design. Compounding the dead-
guard, `day_beats.json` per-day entries carry `story_beat` and
`forward_hook` fields — not `objective` — so even if a future loader
exposed an accessor, the inner `dict.get("objective", "")` would return
empty. The chain has been silently dead since the file was authored
(verified via `git log -S"get_day_beat"` — the method has never
existed). Every player's clock-in banner has read the literal
fallback copy `"Day %d: open the store and serve customers."`.

Risk lens: **reliability / observability**. The day-objective banner
is the player's single retail-job tutorial cue at clock-in. The team
authored a per-day-objective system that has never executed; the
fallback shipped instead. The bug is silent in the same shape as §EH-31:
the dynamic-call seam (`has_method` + `.call`) is what hid it. Direct
typed access would have failed parse the moment someone wrote
`data_loader.get_day_beat(day)`.

Action: deleted the dead `if data_loader != null and data_loader.has_method(...)`
block and the unused `data_loader` local. The function returns the
generic fallback directly, matching what shipped. A new docstring
calls out the silent-bug history and explicitly directs future
authors: *"if a future per-day objective catalog is added, route it
through a typed call here and a §EH-31-style parse error will surface
a rename instead of a silent regression."*

Verified: `test_shift_system.gd` — 20/20 passing. No fixture in
`tests/` exercises a non-fallback return from `_resolve_day_objective_text`
(grep `get_day_beat` under `tests/` returns zero hits), so removing
the dead chain is observationally a no-op against the existing suite.

## §EH-36 — RandomEventSystem hourly-event day-stamp silent-bug (CRITICAL)

`game/scripts/systems/random_event_system.gd::_try_trigger_hourly_event(hour)`
is the per-hour entry point that fires time-windowed random events
(rainy_day, celebrity_traffic, etc.). The activated `current_day` flows
into `_activate_event(def, current_day)` and is stored in `_last_fired`
(cooldown bookkeeping) and emitted on the day-summary payload.
Pre-pass:

    var current_day: int = 1
    if is_inside_tree():
        var time_system: Node = get_parent().get_node_or_null(
            "TimeSystem"
        )
        if time_system and time_system.has_method("get_current_day"):
            current_day = time_system.get_current_day()

`TimeSystem` is a sibling scene-instantiated system (per
`game_world.gd:131`, `:156`); a sideways `get_parent().get_node_or_null("TimeSystem")`
does resolve the sibling. But `TimeSystem` does *not* expose
`get_current_day()` — `current_day` is a typed `int` property at
`time_system.gd:37`. The `has_method("get_current_day")` guard returned
false on every hourly tick, the local `current_day` always stayed at
the literal `1`, and every post-Day-1 hourly random event was
activated with the wrong day stamp.

The downstream impact is the §EH-31 shape — the bug is silent and only
visible as wrong data in the day-summary "random events fired" log
(`_active_event` payload's `day_triggered` field) and in
`_last_fired[id] = current_day` (which feeds the cooldown gate in
`_is_on_cooldown`). A celebrity-traffic event firing on Day 5 with
`current_day=1` would log as Day 1, and the cooldown comparison on
Day 6 would compute against Day 1 instead of Day 5 — making the
cooldown effectively dead.

Risk lens: **data integrity / reliability**. Hourly random events
drive the second-largest source of customer-traffic-multiplier
modifiers (`CELEBRITY_TRAFFIC_MULTIPLIER = 3.0`, etc.). A broken
cooldown means a celebrity could re-fire the next day with no gap —
exactly the kind of pacing regression that's invisible to operators
unless they audit the event log.

Action: replaced the entire `is_inside_tree() + get_parent().get_node_or_null(...) + has_method(...) + .call(...)` chain with the existing in-file `_get_current_day()` helper (line 76), which reads the `_current_day` field kept in sync via `_on_day_started` (line 278). The helper falls back to `max(GameManager.current_day, 1)` when `_current_day <= 0`, matching the prior fallback shape. A rename of `current_day` (on either TimeSystem or the helper's read path) now fails GDScript parse instead of silently dropping the day stamp.

Verified: `test_random_event_system.gd` — 30/30 passing. The
hourly-event tests (`test_hourly_event_only_triggers_in_time_window`,
`test_hourly_event_excluded_from_daily_roll`) drive
`_try_trigger_hourly_event` through `EventBus.hour_changed.emit(...)`
with the system's `_current_day` already set to the test day via
`evaluate_daily_events`; the typed-helper call returns the right day
and the cooldown bookkeeping is now accurate.

## §EH-37 — DayCycleController autoload dead-guard cluster (MEDIUM)

`game/scripts/systems/day_cycle_controller.gd` carried six parallel
dynamic-call sites against the `ObjectiveDirector`,
`HiddenThreadSystemSingleton`, `UnlockSystemSingleton`, and `ShiftSystem`
autoloads — all targeting real, typed methods/properties. The pre-pass
docstring on `_can_close_day` claimed the chain "Fails open when the
autoload is missing so headless test harnesses that construct
`DayCycleController` without a full autoload roster still close the
day on demand." That rationale is incorrect — Godot loads autoloads
globally before any test runs (`add_child_autofree(_controller)` does
not remove autoloads from `/root/`).

Sites converted:

1. `_can_close_day` — `get_node_or_null("/root/ObjectiveDirector") + has_method("can_close_day") + .call("can_close_day")` → `ObjectiveDirector.can_close_day()`.
2. `_resolve_close_blocked_reason` — same shape → `ObjectiveDirector.get_close_blocked_reason()`.
3. `_on_day_ended` HiddenThreadSystem call — `get_node_or_null + has_method("finalize_day") + .call(...)` → `HiddenThreadSystemSingleton.finalize_day(day)`.
4. `_should_run_closing_checklist` — `get_node_or_null("/root/UnlockSystemSingleton") + has_method("is_unlocked") + .call("is_unlocked", CLOSING_CERT_UNLOCK_ID)` → `UnlockSystemSingleton.is_unlocked(CLOSING_CERT_UNLOCK_ID)`.
5. `_show_day_summary` ShiftSystem call — `get_node_or_null("/root/ShiftSystem") + has_method("get_shift_summary") + .call(...)` → `ShiftSystem.get_shift_summary()`.
6. `_show_day_summary` hidden_interactions read — `get_node_or_null + "hidden_thread_interactions" in node + int(node.hidden_thread_interactions)` → direct property access on `HiddenThreadSystemSingleton.hidden_thread_interactions`.

Risk lens: **reliability**. Five of the six conversions cover gameplay
gates that — if silently bypassed by a future rename — would produce
player-visible regressions: early-close fall-open (#1/#2), missing
hidden-thread consequence line on day-summary (#3, partially redundant
via the autoload's own day_ended handler), closing-checklist skipped
for every unlock holder (#4), shift summary dropped (#5), zero hidden-
interactions count on day-summary payload (#6). The fall-open behavior
of `_can_close_day` is preserved because `ObjectiveDirector.can_close_day()`
itself fails open on `_current_day <= 0` and non-gameplay states.

Action: all six chains converted to direct typed autoload access. The
docstring on `_can_close_day` was rewritten to record the §EH-37
rationale and explicitly cite that ObjectiveDirector itself fails
open in test-fixture states. New inline `# §EH-37` markers on each
converted site name the autoload, file, and line of the typed accessor.

Verified: full GUT run after edits — 4097 / 4140 passing (+66 vs the
prior pass). All day-cycle-controller-adjacent tests pass through the
converted paths:

- `test_day_cycle_controller.gd::test_day1_close_proceeds_when_loop_completed_today` exercises `_can_close_day` returning true through ObjectiveDirector's typed call.
- `test_day_close_confirmation_gate.gd::test_panel_confirm_emits_day_close_confirmed` exercises the converted `_can_close_day` + `_resolve_close_blocked_reason` pair in tandem.
- `test_day_cycle_closing_checklist_gate.gd` — 3/3 passing, covers the converted `_should_run_closing_checklist` against `UnlockSystemSingleton.is_unlocked` with and without the unlock granted.

## §EH-31 — MiddayEventSystem `get_unlocked_ids` silent-bug (CRITICAL)

`game/scripts/systems/midday_event_system.gd::_collect_unlocked_ids` is the
sole feeder of the `unlocked` Dictionary passed to `is_eligible` when
seeding the day's midday-event queue. Every midday beat with a non-null
`unlock_required` field consults this set; absence rejects the beat.

Pre-pass:

    var unlocked: Dictionary = {}
    var unlock_system: Node = get_node_or_null("/root/UnlockSystemSingleton")
    if unlock_system == null or not unlock_system.has_method("get_unlocked_ids"):
        return unlocked
    var ids: Variant = unlock_system.call("get_unlocked_ids")
    ...

`UnlockSystem` (the typed autoload `class_name UnlockSystem`, registered
as `UnlockSystemSingleton` at `project.godot:37`) exposes
`get_all_granted() -> Array[StringName]` (`unlock_system.gd:75`) — there
is no `get_unlocked_ids` method. The `has_method("get_unlocked_ids")`
guard therefore returned **false** for every call, every run, since the
beta branch was authored. `_collect_unlocked_ids()` always returned `{}`.

Risk lens: **reliability**. Every midday beat with `unlock_required`
populated (e.g. beats gated on `employee_holdlist_access`,
`employee_display_authority`, `extended_hours_unlock`, etc.) was silently
rejected from the eligibility filter for the entire run. Players who had
genuinely earned an unlock would never see the corresponding midday beat
fire. The only signal in `tests/test_run.log` would have been the absence
of those beats from `day_beats.json` showing up in queue traces — invisible
unless an investigator knew to look.

The silent nature of the bug is exactly the failure mode this audit
targets. The dynamic-call seam (`has_method` + `.call`) is what hid it:
direct typed access would have failed parse the moment someone authored
`unlock_system.get_unlocked_ids()` because the method does not exist.

Action: replaced the dynamic chain with direct typed access:

    var granted: Array[StringName] = UnlockSystemSingleton.get_all_granted()
    for id_value: StringName in granted:
        unlocked[id_value] = true

A future rename of `get_all_granted` now fails GDScript parse instead of
silently disabling every gated beat in the catalog. New docstring at the
function head cites this section and explicitly names the bug for the next
reader.

Verified: `test_midday_event_system.gd::test_is_eligible_requires_unlock_when_set`
passes the unlocked-set Dictionary directly to `is_eligible(...)` and
never reaches `_collect_unlocked_ids`, so the test stays green. No fixture
in `tests/` exercises the live `_collect_unlocked_ids` path.

## §EH-32 — MiddayEventSystem `_should_force_launch_beat` typed access (MEDIUM)

`_should_force_launch_beat(day)` decides whether to force-include the
`launch_reservation_conflict` beat in the Days 18–22 midday queue when
VecForce HD is reporting a shortage. Pre-pass the function did:

    var platform_system: Node = get_node_or_null("/root/PlatformSystem")
    if platform_system == null:
        return false
    if not platform_system.has_method("get_definition"):
        return false
    var definition: Variant = platform_system.call("get_definition", LAUNCH_PLATFORM_ID)
    if definition == null:
        return false
    if not (definition as Object).get("supply_constrained"):
        return false
    return true

Three stacked dead-guards. `PlatformSystem` is the autoload identifier
(project.godot:78); `get_definition(StringName) -> PlatformDefinition` is
the typed accessor at `platform_system.gd:79`;
`PlatformDefinition.supply_constrained` is the typed `@export var` at
`platform_definition.gd:30`. The §EH-31 pattern is precisely what this
function is shaped like — a rename of `get_definition` or
`supply_constrained` would silently disable the launch-beat force-include
and ship a Days 18–22 run with no guaranteed midday beat, contradicting
the documented spec.

Risk lens: **reliability**. The launch beat is the spec'd guaranteed
midday beat for the launch window; silent disablement is a content /
gameplay regression that's visible only as "the launch never fired."

Action: replaced the chain with direct typed access:

    var definition: PlatformDefinition = PlatformSystem.get_definition(
        LAUNCH_PLATFORM_ID
    )
    if definition == null:
        return false
    return definition.supply_constrained

Tests already access this autoload directly (`tests/gut/test_platform_system.gd:89`
etc.). New docstring cites this section.

## §EH-33 — retro_games.gd autoload dynamic-call cluster (MEDIUM)

`game/scripts/stores/retro_games.gd` carried five dynamic-call sites against
the `PlatformSystem` and `StoreCustomizationSystem` autoloads, plus two
unused `tree.root.get_node_or_null` helpers (`_has_platform_system` and
`_get_store_customization_system`):

1. `_connect_platform_shortage_signals` — `_has_platform_system()` short-
   circuit.
2. `_refresh_new_console_display_label` — `get_tree().root.get_node(...) +
   .call("get_definition", ...) + .get("display_name") + .call("is_shortage", ...)`.
3. `_on_poster_slot_interacted` — `customization.call("cycle_poster")`.
4. `_on_featured_display_interacted` — `customization.call("can_set_featured_category") + .call("cycle_featured_category")`.
5. `_connect_store_customization_signals` — `customization.connect(&"featured_category_changed", ...)`.

All five resolve to autoload identifiers (`PlatformSystem`,
`StoreCustomizationSystem`) with typed methods (`is_shortage`,
`get_definition`, `cycle_poster`, `can_set_featured_category`,
`cycle_featured_category`) and one owner-declared signal
(`featured_category_changed` at `store_customization_system.gd:30`).

Risk lens: **reliability**. The shortage-label / featured-category /
poster-cycle paths drive both player-visible UI (the
`new_console_display/ShortageLabel`, the in-store poster prop) and the
`display_exposes_weird_inventory` hidden-thread trigger. A silent skip
ships either a stale label or a missing hidden-thread event with no
diagnostic.

Action: replaced all five with direct typed autoload access. Both
helper functions were deleted as they had no other callers. The
`_connect_store_customization_signals` signal connect now uses the typed-
signal form (`StoreCustomizationSystem.featured_category_changed.connect(...)`)
mirroring the §EH-13 pattern.

Verified: no test fixture exercises the dynamic-call paths
(`grep _get_store_customization_system tests/` and `grep _has_platform_system tests/`
both return zero hits). The retro-games scene tests load the full autoload
tree, so direct access works.

## §EH-34 — retro_games_holds.gd autoload dead-guard cluster (MEDIUM)

`game/scripts/stores/retro_games_holds.gd` carried four parallel dynamic-
call sites against the `UnlockSystemSingleton`, `PlatformSystem`,
`ManagerRelationshipManager`, and `EmploymentSystem` autoloads:

1. `has_hold_terminal_access` — `tree.root.get_node_or_null("UnlockSystemSingleton") +
   .has_method("is_unlocked") + .call("is_unlocked", ...)`.
2. `is_item_supply_constrained` — `_has_platform_system() + .get_node("PlatformSystem") +
   .has_method("is_shortage") + .call("is_shortage", platform_id)`.
3. `_apply_manager_trust_delta` — `tree.root.get_node_or_null("ManagerRelationshipManager") +
   .has_method("apply_trust_delta") + .call("apply_trust_delta", ...)`.
4. `_apply_employee_trust_delta` — `tree.root.get_node_or_null("EmploymentSystem") +
   .has_method("apply_trust_delta") + .call("apply_trust_delta", ...)`.

All four targets are autoloads. All four called typed methods that exist:
`is_unlocked` (`unlock_system.gd:71`), `is_shortage` (`platform_system.gd:54`),
`apply_trust_delta` on both ManagerRelationshipManager
(`manager_relationship_manager.gd:132`) and EmploymentSystem
(`employment_system.gd:94`).

Risk lens: **data integrity / reliability**. `apply_trust_delta` is the
sole pipeline that flows the Fulfillment Conflict outcomes (HONOR_EARLIEST
→ +0.02 manager trust; ESCALATE_TO_MANAGER → +0.03 manager trust;
GIVE_TO_WALK_IN → -0.05 manager trust + -3.0 employee trust) into the
manager- and employment-relationship pipelines that drive ending evaluation
and Day-N notes. A silent skip on a method rename would have left the
player's choice with zero consequence — a class of bug previously surfaced
on the conflict-resolution path multiple times in playtesting.

`is_item_supply_constrained` is the conflict-detection rule; a silent
skip would fall through to the static `ItemDefinition.supply_constrained`
flag, masking live shortage state and producing the wrong CONFLICT-badge
gating for the Fulfillment Conflict terminal.

`has_hold_terminal_access` gates the entire Fulfillment Conflict UI. A
silent skip would silently lock the player out of the terminal even after
the `employee_holdlist_access` unlock is granted.

Action: replaced all four chains with direct typed autoload access (one
line per call site). The `_has_platform_system()` helper was deleted (no
remaining callers).

Verified: `test_retro_games_hold_list.gd::before_each` boots
`ManagerRelationshipManager.manager_trust` and
`EmploymentSystem.state.employee_trust` directly via the autoload
identifiers, so the typed calls in `_apply_manager_trust_delta` /
`_apply_employee_trust_delta` execute against the same autoloads the test
fixture is reading and resetting. Full GUT run unchanged (37 failing — same
pre-existing strip-to-bones leftovers documented in prior passes).

## §EH-20 — AudioEventHandler silent store-music/ambient fallbacks (MEDIUM, partially-justified-not-acted)

`game/autoload/audio_event_handler.gd::_play_store_music_for` and
`::_play_store_ambient_for` each carry three silent-fallback branches:

1. `not ContentRegistry.exists(store_id)` — unknown id. **Legitimate** fallback
   (the player exited a store and is in hallway).
2. `store_def == null` — registered id resolved to no StoreDefinition.
   **Content-authoring break** in theory.
3. `music_path.is_empty()` / `ambient_path.is_empty()` — definition has empty
   audio field. **Content-authoring break** in theory.

Initially branches 2 and 3 were escalated to `push_error`, since
`store_definitions.json` for `retro_games` has both fields populated and a
missing value would silently boot the store with hallway music. The
post-edit test run surfaced 94 hits from integration fixtures
(`compat_store`, `test_store`, `created_store`, `sports`) that construct
`StoreDefinition.new()` without setting `music` / `ambient_sound`. Critically,
`content_registry.gd::_validate_store` (lines 394–415) does **not** validate
those fields at boot, so the runtime fallback path is the only guard.

Risk lens: **reliability / observability**. The current `push_warning`
posture surfaces the diagnostic in `tests/test_run.log` and in operator
logs (Godot prints warnings to stderr) without breaking the CI `^ERROR:`
scan. A real production `retro_games` regression would still show up
loudly relative to the silent baseline.

Action: **kept at `push_warning` per §EH-10** with an in-line comment
naming the fixtures and explicitly noting that escalation to `push_error`
should happen iff `_validate_store` adds boot-time checks on the
`music` / `ambient_sound` fields. That follow-up belongs in a
ContentRegistry pass, not an error-handling pass — explicitly out of
scope here so we don't widen the surface.

## §EH-21 — ManagerRelationshipManager._tier_category_note silent fallbacks (MEDIUM, partially-acted)

`_tier_category_note(tier, category)` is the daily-note selector for
Day 2+ (`select_note_for_day` → `_tier_category_note`). Three silent-
fallback paths existed pre-pass:

1. `tier_block is not Dictionary` — the requested tier name is missing
   from `tier_notes`.
2. Both the requested `category` and the `operational` fallback are
   missing/empty inside the tier.
3. The randomly-picked candidate is malformed (non-Dictionary).

`_end_of_day_comment` (§F-147) already established the canonical split:
structural breaks fail loud, per-entry malformed warns. `_tier_category_note`
was missing the equivalent loud paths.

Risk lens: **observability / reliability**. Silent fallback would have
shipped Vic's daily commentary as an empty string for the rest of the
run; the player loses the only feedback channel about how the day went.

Action:
- Branch 1 → `push_warning` (test fixtures may inject partial dicts via
  `_set_notes_for_testing`; matches the §EH-10 pattern on
  `_end_of_day_comment`'s eod_block check).
- Branch 2 → `push_error` (content-authoring break — both candidate slots
  and the documented `operational` fallback are gone).
- Branch 3 → `push_warning` (single bad entry; the next random pick on
  the next call recovers, mirroring `_end_of_day_comment`'s line 463).

## §EH-22 — StoreDecorationBuilder unknown store_type fail-loud (MEDIUM)

`game/scripts/stores/store_decoration_builder.gd::build` carries a single
`match store_type` that only handles `"retro_games"`. After the
`strip-to-bones` refactor, every other store was removed; the default
arm previously emitted a `push_warning` and returned a decoration node
with no children.

Risk lens: **reliability**. The `store_type` value is sourced from
`StoreController.store_type` → `StoreDefinition.id`. A typo or rename
would silently ship a store with no posters / signs / planters — a
content-authoring break that's hard to diagnose from a screenshot.

Action: escalated `push_warning` → `push_error`. The fallback (empty
`Decorations` node) is preserved so the scene tree stays valid. No test
exercises the unknown-store_type path on this branch (verified by greps
for `_build_retro` / `StoreDecorationBuilder.build` in `tests/`).

## §EH-23 — HUD typed-controller access vs has_method (MEDIUM)

`hud.gd::_beta_close_day_allowed_quiet`, `::_beta_close_day_reason`, and
`::_beta_day_one_controller` all used `has_method(...) + call(...)` to
reach the `BetaDayOneController` (typed `class_name`, group-registered
in its own `_ready`). The dynamic-call seam was inconsistent: `hud.gd`
already imports the typed class via type annotations elsewhere.

Risk lens: **reliability**. The §EH-14 pattern (already removed in
`beta_day_one_controller.gd::_pause_time_for_end_day`) applies here:
`has_method` returns false on a rename, the HUD's "Close Day" gate
falls open even when the controller would have refused, and the player
can press F4 from any stage. A controller signature rename would have
silently shipped a broken early-close gate.

Action: replaced `has_method` + `call` with direct typed access on a
typed `BetaDayOneController` reference. `_beta_day_one_controller` now
returns `BetaDayOneController`, not `Node`. A signature rename now
fails GDScript parse instead of falling open. No tests reach the
fallback path (HUD tests use the typed controller via group registration).

## §EH-24 — InteractionRay direct InputFocus access (MEDIUM)

`interaction_ray.gd::_input_focus_blocks_interaction` previously walked
`tree.root.get_node_or_null("InputFocus")` and gated the dispatch on
`has_method("current")`. This was the §EH-15 pattern: the
`InputFocus` autoload is owner-declared in `project.godot:51`, the
`current()` method is owner-declared at `input_focus.gd:64`, and the
function already referenced `InputFocus.CTX_STORE_GAMEPLAY` directly —
which is itself a typed-autoload reference. The `_get_input_focus_node`
helper had no other callers.

Risk lens: **reliability**. The dual-path inconsistency is bug-shaped:
if the dynamic-call seam ever fell through (the autoload couldn't be
found by name), the gate would fall *open* (block_interaction = false),
letting modals' ray-trace fire through, while the same script would
parse-error on the direct `InputFocus.CTX_STORE_GAMEPLAY` access just
below.

Action: replaced the helper-driven dynamic call with a single direct
call to `InputFocus.current()`. The empty-context fallthrough is kept
(`if ctx == &""`) for unit-test isolation. The `_get_input_focus_node`
helper was deleted. A `current()` rename now fails GDScript parse.

## §EH-25 — BetaRunState.apply_decision_effect EconomySystem-null test seam (LOW, justified-not-acted)

`beta_run_state.gd::apply_decision_effect` mirrors a cash delta into
`EconomySystem` so the HUD's `get_cash()` pipeline stays the single
visible source of truth. The `if economy != null:` guard exists because
`tests/gut/test_beta_run_state_cash_delta.gd` calls the autoload directly
without a GameWorld in the tree (and so without EconomySystem). The
test exercises BetaRunState's own bookkeeping, not the EconomySystem
mirror.

Risk lens: **data integrity**. In production, both BetaRunState.cash
and EconomySystem.cash should track. The guard skipping the mirror
means a test could pass while shipping a divergence — but the test
guards the *BetaRunState side*, and the EconomySystem mirror is
exercised by separate integration tests (`test_beta_day_one_critical_path.gd`)
that build the full GameWorld.

Action: **kept the guard, added §EH-10-pattern annotation** citing the
test fixture and clarifying why escalation would break it. No behavior
change.

## §EH-26 — BetaDayOneController BetaRestockShelf wiring fail-loud (HIGH)

`beta_day_one_controller.gd::_spawn_visible_shelf_items(count)` spawns
the day's stock as box meshes on `BetaRestockShelf/ShelfBoard`. Two
pre-pass silent guards:

1. `_store_root() == null` — test fixture seam (no parent in unit tests).
2. `shelf == null or not (shelf is Node3D)` — `BetaRestockShelf` Node3D
   missing under the store root.

Branch 2 is a scene-wiring regression — `retro_games.tscn` ships the
`BetaRestockShelf` Node3D. Pre-pass, the function returned 0 silently,
and the caller's `EventBus.toast_requested.emit("Stocked %d games on
the used games shelf." % spawned)` then surfaced "Stocked 0 games on
the used games shelf" — a confusing player-visible bug with no
diagnostic.

Risk lens: **reliability / data integrity**. The on-shelves counter is
the visible feedback for the stocking objective; "Stocked 0" leaves
the player stuck on a chain that quietly never advances.

Action: branch 2 escalated to `push_error` + `return 0`. Branch 1 kept
silent per the documented test-fixture pattern. New docstring cites
this section.

## §EH-27 — BetaDayOneController customer-setup wiring fail-loud (HIGH)

`beta_day_one_controller.gd::_configure_beta_customer` wires up the
Day-1 register customer's visible silhouette and interaction trigger.
`::_resize_customer_trigger` runs after `Interactable._ready` reparents
the CollisionShape3D. Three pre-pass silent guards:

1. `not (customer_node_ref is Node3D)` — `BetaDayOneCustomer` Node3D
   missing under the store root (scene-wiring break).
2. `interactable_node == null` — customer has no `Interactable` child.
3. `collision == null` — `Interactable` has no `CollisionShape3D`
   descendant.

All three are scene-wiring regressions — `retro_games.tscn` authors all
three nodes for the beta. The pre-pass behavior shipped a customer
that either didn't render or had a 1.5 m default trigger box that
the screen-center ray flew over until the player was nose-to-chest.

Risk lens: **reliability**. The register customer is the player's
first interactive beat after stocking; if the trigger is unhittable
the chain stalls. The player has no error message and no way to know
why E does nothing at the register.

Action: all three escalated to `push_error` + `return`. The
`_store_root() == null` and `is_instance_valid(customer_node)` guards
stay silent — first is the unit-test seam, second handles the
`call_deferred` race where the customer was freed before the
deferred resize fires. New docstrings cite this section.

## §EH-28 — GameWorld._wire_save_manager dead autoload guards (MEDIUM)

`_wire_save_manager` previously did:

    var unlock_system: UnlockSystem = get_node_or_null("/root/UnlockSystemSingleton")
    if unlock_system:
        save_manager.set_unlock_system(unlock_system)

and the same for `OnboardingSystem`. Both are autoloads
(`project.godot:37, :39`); the `get_node_or_null + null check` is the
§EH-13 / §EH-15 dead-guard shape. A singleton rename / removal would
silently ship a SaveManager that omits unlock or onboarding data —
saves would persist without that scope and the regression would
surface only as "unlocks didn't restore."

Risk lens: **data integrity**. SaveManager's job is to persist run
state; missing one of the registered subsystems silently truncates
the save.

Action: replaced both pairs with direct typed access:

    save_manager.set_unlock_system(UnlockSystemSingleton)
    save_manager.set_onboarding_system(OnboardingSystemSingleton)

A singleton rename now fails GDScript parse. No tests reach the
fallback path (tests access `UnlockSystemSingleton.x` directly on the
autoload, not via `get_node_or_null`).

## §EH-29 — CheckoutSystem.customer_ready_to_purchase caller-bug fail-loud (MEDIUM)

`checkout_system.gd::_on_customer_ready_to_purchase(customer_data)`:

1. `cust_id == 0` — payload missing `customer_id` or zero.
2. `not node is Customer` — `instance_from_id(cust_id)` returned a
   non-Customer node.

Both are Customer-FSM caller-bug invariants: the Customer FSM only
emits this signal from `customer.gd::_build_customer_data` with
`get_instance_id()` on a typed Customer node. Pre-pass both used
silent `return`, which would hide an FSM regression as a queue
rejection UX bug.

The empty-dict test fixtures
(`test_objective_director.gd:203`, `:227`, `:358`, `:401` —
`EventBus.customer_ready_to_purchase.emit({})`) only reach
ObjectiveDirector (an autoload, always connected). CheckoutSystem is
scene-instantiated by GameWorld and is **not loaded in those tests**.
Escalation is safe.

Risk lens: **reliability**. A real FSM regression would silently lose
register-queue events — exactly the systemic class §EH-11 targeted.

Action: both branches escalated to `push_error` + `return`. New
function-header docstring documents the contract and cites this
section. Mirrors §EH-11.

## §EH-30 — RegisterStatusIndicator._controller test-seam annotation (LOW, justified-not-acted)

`game/scripts/beta/register_status_indicator.gd::_controller` returns
`null` in unit-test fixtures that don't add the controller to the
scene tree. Production beta path always group-registers the controller
in `BetaDayOneController._ready`. The caller (`get_disabled_reason`)
handles the null return by surfacing an empty string, which the HUD
treats as "no hint." This is the documented Interactable convention
and matches the parallel test seam at `hud.gd::_beta_day_one_controller`.

Risk lens: **observability**. The status hint disappears in test
isolation; production is unaffected.

Action: **kept silent, added annotation** citing this section and
the §EH-10 pattern. No behavior change.

## §EH-16 — DataLoader.create_starting_inventory fail-loud (HIGH)

`game/autoload/data_loader.gd::create_starting_inventory` is the single
entry point that builds the Day-1 backroom from `StoreDefinition.starting_inventory`.
It is called from `GameWorld._create_default_store_inventory` on store
entry — the Day-1 critical path. The function carries a §F-83 docstring
that explicitly states *"surfacing the cause… is required so a content-
authoring regression is caught in CI / playtest rather than masquerading
as 'the player has no items today'."*

Pre-pass: every failure branch returned `[]` with a `push_warning`. The
docstring's CI safety-net promise was inert because the CI stderr scan in
`.github/workflows/validate.yml:140` greps `^ERROR:`, not `^WARNING:`. The
four warning sites:

1. `not ContentRegistry.exists(store_id)` — caller passed a store id that
   isn't in the registry.
2. `canonical.is_empty()` — store id resolved to an empty canonical.
3. `get_store(canonical) == null` — canonical resolved but no
   `StoreDefinition` exists for it.
4. In-loop: `get_item(item_id) == null` — a typo in the
   `starting_inventory` array references a non-existent item.

Risk lens: **reliability**. Each of these is a content-authoring
regression. A single typo in `store_definitions.json` or a renamed item id
would silently shrink the Day-1 backroom; the player boots into an empty
backroom and the tutorial loop becomes unreachable. The only signal pre-
pass would have been a player report of "no items to stock."

Action: all four `push_warning` calls escalated to `push_error`. The `[]`
fallback / `continue` is preserved on every branch so the function still
returns a valid (possibly empty) typed array. Verified: no test fixture
passes a malformed store id to `create_starting_inventory`
(`tests/gut/test_new_game_state.gd` uses
`GameManager.DEFAULT_STARTING_STORE` and `ContentRegistry.get_all_ids("store")`
exclusively); the 8/8 tests in that file remain green.

## §EH-17 — EnvironmentManager warnings on intentional test seams (MEDIUM, justified-not-acted)

`game/autoload/environment_manager.gd::swap_environment` carries two
`push_warning`-and-return paths:

1. `_resolve_zone(zone_id).is_empty()` — the requested zone isn't in
   ContentRegistry, hallway constant, or `FALLBACK_ZONE_IDS`.
2. `_resolve_environment_id(resolved).is_empty()` — zone resolved but
   there's no `PRELOADED_ENVIRONMENTS` entry and no
   `FALLBACK_ENVIRONMENT_IDS` entry.

On first inspection these look like content-authoring breaks that should
be `push_error`. However, multiple integration tests deliberately exercise
both paths via the autoload connection at line 28 (`EventBus.store_entered.connect(_on_store_entered)`):

- `tests/integration/test_npc_spawn_pipeline.gd` emits `store_entered.emit(&"test_npc_store")` six times.
- `tests/integration/test_customer_npc_lifecycle.gd` emits `store_entered.emit(&"test_store")` six times.
- `tests/unit/test_camera_manager.gd::test_store_entered_unknown_store_does_not_change_camera` emits `store_entered.emit(&"unknown_store")` to verify the camera-manager null-default contract.
- `tests/unit/test_queue_system.gd` emits `store_exited.emit(&"test_store")` three times.

These fixtures rely on the silent-fallback contract (stay in current
environment) so they can exercise downstream subscribers in isolation
without authoring a real env_*.tres resource per fixture. Escalating to
`push_error` would fail CI on tests that exercise the contract on purpose.

Action: **kept at `push_warning` per §EH-10**. Updated the in-line
comments at both branches to (a) name the test categories that exercise
each path, (b) explicitly cite the §EH-10 pattern, and (c) document why
escalation is incorrect. The warnings stay diagnosable in the test-run log
without breaking CI's stderr scan.

## §EH-18 — CheckoutSystem.initiate_sale rejection contract (MEDIUM, justified-not-acted)

`game/scripts/systems/checkout_system.gd::initiate_sale` rejects null
customer / item and zero-or-negative agreed_price by setting `_is_processing = false`
and returning. In production these branches are unreachable (the typed
sale path always supplies non-null typed references and a positive price),
but `tests/gut/test_checkout_system.gd::test_initiate_sale_rejects_null_customer`
(line 322) and `::test_initiate_sale_rejects_zero_price` (line 331)
deliberately call the function with bad inputs and assert
`_is_processing == false`. These tests document the rejection contract.

Action: **kept at `push_warning` per §EH-10**. New docstring at the
function head names both tests, explains the contract, and cites this
section. Both paths were briefly escalated to `push_error` during this
pass, but the change broke the two intentionally-exercised tests'
compliance with the CI `^ERROR:` allowlist; reverted.

## §EH-19 — CheckoutSystem panel-not-set wiring fail-loud (MEDIUM)

`_show_checkout_panel` (line ~286) and `_on_negotiation_started` (line ~503)
both check `if not _checkout_panel:` / `if not _haggle_panel:` before
operating on the panel. These panels are set by
`GameWorld._initialize_tier_3_operational` (`game_world.gd:467` and `:473`)
during the playable-world init tier; reaching either guarded branch in
production means the wiring regressed.

Pre-pass: `push_warning` and silent return. The customer would sit idle at
the register or lock in a haggle state with no UI, the day clock would
keep ticking, and the only signal would be a player-visible "register
stalls forever" UX bug.

Risk lens: **reliability**. Both panels are non-optional production
wiring; a regression silently disables the checkout UI for the entire
session. No test exercises either path (verified: zero hits for "no
checkout panel assigned" / "no haggle panel assigned" in
`tests/test_run.log`).

Action: both `push_warning` calls escalated to `push_error`. The fallback
(silent return) is preserved so the customer state machine doesn't crash;
the only effect is that CI now fails on a wiring regression instead of
shipping a broken register.

## §EH-12 — BetaDayOneController shipped-content load failures (HIGH)

`game/scripts/beta/beta_day_one_controller.gd::_load_json` is the single
entry point that reads `customer_events.json`, `day_01.json`, and
`day_02.json` from `res://game/content/beta/`. The dictionary it returns
flows into `_load_content` → `_events_by_day` → `_start_day` → the
DAY1_EVENT_ID `wrong_console_parent` decision card.

Pre-pass: every failure branch silently returned `{}`:

1. `not FileAccess.file_exists(path)` — file missing on disk.
2. `FileAccess.open(...) == null` — file present but unreadable
   (permissions, locked, I/O error).
3. `JSON.parse_string(...) == null` — file present and readable but the
   contents are not valid JSON.

Risk lens: **reliability / observability**. A corrupt
`customer_events.json` (a stray comma, a half-edited string literal from a
patch, a UTF-8-BOM regression from a Windows editor) would have shipped
as "Day 1 has no customer at the register." The tutorial chain would have
appeared frozen on `STAGE_TALK_TO_CUSTOMER` with no diagnostic, no toast,
and no log line — the only signal would be a player report that the
register customer never appears.

Action: case 2 (open-fail) and case 3 (parse-fail) escalated to
`push_error` with the offending path and the FileAccess error code.
Case 1 (missing) downgraded to `push_warning` so a future
`day_02.json`-stripped placeholder doesn't fail CI. The `{}` fallback is
preserved on every branch so the chain still flows (no events shows up
as an empty `_day_events` array — the player still gets a playable
back-room → stock → close-day loop, just without the customer beat).

Verified: no test fixture passes a corrupt or missing `customer_events.json`
(grep `_load_json`, `customer_events.json`, `day_01.json`, `day_02.json`
under `tests/` — zero hits in beta-controller test paths). The Day-1
critical-path test loads `retro_games.tscn` with the real shipped content
and passes after this edit.

## §EH-13 — Dead `EventBus.has_signal` guards in beta subsystem (MEDIUM)

Three sites in the beta subsystem (and one in `moments_tray.gd`) wrapped
calls to `EventBus.beta_objective_completed.emit(...)`,
`EventBus.day_started.connect(...)`, and `EventBus.day_ended.connect(...)`
with `if EventBus.has_signal("...")` guards:

- `beta_day_one_controller.gd::on_beta_day_end_requested` (close_day emit)
- `beta_day_one_controller.gd::_complete_current_objective`
  (per-objective emit)
- `beta_today_checklist.gd::_ready` (subscribe to
  `beta_objective_completed` and `day_started`)
- `moments_tray.gd::_ready` (subscribe to `day_started` and `day_ended`)

All four signals are owner-declared on the autoload `EventBus`
(`event_bus.gd:29`, `:31`, `:664`). The autoload itself is registered in
`project.godot:50` and is guaranteed to be present at the moment any
script's `_ready()` runs.

Risk lens: **reliability / observability**. The guard does nothing useful
in production (the signal is always present), but it actively hurts the
maintenance posture: a rename or accidental removal of the signal would
silently skip the connect / emit, leaving the today checklist stuck
showing yesterday's bullets, the moments tray's daily reset broken, and
the beta-day-1 chain advancing without telling subscribers. The
regression would surface only as an end-user UX bug well after merge.

Action: removed all four guards. Signal renames now fail at GDScript parse
time on the EventBus side (the parser catches `EventBus.beta_objective_completed`
when the symbol is gone). New comments at each site cite this section so
future readers understand why the guard was removed rather than
re-introducing it as "defensive."

## §EH-14 — Dead `has_method` guard in `_pause_time_for_end_day` (MEDIUM)

`beta_day_one_controller.gd::_pause_time_for_end_day` previously read:

    if time_sys.has_method("set_speed"):
        time_sys.call("set_speed", TimeSystem.SpeedTier.PAUSED)

`TimeSystem` is the typed autoload `class_name TimeSystem` declared at
`time_system.gd`; `set_speed(tier: SpeedTier)` is a public method at
`time_system.gd:163`. The dynamic-call seam exists for no contract
reason — the surrounding code already typed `time_sys: TimeSystem`.

Risk lens: **reliability**. If `set_speed` were ever renamed,
`has_method` would return false and the function would silently skip the
pause, causing `TimeSystem._end_day()` to fire as the clock crosses 17:00
and slamming the player straight to the day-summary screen before they
could press E on the close-day trigger — exactly the bug the
function's docstring (and §F-FIX1 historical note) was written to
prevent.

Action: replaced the `has_method` + `call` pair with a direct
`time_sys.set_speed(TimeSystem.SpeedTier.PAUSED)`. A signature change now
fails parse instead of silently regressing the time gate.

## §EH-15 — Dead `InputFocus != null and has_signal` guards (MEDIUM)

`modal_dim_overlay.gd::_ready` and `toast_notification_ui.gd::_ready` both
guarded their `InputFocus.context_changed.connect(...)` call with:

    if InputFocus != null and InputFocus.has_signal("context_changed"):
        InputFocus.context_changed.connect(...)

`InputFocus` is registered as an autoload in `project.godot:51`. Autoloads
cannot be null at script `_ready()` time; the engine instantiates them
before any non-autoload script runs. The signal `context_changed(new_ctx,
old_ctx)` is declared at `input_focus.gd:15`.

Risk lens: **reliability**. The two consumers are the foundation of the
modal-fade contract: the dim overlay above gameplay and the toast
modal-suppression. If either guard ever short-circuited (unreachable in
practice, but the structure invites bug-shaped thinking), modals would
render without dimming and toasts would slide in over open modals. A
signal rename would silently disable both behaviors with no diagnostic.

Action: removed both guards. Each site now connects unconditionally and
the in-line comment cites this section. Verified by running
`test_modal_dim_overlay`, `test_toast_modal_suppression`, and
`test_toast_layer_z_order` — all green.

## §1 — ObjectiveDirector content validation (HIGH)

`game/autoload/objective_director.gd` parses `res://game/content/objectives.json` at autoload time and feeds the Day-1 step chain that drives the entire first-time-player tutorial rail.

Pre-pass severity: `push_warning` for four content-authoring regressions:

1. Non-Dictionary entry inside `steps` (line 105 pre-pass)
2. Non-Array `steps` field (line 113 pre-pass)
3. Day 1 `steps` count != `DAY1_STEP_COUNT` (line 124 pre-pass)
4. Non-Dictionary `pre_step` field (line 145 pre-pass)

Risk lens: **reliability**. Each of these conditions silently disables the Day-1 step chain (`_day1_steps_available()` returns false) or, in the `pre_step` case, leaves the rail blank between `day_started` and the first `manager_note_dismissed`. The rail is the player's only on-screen tutorial guide on Day 1. A typo in `objectives.json` would have shipped a broken first-day experience whose only signal was a `WARNING:` line that no CI job parsed.

Action: escalated all four sites to `push_error`. The CI `gut-tests` job greps `^ERROR:` on stderr and fails the build on unrecognized push_error output (`.github/workflows/validate.yml` lines ~118–135). The default fallback (rail falls back to pre-sale / post-sale text) is preserved so production never crashes — but a regression now fails CI rather than shipping. No test exercises these malformed-input paths, so the change does not destabilize the existing suite.

## §2 — GameWorld player-bounds metadata (HIGH)

`game/scenes/world/game_world.gd::_apply_marker_bounds_override` (lines 1086–1102 post-pass) reads `bounds_min` / `bounds_max` metadata from the `PlayerEntrySpawn` marker on each store scene to clamp the walking player's reachable footprint.

Pre-pass severity: `push_warning` per side when the metadata key was present but the value was not a `Vector3`.

Risk lens: **data integrity / safety**. The method comment already documented the consequence: *"Falling silently through to the default footprint can let the player walk through walls in a store whose interior is smaller than the default bounds."* This is a content-authoring bug with player-visible exploit potential (clipping into geometry, escaping into out-of-bounds rendering). The author had already escalated from a fully silent fallback to a warning; this pass takes it the rest of the way to an error so CI catches the regression at build time.

Action: both `push_warning` calls escalated to `push_error`. The default footprint is still applied so the store remains playable. `null` (key absent) remains the documented opt-out and stays silent. No test passes wrong-type bounds metadata, so this is safe against the existing suite.

## §3 — InventoryPanel row-builder UI invariant (HIGH)

`game/scenes/ui/inventory_panel.gd::_on_remove_from_shelf` (lines 529–546 post-pass) is the click handler for the per-row Remove button. The button is gated upstream by `inventory_row_builder.add_remove_button`, which only attaches it when `item.current_location.begins_with("shelf:")`.

Pre-pass severity: `push_warning` when the handler ran for a non-shelf item.

Risk lens: **observability / data integrity**. Reaching this branch means the row-builder gating regressed and a click was offered for an item that lives in the backroom (or worse, has empty/malformed location). The handler refused to do anything, so a player would see "no response on click" — a well-known frustration vector and an extremely hard-to-diagnose production bug if it ever shipped.

Action: escalated to `push_error`. `test_inventory_panel.gd` exercises the normal shelf-removal flow with `current_location = "shelf:..."`, so the new error path is never hit by the test suite. A row-builder regression that re-introduced the bad gating would now fail CI immediately.

## §4 — RegisterInteractable Customer-FSM invariant (HIGH)

`game/scripts/components/register_interactable.gd::_fire_quick_sale` (lines 75–90 post-pass) handles the Day-1 single-press checkout. By the time it runs, `_pending_customer` has been set from `EventBus.customer_ready_to_purchase`, which the Customer FSM only emits when `_desired_item` is resolved.

Pre-pass severity: `push_warning` when the arrived customer had no desired item / definition.

Risk lens: **reliability**. This is a Customer-FSM invariant break: a customer cannot legitimately reach the register without a desired item under the documented protocol. A warning here would have allowed a broken FSM transition to ship as a "queue rejection" UX bug rather than the systemic state-machine fault it actually is.

Action: escalated to `push_error`. The fallback (`customer.reject_from_queue()`) is preserved so the queue self-recovers. The existing test suite always builds the customer with a valid `_desired_item`, so the new error path is never exercised by tests.

## §5 — Unchecked `signal.connect()` calls (NOTE)

Across the in-scope files, ~30 `signal.connect(...)` calls do not capture or check the returned error code. Examples: `event_bus.gd:919`, `objective_director.gd:55–67`, `interaction_ray.gd:44–46`, `interaction_prompt.gd:42–49`, `day_cycle_controller.gd:43–47`.

Risk lens: **observability**. In Godot 4, `Signal.connect()` returns `OK` on success and an error code on duplicate / invalid target / disconnected receiver. The idiomatic project pattern (consistent across the autoload roster) is to call `.connect()` without capturing the result, relying on `is_connected()` guards in the few places where double-connect is plausible (e.g. `close_day_confirmation_panel.gd:30`, `interaction_ray.gd:215`).

Decision: **justify, do not act**. Wrapping every `connect()` in a checked path would invert the project's idiom and add ~50 nearly-identical guard branches. The signal infrastructure (`EventBus` autoload) is itself authored once and well-tested, so the connect-time failure modes that warrant per-call hardening are already covered by the `is_connected` guards at the rare double-subscribe sites. Recommend revisiting only if a future incident traces back to a missing connection.

## §6 — Test-seam silent returns (LOW)

The following silent-return patterns are documented test seams and are kept as-is. Each carries an existing `§F-XX` reference at the call site that this pass leaves intact:

- `objective_director.gd:316–319` (§F-98) — Day-1 step state-machine race-guard.
- `objective_director.gd:336–338` (§F-99) — `tree == null` test seam mirrors §F-44 / §F-54.
- `game_world.gd:858–862` (§F-55) — silent return on GAME_OVER is intentional.
- `game_world.gd:872–875` (§F-105) — same GAME_OVER terminal-state guard.
- `game_world.gd:980–983` (§F-39) — `as Node3D` cast guard.
- `game_world.gd:1110–1114` (§F-46) — silent return when no `PlayerController` child exists.
- `game_world.gd:1195–1201` (§F-90) — Tier-2 init pattern for `store_state_manager`.
- `inventory_panel.gd:389–391` (§F-104) — null `_filter_row` test seam.
- `inventory_panel.gd:574–577` (§F-104) — null `SceneTree` test seam.
- `inventory_panel.gd:586–595` (§F-96) — empty `slot_id` rejection.
- `interaction_ray.gd:299` (§F-53) — dead-prompt audit reference.
- `interaction_ray.gd:359–366` (§F-108) — debug-build telemetry gate.
- `interaction_prompt.gd:131–137` (§F-44) — null-`InputFocus` test seam.
- `morning_note_panel.gd:138–143` / `:156–159` (§F-136) — `GameState` / autoload fallback.
- `day_cycle_controller.gd:141–145` and `:148–152` — `ObjectiveDirector` autoload fail-open documented in the function header (lines 137–140).

These all share the same shape: production runtime always provides the system being checked; bare-Node unit-test fixtures hit the silent path; the fallback (default value, no-op, generic copy) is the documented behavior.

## §7 — `has_method` dynamic-call seams (LOW)

Seven sites (`inventory_panel.gd:761`, `game_world.gd:149`, `day_cycle_controller.gd:145/152/186`, `morning_note_panel.gd:157`, `register_interactable.gd:102`) call `obj.has_method(...)` before `obj.call(...)`. These are deliberate decoupling between autoload and scene scripts — the typed import would create a circular dependency between the autoload roster and the scene tree.

Decision: **justify, do not act**. The pattern is consistent across the codebase and the call sites are stable; signature drift would be caught by GDScript's parser at edit time on the implementing class. No hardening warranted.

## §8 — `input_focus.gd` stack-depth leak (NOTE)

`game/autoload/input_focus.gd:127–133` warns (rather than errors) when the post-transition stack depth is greater than 1 — an upstream scene leaked a `push_context` without matching `pop`. The function header explicitly justifies this:

> A depth >1 post-transition means the prior scene leaked a push and is reported as a non-fatal warning so the leaking call site can be found.

The case for keeping a warning: the topmost frame still gates input correctly, so gameplay continues. Empty stack is the fatal case (`_fail` calls `push_error` + AuditLog.fail_check + ErrorBanner). Depth=1 is healthy; depth>1 is "diagnose me." The current split between fail (empty) and warn (over-deep) is correct.

Decision: **justify, do not act**. Keep the warning; the existing `MAX_STACK_DEPTH=8` assert in `push_context` is the hard cap.

## §EH-09 — HUD CloseDayPreview missing (HIGH)

`game/scenes/ui/hud.gd::_open_close_day_preview` (lines 318–326 post-pass) is
the click handler for the in-store HUD's "Close Day" button. The intended path
opens the `CloseDayPreview` modal so the player can review the day before
committing; the modal owns the `EventBus.day_close_requested` emit. The
fallback path emits the signal directly (the day still closes) but the modal
is gone.

Pre-pass: the function docstring already read *"the wiring regression is
logged so CI catches it"* — but the call used `push_warning`, which the CI
stderr scan in `.github/workflows/validate.yml` (`grep "^ERROR:"`) does not
match. The promised CI safety net was inert.

Risk lens: **reliability / observability**. `hud.tscn` ships with a
`CloseDayPreview` child; reaching the fallback means the scene was
edited without the modal. The day-close still works, but the player loses
the dry-run preview UX entirely — a silent UX regression that this pass
escalates to a CI failure.

Action: escalated `push_warning` → `push_error` and updated the docstring
to reference this section. No tests exercise the missing-preview path
(verified via grep: `_open_close_day_preview`, `CloseDayPreview child
missing`, `HUD._close_day_preview` — zero hits in `tests/`).

## §EH-10 — InventoryPanel empty store_id (MEDIUM, justified-not-acted)

`game/scenes/ui/inventory_panel.gd::_refresh_grid` (lines 349–365 post-pass)
is the panel-refresh entry point. The Day-1 contract (ISSUE-001) wires
`active_store_changed` so by the time the panel can be opened, GameManager
has an active store. Hitting the empty-`store_id` branch is a regression of
that wiring.

The docstring at this site reads similarly to §EH-09 — *"surface it loudly
so it shows up in CI rather than silently degrading to an empty panel"* —
which on initial read suggests a `push_error` escalation. **However**,
`tests/gut/test_inventory_panel.gd::test_refresh_with_empty_store_id_falls_back_safely`
deliberately sets `panel.store_id = ""` and asserts the graceful "No active
store" fallback rendering. Escalating to `push_error` would fail CI on a
test that exercises the contract on purpose.

Action: **kept at `push_warning`**, updated the comment to (a) name the
test that exercises this branch, (b) explain why escalation is incorrect,
and (c) cite this section. The docstring's "shows up in CI" wording now
accurately means "appears in CI logs as a warning, not as a build failure."

## §EH-11 — CustomerSystem despawn caller-bug invariants (HIGH)

`game/scripts/systems/customer_system.gd::despawn_customer` (lines 345–362
post-pass) is the sole path that removes a customer from `_active_customers`
and increments `_leave_counts`. Its two upfront guards — `customer_node ==
null` and the `as Customer` cast — are caller-bug invariants. The function
is wired through `_on_customer_despawn_requested(customer: Customer)` (a
typed signal handler) and through internal timeout-cleanup paths that all
hold typed `Customer` references. No test fixture passes `null` or a non-
`Customer` node (verified: zero hits for `despawn_customer(null` or non-
`Customer` despawn calls under `tests/`).

Pre-pass: both guards used `push_warning` and silently returned. A real
caller bug would have:
1. Skipped the `_active_customers.erase(customer)` accounting → leaked
   reference, biased `get_active_customer_count`.
2. Skipped `_increment_leave_count` → undercounted day-summary "failed
   customer" buckets.
3. Skipped the `customer_left` signal → downstream subscribers
   (reputation, performance reports) lose an event.

Risk lens: **reliability / data integrity**. Not security or auth, but a
silent count drift that would show up only as "the day-summary numbers
look off" — exactly the hard-to-diagnose production bug class this audit
targets.

Action: replaced both `push_warning` calls with `push_error` and added a
shared block comment at the function head citing this section. The fallback
behavior (silent return) is preserved so the customer state machine self-
recovers; only the diagnostic level changes.

## Escalations

One follow-up that belongs in a different pass:

- **§EH-20 boot-time validation for StoreDefinition audio fields**.
  `content_registry.gd::_validate_store` (lines 394–415) validates
  `scene_path`, `inventory_type`, `interaction_set_id`, and
  `tutorial_context_id` at boot, but **not** `music` or `ambient_sound`.
  As a result, the runtime fallback in `audio_event_handler.gd` is the
  only check, which forced this pass to keep those branches at
  `push_warning` rather than `push_error` (otherwise integration
  fixtures that emit `store_entered` with sentinel store_ids would
  fail CI). The smallest concrete next action is to add four lines to
  `_validate_store` that mirror the existing field checks, plus updating
  the test fixtures (`compat_store`, `test_store`, `created_store`,
  `sports`) to set non-empty placeholder paths. That's a ContentRegistry
  / fixture-hygiene pass, not an error-handling pass. **Who unblocks:**
  whoever owns content-validation policy on this branch. **Smallest
  next action:** open an issue titled "ContentRegistry: validate
  StoreDefinition.music / .ambient_sound at boot" referencing §EH-20.

All other findings were either acted on (§§1–4, §§EH-09 / EH-11,
§§EH-12 – §EH-38), or explicitly justified-not-escalated with
test-bound rationale (§§EH-10 / EH-17 / EH-18 / EH-20 / EH-25 / EH-30),
or justified at the call site (§§5–8). The prior-pass "Escalations"
follow-up — removing the dead `if InputFocus != null:` connect-time
guards in `objective_rail.gd:74`, `crosshair.gd:24`, and
`interaction_prompt.gd:48` — was completed in the §EH-15 follow-up
table earlier in this report.

Surveyed-and-deferred this pass (2026-05-11 §EH-38):

- The §EH-38 sweep ranged across the ownership-autoload consumer
  surface (FailCard, SceneRouter, StoreRegistry, CameraManager) for
  the §EH-13/§EH-15 dead-guard shape. 9 sites in 4 files were
  converted to direct typed-autoload access. The §EH-31 latent
  silent-bug shape was caught and fixed in
  `store_registry.gd::_seed_from_content_registry`. Three site
  clusters remained justified-not-acted:
  - **`store_director.gd::_audit_pass` / `::_audit_fail`** —
    `set_audit_for_tests` injection seam is load-bearing for
    `test_store_director.gd`. The `has_method` guard tolerates
    test-mock variants. Converting would widen the test-fixture
    implementation cost.
  - **`hold_shelf_interactable.gd::_resolve_suspicious_slip_count`** —
    scene-content dynamic-call seam (parent `holds` property), not
    autoload dead-guard.
  - **`day1_readiness_audit.gd`** — same prior-pass deferral remains;
    the "partial-report-on-missing-subsystem" contract makes the
    §EH-31 fix shape a behavior change.

Surveyed-and-deferred prior pass (2026-05-11 §§EH-35 – §EH-37):

- The prior-pass "Smallest next action" — `rg "has_method\(\"[a-z_]+\"\)" game/`,
  extract method names, cross-reference against `class_name`-typed
  autoloads — was executed. The 27-site sweep surfaced two real
  §EH-31-class silent bugs (§EH-35 in `shift_system.gd`, §EH-36 in
  `random_event_system.gd`) and one cleanly-convertible dead-guard
  cluster (§EH-37 in `day_cycle_controller.gd`), all acted on this
  pass. The remaining 23 sites were classified into three categories:
  - Documented test seams with `§F-XX` annotations (left as-is).
  - Stub-tolerance guards in scene-instantiated systems with externally-
    injected fields (`trade_in_system.gd`, `store_customization_system.gd`)
    — converting these would force test fixtures to implement every
    method on every stub. Left as-is.
  - One wider-rewrite candidate: `day1_readiness_audit.gd` has ~5
    sites that are §EH-31-shape against real autoloads, but the file's
    "partial-report-on-missing-system" contract means a conversion has
    a non-trivial behavior change. **Smallest next action:** open a
    follow-up issue titled "Day1ReadinessAudit: convert dead `has_method`
    guards to typed-autoload calls" and decide whether the report should
    fail loud on a missing method (the §EH-31 fix) or continue producing
    partial reports.

Prior-pass "Surveyed-and-deferred" follow-up (preserved for history):

- `retro_games_holds.gd` callers of `_apply_manager_trust_delta` /
  `_apply_employee_trust_delta` already had no test seam to preserve
  (the test fixture mutates the autoloads directly in `before_each`).
  The §EH-34 escalation was therefore safe to ship without a
  follow-up. If a future autoload-rename ever needs the dynamic-call
  seam back for a deliberate test reason, it should be reintroduced
  with a §EH-10-style annotation citing the specific test.
