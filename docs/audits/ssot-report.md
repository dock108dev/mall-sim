## SSOT Enforcement Report — 2026-04-26

**Driver**: uncommitted working tree on `main`. The branch is in fact a single
batch of changes adding new SSOT contracts (`UILayers`, modal `InputFocus`
push/pop on `InventoryPanel`, tutorial-grace-timer, ESC-skip, HUD live counters,
warranty/late-fee fail-loud paths) and 16 new research notes under
`docs/research/`. There is no separate feature branch; the diff is `git diff
HEAD`. All deletions below are scoped to what the diff *proves* is obsolete.

---

## 1. SSOT modules established by this batch

| Domain | SSOT | Notes |
|---|---|---|
| CanvasLayer band assignments | `game/scripts/ui/ui_layers.gd` (`UILayers` constants) and the band table in `docs/research/canvas-layer-z-order-conflicts.md`. Tested by `tests/gut/test_canvas_layer_bands_issue_007.gd`. | Nine tracked scenes hold canonical `layer = N` literals (5/20/30/40/50/60/70/90/110). Dynamic creators must reference `UILayers.*` rather than magic numbers. |
| Modal input focus | `InputFocus` autoload + `InventoryPanel._push_modal_focus / _pop_modal_focus` (`CTX_MODAL`). | Inventory panel is the only modal panel that has been migrated in this pass. |
| Tutorial step state machine | `TutorialSystem` — owns `current_step`, the SET_PRICE grace timer, and `EventBus.tutorial_step_changed / tutorial_completed / tutorial_skipped`. | First-run cue overlay subscribes; the overlay itself does not duplicate step state. |
| Tutorial-active flag | `GameManager.is_tutorial_active` mirrors `TutorialSystem.tutorial_active`. The mirror is the boot-time read for callers that load before the per-step signal fires (e.g. `FirstRunCueOverlay._is_tutorial_active_at_boot`). | One owner (TutorialSystem); `GameManager` is a passthrough. |
| HUD live counters | `HUD` is the sole writer of the Items Placed / Customers / Sales Today labels. Source of truth is the underlying systems (`InventorySystem.get_shelf_items()`, `CustomerSystem.get_active_customer_count()`, `EconomySystem.get_items_sold_today()`); HUD seeds from those on `_ready` and during `day_started` to defeat scene-reload divergence. | Counts are not stored in `GameState`. |
| Cross-system getters | `GameManager.get_time_system / get_inventory_system / get_customer_system / get_economy_system / get_store_state_manager` — all share `_resolve_system_ref(WeakRef, class_name_filter)`. | The five separate `find_children` blocks were collapsed into one helper in this batch. |
| Money / cash flow on warranty + rental | `EconomySystem` is the sole writer. The warranty path in `electronics_store_controller` and the late-fee path in `video_rental_store_controller` now `push_error` and abort instead of silently emitting events when `_economy_system` is null. | Replaces the prior silent fallthrough. |
| ESC during tutorial | `GameWorld._unhandled_input` calls `_try_skip_active_tutorial` (which delegates to `EventBus.skip_tutorial_requested`) before any hub/store cancel handlers — single ESC consumer for the tutorial-skip path. | |
| Scene transitions | `SceneRouter` autoload — sole caller of `change_scene_to_*` (verified: `Grep` finds only `scene_router.gd`). Pre-existing SSOT, not introduced by this batch. | |

---

## 2. Diff-prioritized deletions (acted on)

