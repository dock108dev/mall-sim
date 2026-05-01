# SSOT Enforcement Report — 2026-05-01

**Pass scope.** Working-tree changes vs HEAD (no `main`-vs-feature diff
available — all delta is uncommitted). The branch direction is set by
`BRAINDUMP.md`: make the Day 1 Retro Games store playable, hide UI fields with
no live source, and consolidate scattered close-day / placement / camera
controls into single owners.

The diff itself already performs most of the SSOT enforcement (HUD scene
restructure, day-close preview wiring, placement hint signal, fixture
collision in player controller). This pass adds the *destructive* tail of
that work: deleting placeholder asset scenes that the diff has just orphaned,
and recording the SSOT contracts the diff established so they don't drift.

---

## Changes made this pass

### Deleted files (production-orphan placeholder scenes)

The retro_games scene moved from `[ext_resource] placeholder_fixture_*` to
inline `BoxMesh`/`MeshInstance3D` geometry (visible in the
`game/scenes/stores/retro_games.tscn` diff: `placeholder_fixture_shelf_standard.tscn`
ext_resource removed; counter/register meshes inlined as new sub_resources).
That made the placeholder fixture and environment scenes orphan. Production
grep across `*.tscn` shows zero remaining consumers; the only references were
in a single test, so the test was scoped down (see below).

| Path | Reason |
|---|---|
| `game/assets/models/fixtures/placeholder_fixture_shelf_standard.tscn` | Was the only diff-removed fixture (retro_games dropped its `[ext_resource id="15"]`). No other store referenced it. |
| `game/assets/models/fixtures/placeholder_fixture_counter_checkout.tscn` | Never referenced by any production scene in git history (`git log -S` returns nothing). Pure orphan, surfaced by the move-to-inline-geometry style this branch establishes. |
| `game/assets/models/fixtures/placeholder_fixture_counter_display.tscn` | Same — zero production references in history. |
| `game/assets/models/fixtures/placeholder_fixture_kiosk_stand.tscn` | Same. |
| `game/assets/models/env/placeholder_env_storefront_entrance.tscn` | Only consumer was the test below. Production storefronts use inline geometry. |
| `game/assets/models/env/placeholder_env_mall_hallway.tscn` | Zero consumers anywhere. |

### Edited files

| Path | Change |
|---|---|
| `tests/gut/test_placeholder_environment_materials.gd` | Removed `test_placeholder_scenes_apply_textured_material_resources` plus the `_assert_scene_uses_material` and `_scene_uses_material` helpers it owned. The two remaining tests (`test_required_placeholder_textures_exist_and_use_supported_sizes`, `test_textured_materials_reference_required_albedo_maps`) still verify that the texture PNGs exist and that the textured material resources reference the right albedo maps — those textures and materials *are* still consumed by production stores. |

Test result after edits: `4802/4802 GUT tests pass` (verified with
`bash tests/run_tests.sh`). The pre-existing `validate_issue_239.sh`
failures (PocketCreatures content shape, tournaments count) reproduce on
clean HEAD via `git stash`-and-replay; they are not caused by this pass.

---

## SSOT contracts established by the working-tree diff

For each domain the branch touches, here is the single canonical owner the
diff has installed. These are the contracts that future PRs must respect or
break with a CLAUDE.md update.