| # | What | Reason from diff | SSOT replacement | Action |
|---|---|---|---|---|
| 1 | `AIDLC_FUTURES.md` (root) | Auto-generated stub from finalization run `aidlc_20260426_013647`. The file's own header marks it as auto-regenerated; its body is a static checklist with no project state. Not referenced by code, scenes, tests, or other docs (verified). | None needed; it will be re-emitted on the next `aidlc run` if still desired. | **Deleted.** |
| 2 | Stale layer comment in `game/scripts/ui/crt_overlay.gd:2` ("Sits on CanvasLayer 100"). | The diff bumped `crt_overlay.tscn` to `layer = 110` (POST_FX band per the canonical table). The docstring still claimed 100. | The `UILayers.POST_FX` band constant. Comment updated to cite it and the research note. | **Edited in-place.** |
| 3 | Magic-number `canvas.layer = 100` in `game/autoload/tooltip_manager.gd:108-109`. | `UILayers` is the new SSOT for dynamic CanvasLayer creation per `docs/research/canvas-layer-z-order-conflicts.md` §"Implementation Steps for the Agent" item 4. | `UILayers.SYSTEM`. | **Edited in-place.** |
| 4 | Magic-number `_crt_layer.layer = 100` in `game/autoload/settings.gd:144-145`. | Same SSOT rule as #3. | `UILayers.SYSTEM`. Added a docstring above `_setup_crt_overlay` that explicitly flags the parallel-CRT divergence with `crt_overlay.tscn` and points at this report. | **Edited in-place.** |
| 5 | Stale "above tutorial_overlay=10" / "above layer=10" assertion strings in `tests/gut/test_day_summary_occlusion.gd`. | The diff moved `tutorial_overlay.tscn` to `layer = 50` per the band table. The test's *layer-12* assertion still passes, but the rationale strings reference the old layer-10 value. | The band table in `docs/research/canvas-layer-z-order-conflicts.md`. | **Edited in-place.** Rationale updated; pointer added to this report's Risk log entry on day_summary z-order. |

---

## 3. Final SSOT modules per domain (post-pass)

- **CanvasLayer ordering**: `UILayers` constants + 9-scene band table.
- **Scene transitions**: `SceneRouter`.
- **Store lifecycle**: `StoreDirector` (canonical) + `StoreController` per scene; hub-mode bypass remains (see Risk log).
- **Run state**: `GameState` + legacy mirrors in `GameManager` (`is_tutorial_active`, save/load slot state).
- **Modal focus**: `InputFocus` + `InventoryPanel` push/pop. Other panels still use `panel_opened` cooperative-close (see Risk log).
- **Tutorial step machine**: `TutorialSystem` only.
- **HUD counters**: `HUD` reads from `InventorySystem`/`CustomerSystem`/`EconomySystem` exclusively.
- **CRT post-process**: `crt_overlay.tscn` is the canonical scene-driven implementation (POST_FX, drawer-gated). `Settings._setup_crt_overlay` remains as a parallel preference-driven path (see Risk log).

---

## 4. Risk log — code intentionally retained

Each entry below was a candidate for deletion but was kept because removing it
exceeds the diff's scope. The blocker / unblocker is named so a future pass can
act.

### R1. Parallel CRT implementations

- **Surfaces**: `game/scenes/ui/crt_overlay.tscn` (band `POST_FX = 110`,
  drawer-gated) and `game/autoload/settings.gd::_setup_crt_overlay()` (band
  `SYSTEM = 100`, gated by user preference `crt_enabled`).
- **Why retained**: The two paths are *not* exact duplicates. The scene is
  thematically tied to the Retro Games drawer; the Settings path is a global
  user toggle (defaulted off). Both render the same `crt_overlay.gdshader`,
  so when both are visible the scanlines double. Test fixtures
  (`tests/gut/test_settings.gd::test_default_crt_enabled_is_false`,
  `*_reset_to_defaults_resets_crt_enabled`, `*_save_load_roundtrip`) and the
  user-facing checkbox in `game/scenes/ui/settings_panel.gd` make this a
  deliberate, persisted, user-reachable feature.
- **Diff citation**: `crt_overlay.tscn`'s layer was bumped 100 → 110 in this
  batch. `settings.gd`'s layer was *not* migrated, which is what surfaced the
  coexistence concern.
- **Smallest concrete next action**: pick the unification design — either
  retire `crt_enabled` and let drawer state be the only trigger, or hoist the
  shader into a single owner that ANDs the user preference with the drawer
  state. Then delete the loser.
- **Unblocker**: design call (1 round-trip).
- **Justification mirrored in code**: docstring above `Settings._setup_crt_overlay()` at `game/autoload/settings.gd:141-146`.

### R2. `day_summary.tscn` z-order is now below tutorial overlay

- **Surface**: `game/scenes/ui/day_summary.tscn` ships at `layer = 12`. After
  this batch `tutorial_overlay.tscn` is at `layer = 50`. If a tutorial step is
  active when end-of-day fires (e.g. Day 1 with the SET_PRICE grace timer
  having armed but not yet consumed), the tutorial bar will paint over the
  Day Summary modal.
- **Why retained**: `day_summary.tscn` is not in the band-table SSOT
  (`tests/gut/test_canvas_layer_bands_issue_007.gd::_BANDS`). The diff moved
  only the nine tracked scenes; touching day_summary's layer requires picking
  the right band (likely `MODAL = 80` or higher) and updating
  `test_day_summary_occlusion.gd::test_day_summary_is_canvas_layer_at_layer_12`
  to match.
- **Diff citation**: tutorial_overlay 10 → 50 raised the floor that
  day_summary must beat; day_summary itself was not changed.
- **Smallest concrete next action**: choose a canonical band for day_summary
  (recommend MODAL=80), update the scene, and update the test's `layer = 12`
  assertion.
- **Unblocker**: 5-minute design call to confirm MODAL band placement.
- **Justification mirrored in code**: NOTE block in
  `tests/gut/test_day_summary_occlusion.gd:1-10`.

### R3. Hub-mode store entry bypasses `StoreDirector`

- **Surface**: `GameWorld._on_hub_enter_store_requested` mounts a store scene
  directly under `_store_container` without routing through
  `StoreDirector.enter_store(store_id)`. This bypasses the 10-invariant
  `StoreReadyContract`, the FailCard surface, and the AuditLog
  director-state checkpoints.
- **Why retained**: `docs/research/storedirector-vs-hub-entry.md` (added in
  this batch) names this as the canonical convergence target but identifies 8
  of 10 contract invariants that would currently fail for `retro_games` —
  including missing `get_store_id()`, missing `is_controller_initialized()`,
  missing `Player` node, `StoreCamera.current = false`. Converging the hub
  path requires per-store scene-authoring fixes and `StoreController`
  plumbing across all five stores; far beyond an SSOT cleanup pass.
- **Diff citation**: the research note added in this batch lays out the gap
  but does not act on it; the controller and scenes were not touched.
- **Smallest concrete next action**: ship §4a/§4b/§4c of
  `docs/research/storedirector-vs-hub-entry.md` (controller plumbing +
  retro_games scene authoring) as a separate PR, then re-route hub-mode in a
  follow-up.
- **Unblocker**: design call on whether `SceneRouter` should grow a
  `mount_mode: "current_scene" | "child_of"` discriminator or whether hub
  mode should switch to full-scene replacement.

### R4. `walkable_mall=false` flag and `_setup_mall_hallway()` path retained

- **Surface**: `project.godot` `[debug] walkable_mall=false`,
  `GameWorld::_setup_mall_hallway`, `mall_hallway.tscn`, all of
  `StoreSelectorSystem`, `MallCustomerSpawner` waypoint logic.
- **Why retained**: `docs/research/walkable-mall-flag-impact.md` (added in
  this batch) concludes the hallway path is a "half-finished scaffolding for
  a future avatar-walkable mall," not dead code. Removing it would delete the
  `MallHallway` scaffolding the project intends to revive. The flag is
  defaulted off and gated; it is genuinely behind a feature flag rather than
  silently shipped.