| # | Domain | SSOT (single owner) | Forbidden patterns |
|---|---|---|---|
| 1 | **Day-close from in-store HUD** | `CloseDayPreview.show_preview()` modal — dry-run sim revealed event-by-event, then `_on_confirm_pressed` is the *only* path that emits `EventBus.day_close_requested`. The HUD's `_open_close_day_preview()` (`game/scenes/ui/hud.gd:238`) is the sole entry, used by both the Close Day button and the Escape-key handler. | Direct `EventBus.day_close_requested.emit()` from any in-store UI surface. The HEAD code emitted from two paths in `hud.gd`; both have been routed through the modal. The `mall_overview.gd:383` direct emit is *not* an in-store path and is intentionally kept (justified below — the preview's shelf-snapshot UX has no payload from mall view). |
| 2 | **Placement-mode hint banner** | `PlacementHintUI` (`game/scripts/ui/placement_hint_ui.gd`) listens to `EventBus.placement_hint_requested(item_name)` and `EventBus.placement_mode_exited`. The signal is emitted exclusively by `InventoryShelfActions.enter_placement_mode(item)` (`game/scripts/ui/inventory_shelf_actions.gd:13`). | Other UI listening to `placement_mode_entered` and rendering its own placement copy. `InteractionPrompt` is suppressed by `CTX_MODAL` during placement, so it cannot be the surface; PlacementHintUI is the dedicated banner that survives that gap. |
| 3 | **MALL_OVERVIEW cash display** | The hub's KPI strip (`game/scenes/mall/mall_overview.gd`) is canonical. The HUD's `_cash_label` is *forced hidden* in `MALL_OVERVIEW` state (`hud.gd:312`, with the explicit comment "KPI strip is the canonical cash display"). | Any addition to the HUD that re-enables `_cash_label.visible = true` in MALL_OVERVIEW. The legacy "$0.00$0" duplicate render artefact came from both labels rendering at once; the diff fixes it by deferring to the hub strip. |
| 4 | **Fixture-collision blocking during pivot movement** | `PlayerController._pivot_blocked()` (`game/scripts/player/player_controller.gd:336-357`) is the sole gate. `_resolve_pivot_step` slides Z-then-X around blockers, then refuses the move. Public `resolve_pivot_step` wrapper exists *only* for the GUT collision test (`tests/gut/test_player_controller_fixture_collision.gd`). | Other callers writing to `_target_pivot` directly without going through `_resolve_pivot_step`. The diff's `_apply_keyboard_movement` now routes through the resolver — earlier code clamped to bounds without checking fixture overlap. |
| 5 | **Orthographic camera mode** | `PlayerController.is_orthographic` (export, default `false`) — when set on the per-store player scene (only `retro_games.tscn` does, line 286), the controller switches to `PROJECTION_ORTHOGONAL`, suppresses right-click orbit and middle-click pan, and routes scroll-wheel to `ortho_size_*`. | Other code paths flipping `Camera3D.projection` directly. The orthographic camera grammar is the merge-blocker called out in `docs/style/visual-grammar.md` ("reinvented camera controller"). |
| 6 | **Day Summary "Return to Mall" routing** | `DaySummary._on_mall_overview_pressed` (`game/scenes/ui/day_summary.gd:824`) emits `mall_overview_requested`, handled by `GameWorld._on_day_summary_mall_overview_requested` (`game/scenes/world/game_world.gd:832`) which routes to `GameManager.State.MALL_OVERVIEW`. The wages/milestone/save side-effects still run via `next_day_confirmed.emit()` first, mirroring `_on_continue_pressed`. | A second button or path that bypasses `next_day_confirmed` and short-circuits straight to MALL_OVERVIEW — that would skip wage payouts and save persistence. The `GAME_OVER` early return is documented as `§F-55`. |
| 7 | **Retro Games checkout-counter prompt state** | `RetroGames._refresh_checkout_prompt()` (`game/scripts/stores/retro_games.gd:325`) reads `EventBus.queue_advanced(size)` and toggles between "No customer waiting" (idle, no prompt verb) and "Checkout Counter — Press E to checkout customer" (active). | Any other emitter of register-queue size to the checkout prompt. `queue_advanced` is the single source of queue truth. |
| 8 | **Day 1 quarantine surface** | `RetroGames._apply_day1_quarantine()` (`game/scripts/stores/retro_games.gd`) hides `refurb_bench` only on Day 1 non-debug builds. `testing_station` is intentionally *not* in the list — it ships with its `Interactable` disabled, and its visual zone (`crt_demo_area`: CRT prop, neon panels, "Coming Soon" Label3D) stays visible as a parked feature. | Re-introducing `testing_station` to the quarantine loop. The `for node_name in ["refurb_bench"]:` shape was collapsed to a direct `get_node_or_null("refurb_bench")` per the prior cleanup pass (`docs/audits/cleanup-report.md`). |
| 9 | **MALL_OVERVIEW optional buttons** | `MallOverview._refresh_optional_button_visibility()` (`game/scenes/mall/mall_overview.gd:307`) is the only method that toggles the Moments Log and Completion buttons. Buttons appear only when their target panel has real content (witnessed moments / progressed criteria). Performance is always visible — kept on the BRAINDUMP "for now" list. | UI surfaces that re-enable those buttons unconditionally — the BRAINDUMP-cited "Dead UI makes the game feel fake" rule. |

---

## Risk log — items left in place with rationale (act-or-justify)

### J-1. `EventBus.day_close_requested.emit()` direct call in `mall_overview.gd:383`

**Decision:** keep.

**Why:** `CloseDayPreview` shows a per-store shelf snapshot dry-run. Mall hub
view has no specific store under it — the preview UX (shelf-by-shelf reveal)
has no payload from this surface and would render "0 items on the shelf, no
customers today" misleadingly. The mall-hub close button has its own Day-1
gate (`first_sale_complete` flag check at `mall_overview.gd:374-381`) which
mirrors the HUD's gate. The two surfaces gate the same way; only the
in-store path runs the preview.

**How a future change would invalidate this:** if `CloseDayPreview` is
generalized to render an aggregated all-stores snapshot, the mall hub close
button should also route through it. Until then, two surfaces emit the
signal, but with the same gate.

### J-2. `_format_thousands` duplicated in `mall_overview.gd:340` and `store_slot_card.gd:106`

**Decision:** keep both copies.

**Why:** Two ~9-line copies of a number-grouping helper. Extracting to a
shared utility would create coupling between an autoload-style overview and
a per-card UI script for an int formatter. The cleanup pass
(`docs/audits/cleanup-report.md` finding #5) already resolved a similar
"three short lines is better than premature abstraction" call for
`inventory_panel.gd`. Same reasoning here.

**How a future change would invalidate this:** a third or fourth call site
appears, at which point a `UIThemeConstants.format_thousands(int)` helper
becomes the obvious owner.

### J-3. `_seasonal_event_label` and `_telegraph_card` in `hud.gd`

**Decision:** keep.

**Why:** Explore agent's first pass flagged these as "completely dead, never
written." Verified false. Both are written by `_refresh_telegraph_card()`
(line 691) and `_refresh_seasonal_event_display()` (line 716) when the
underlying seasonal/random-event signals fire. They are *forced hidden in
current state matchers* (MALL_OVERVIEW + STORE_VIEW set `.visible = false`)
because Day-1 BRAINDUMP says hide telegraphed-event UI until it has live
content. The signal handlers re-show the labels when an event actually
telegraphs. That is the correct quarantine: not dead code, just gated by
content existence.

**How a future change would invalidate this:** if the seasonal event system
itself is removed, the labels and their refresh methods can come out
together.

### J-4. Pre-existing `validate_issue_239.sh` failures

**Decision:** keep, not in scope.

**Why:** PocketCreatures `packs.json` shape and tournament-count failures
reproduce on clean `HEAD` (verified via `git stash` + replay). They are not
caused by this pass and predate the working-tree changes.

---

## Sanity check — no dangling references

After the deletions, re-scanned the tree:

- `git grep placeholder_fixture_shelf_standard` → `tests/gut/test_placeholder_environment_materials.gd` no longer matches (helper removed).
- `git grep placeholder_fixture_counter_checkout` → 0 hits.
- `git grep placeholder_fixture_counter_display` → 0 hits.
- `git grep placeholder_fixture_kiosk_stand` → 0 hits.
- `git grep placeholder_env_storefront_entrance` → 0 hits.
- `git grep placeholder_env_mall_hallway` → 0 hits.
- `bash tests/run_tests.sh` → `4802/4802` GUT tests pass; only the
  pre-existing `validate_issue_239.sh` failures remain (unrelated).

---

## Escalations

### §E-SSOT-1. `HintOverlayUI` has no production consumer

**File:** `game/scripts/ui/hint_overlay_ui.gd`, `game/scenes/ui/hint_overlay_ui.tscn`.

**Smallest concrete next action:** decide whether the `OnboardingSystem`
autoload (`game/autoload/onboarding_system.gd`) is meant to surface hints in
production at all. `OnboardingSystem` is autoloaded in `project.godot:39`
and emits `EventBus.onboarding_hint_shown`. That signal has zero production
consumers — `HintOverlayUI` is referenced only by its own tests and by the
`tests/integration/test_onboarding_day1_flow.gd` scaffolding, never wired
into `game_world.tscn` or any HUD scene. The new `PlacementHintUI` is a
*different* feature (placement-mode banner, not onboarding toast), so this
is not a diff-proven supersede.

**Why not act in this pass:** removing `HintOverlayUI` cleanly requires
either (a) deleting the entire onboarding subsystem (autoload, signal,
config JSON, integration test, GUT tests — much larger scope than a single
SSOT pass should touch), or (b) wiring `HintOverlayUI` into a production
scene to make the autoload's output observable. That's a product decision
("does Day 1 ship with onboarding hints?"), not a refactor. Owner needs to
pick a direction before the SSOT pass can close it.

**Who unblocks it:** the player-onboarding owner. A 5-minute decision
(ship-with-hints or rip-the-system) unblocks a ~30-line follow-up PR.

### §E-SSOT-2. `prop_counter_register.gltf` orphan

**File:** `game/assets/models/fixtures/prop_counter_register.gltf` (+ `.import`).

**Smallest concrete next action:** check with the asset author (file is dated
2026-04-25, more recent than the placeholders) whether it was imported for
imminent use in the retro_games register prop or is leftover spike. If
spike, delete; if planned, wire it into `retro_games.tscn` register node
behind a TODO with a date.

**Why not act in this pass:** a 4-day-old asset import is more likely
in-progress work than legacy chaff. Deleting it without checking would
overwrite the user's in-progress work — exactly the failure mode the
project's "investigate before deleting" rule forbids.

---

## What was *not* changed (and why)

To make the act-or-justify ledger explicit:

1. **HUD `_speed_button`** — kept connected with `pressed.connect(_on_speed_button_pressed)`
   even though `.visible` is `false` in both real states. The button is
   parked behind GAMEPLAY-state visibility and not part of the Day 1 HUD per
   BRAINDUMP. Disconnecting and reconnecting on state change costs more than
   the unused signal binding. The `_on_speed_button_pressed` early-return
   gates execution to GAMEPLAY only, so dead emits cannot fire.

2. **HUD `_customers_label` / `_reputation_label` write paths** — still wired
   to `customer_entered`/`customer_left`/`reputation_changed`. The labels
   are hidden in STORE_VIEW per the diff but still consumed in
   MALL_OVERVIEW (`hud.gd:324` explicitly re-enables `_reputation_label`).
   Disconnecting the writer would leave MALL_OVERVIEW reading stale text —
   the visible-vs-update split is intentional.

3. **`game/scripts/ui/inventory_shelf_actions.gd::enter_placement_mode(null)`
   fallback** — kept. The cleanup-report (#3) and error-handling-report
   (EH-02) both document this is an intentional optional-arg path for
   tests/legacy callers; PlacementHintUI's empty-string default prompt is
   the documented contract, not a missing log.

4. **Other stores' `is_orthographic` default** — kept `false`. Only
   retro_games sets it true (the Day-1 store). The other stores'
   visual-grammar pass is downstream work and not in this branch's scope.