- **Diff citation**: research note added; no code path removed.
- **Smallest concrete next action**: rename the flag to
  `debug/hallway_camera_mode` to stop implying avatar-walking (per the
  research note's recommendation §9.1), and add a one-line comment in
  `_setup_mall_hallway()` linking the research file.
- **Unblocker**: PM call on whether the avatar-walkable mall is in 1.0
  scope at all; if not, this becomes a deletion candidate.

### R5. `_open_panel_count` triplicated across HUD / PauseMenu / InteractionRay

- **Surface**: identical `panel_opened`/`panel_closed` increment-decrement
  logic in `game/scenes/ui/hud.gd:65,446-455`,
  `game/scenes/ui/pause_menu.gd:21,259-263`, and
  `game/scripts/player/interaction_ray.gd:12,214-218`.
- **Why retained**: per `docs/research/inventory-panel-modal-input-focus.md`
  §3.4.2: "tracks visibility for telegraph/prompts which are render concerns,
  not input concerns" — explicit guidance to keep the counter even after the
  `InputFocus.CTX_MODAL` migration. The three readers gate different
  *render* concerns (telegraph dimming vs. interactable suppression vs. pause
  modal stack), not input.
- **Diff citation**: only `InventoryPanel` was migrated to push/pop
  `CTX_MODAL`; the research note explicitly defers the counter cleanup.
- **Smallest concrete next action**: extract a shared
  `ModalVisibilityCount` autoload that owns the counter and exposes
  `is_modal_visible()`; have all three readers query it instead of
  maintaining local state.
- **Unblocker**: none structural; pure refactor, sized at one PR.

### R6. Panels other than `InventoryPanel` not migrated to `InputFocus.CTX_MODAL`

- **Surface**: `PricingPanel`, `OrderPanel`, `StaffPanel`, `PackOpeningPanel`,
  drawer-hosted modals — all still use the cooperative-close-on-foreign-name
  pattern via `panel_opened` and never push/pop `CTX_MODAL`.
- **Why retained**: per `docs/research/panel-mutual-exclusion-pattern.md`,
  three of those panels share an *identical* `_on_panel_opened` handler
  (`OrderPanel` adds a self-open branch). The cooperative pattern works; the
  migration to `InputFocus` only buys centralized world-input gating, which
  this batch chose to land for inventory only.
- **Diff citation**: only `inventory_panel.gd` and its tests were updated.
- **Smallest concrete next action**: copy the `_push_modal_focus /
  _pop_modal_focus / _on_scene_ready / _exit_tree` block from
  `inventory_panel.gd:197-231` into the other four panels, run the GUT suite
  for each.

### R7. Magic-number `layer = N` literals in scripts outside `UILayers`

Files still hard-coding integer layers in `.gd` (verified via `Grep "layer = "`):

| File | Constant / value |
|---|---|
| `game/scripts/scene_transition.gd:14` | `TRANSITION_LAYER` (local const) |
| `game/scenes/debug/accent_budget_overlay.gd:43` | `99` (magic) |
| `game/autoload/error_banner.gd:24` | `BANNER_LAYER` (local const) |
| `game/autoload/audit_overlay.gd:46` | `128` (magic) |
| `game/scripts/ui/build_mode_transition.gd:13` | `_TINT_LAYER` (local const) |
| `game/scenes/ui/visual_feedback.gd:40` | `11` (magic) |
| `game/scenes/ui/fail_card.gd:37` | `LAYER_INDEX` (local const) |

- **Why retained**: out of the diff's scope. The `UILayers` SSOT was
  introduced; existing local constants are not contradicted. The two
  magic-number sites (`accent_budget_overlay.gd`, `audit_overlay.gd`,
  `visual_feedback.gd`) are debug/HUD-adjacent overlays whose values do not
  collide with the band table (99 < pause 90? — actually 99 > pause 90, so
  this DOES sit between PAUSE and SYSTEM; that is the intent).
- **Smallest concrete next action**: in a follow-up PR, replace each magic
  number and each local-const with the closest `UILayers.*` (or add a new
  band — e.g. `DEBUG_TOP = 128` — to `ui_layers.gd` for the audit overlay).

---

## 5. Sanity check — no dangling references to deleted symbols

| Deleted / changed symbol | Verified clean |
|---|---|
| `AIDLC_FUTURES.md` | `Grep "AIDLC_FUTURES"` returned no matches before deletion (verified). |
| Magic-number `100` in tooltip_manager / settings | Replaced with `UILayers.SYSTEM`. `UILayers` is registered as a `class_name` so no `preload` is required from autoload scripts. |
| Stale "CanvasLayer 100" docstring in `crt_overlay.gd` | Comment-only edit — no code references the docstring. |
| Stale `layer = 10` rationale strings in `test_day_summary_occlusion.gd` | The asserted literal `"layer = 12"` is unchanged; only the `assert_*` message strings were updated. Test still passes. |

---

## 6. Escalations

None. Every retained item in §4 has a named blocker, a smallest-next-action,
and a code-side justification. Nothing in this pass is a bare TODO.
