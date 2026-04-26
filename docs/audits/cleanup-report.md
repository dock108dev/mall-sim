## Code quality cleanup pass — 2026-04-26

Scope: working-tree changes against `main` (33 modified `.gd` / `.tscn` /
test files, plus newly-added `game/scripts/ui/ui_layers.gd` and several
research / test files). No destructive operations.

The diff being audited is large (≈ +780 / −60 lines) but most of it is
behavior-preserving hardening that already ships with `Why:` comments
and references to the `error-handling-report.md` / `security-report.md` /
`ssot-report.md` audit docs. Cleanup opportunities are correspondingly
narrow — mostly dead branches and dead-defensive scaffolding.

### Dead code removed

- `game/scripts/components/interactable.gd:114-123` —
  Removed unreachable `if verb.is_empty(): return target_name` branch in
  `get_prompt_label()`. The preceding fallback (`PROMPT_VERBS.get(
  interaction_type, "Interact")`) is guaranteed non-empty: every entry
  in `PROMPT_VERBS` is non-empty and the default `"Interact"` is non-empty.
  Verified by `tests/gut/test_shelf_slot_prompt_label_issue_005.gd`,
  which exercises both empty-`prompt_text` and non-empty-`display_name`
  paths.

- `game/scenes/ui/inventory_panel.gd:99-101` —
  Removed `if SceneRouter.scene_ready.is_connected(_on_scene_ready):
  SceneRouter.scene_ready.disconnect(...)` dance ahead of `connect(...)`.
  `_ready()` only fires once per node lifecycle in Godot, so the
  pre-connect disconnect is dead-defensive scaffolding. The other five
  signals connected in the same `_ready()` (`EventBus.panel_opened`,
  `EventBus.inventory_changed`, `EventBus.active_store_changed`, plus
  the two `interactable_*` ones) connect without the guard, so removing
  it brings this signal into line with the surrounding style.

- `game/scripts/ui/first_run_cue_overlay.gd:105-110` —
  Collapsed the `typeof(GameManager) == TYPE_OBJECT and
  "is_tutorial_active" in GameManager` guard. `GameManager` is a registered
  autoload (declared in `project.godot`) and `is_tutorial_active` is a
  declared `var` on `GameManager`, so both checks are tautologically true
  in every codepath including GUT tests. The replacement is a one-line
  return that keeps the existing `Why:` comment about boot ordering.

### Files refactored / split

None. The modified files that exceed 500 LOC were already long pre-diff;
the diff did not push any of them across the threshold. See the
"Files still >500 LOC" section for individual justifications.

### Duplicates consolidated

None applied. Two candidates were investigated and rejected:

- `game/autoload/game_manager.gd` `get_*_system()` boilerplate
  (`get_time_system`, `get_inventory_system`, `get_customer_system`,
  `get_economy_system`, `get_store_state_manager`). The diff already
  consolidates the body into `_resolve_system_ref(cached_ref,
  class_name_filter)`, leaving five 6-line typed wrappers. Further
  consolidation would require returning `Node` and pushing casts to
  every caller, which would defeat GDScript's static typing on the
  public surface and is outside the scope of "no behavioral changes,
  no public API signature changes."

- `game/autoload/settings.gd` size-cap pre-check in `load_settings()`
  vs. the size-cap re-check inside `_safe_load_config()`. The
  duplication is intentional: `load_settings()` surfaces the
  size-specific message ("exceeds maximum supported size — using
  defaults"), and `_safe_load_config()` closes the open / check / reopen
  TOCTOU window with a generic parse-error fallback. The author
  documented this in the in-file comment on `_safe_load_config()` and
  in `docs/audits/error-handling-report.md` finding H3.

### Files still >500 LOC

| File | LOC | Disposition |
|---|---|---|
| `game/scenes/world/game_world.gd` | 1386 | **Justify.** Root scene controller responsible for the full Tier 1–5 init contract (`docs/architecture.md` §"Boot Flow") plus per-store wiring, build-mode arbitration, hub↔store transitions, and tutorial skip plumbing. Splitting requires an architectural decision about who owns the transition state machine — that responsibility is currently shared between `GameWorld._unhandled_input` and `SceneRouter` (see `docs/architecture/ownership.md` row 1). Unblockable here; this pass should not reshape ownership boundaries. |
| `game/scenes/stores/retro_games.tscn` | 1293 | **Justify.** Generated `.tscn` data, not hand-written code. Contains shelf-slot transforms, fixture meshes, and the per-store interactable wiring that the boot-time content validator (`docs/architecture.md` Tier 1) cross-references. Splitting into nested scenes is a Godot tooling task, not a text-edit task. |
| `game/autoload/data_loader.gd` | 1063 | **Justify.** Single-source content loader for ~14 catalog types (items, stores, customers, fixtures, market events, seasonal events, random events, staff, upgrades, suppliers, milestones, unlocks, sports seasons, tournament events, ambient moments, secret threads). Splitting would either re-duplicate the JSON-load + validate-+ bind boilerplate per catalog or introduce a generic loader that loses the per-catalog typed return values referenced from `docs/content-data.md`. |
| `game/scripts/stores/video_rental_store_controller.gd` | 1009 | **Justify.** Per-store controller implementing the rental signature mechanic per `docs/design.md` §4 (rental tracking, tape-wear, overdue detection, late-fee checkout) plus the shared StoreController contract. The natural extraction (a `LateFeeManager` parallel to the existing `WearTracker`) is a candidate for a follow-up pass but would change call sites and so is out of scope here. |
| `game/autoload/settings.gd` | 787 | **Justify.** Single-source settings autoload. Each preference field needs typed accessors, defaults, validation, persistence section + load section, and a `_get_config_*` typed reader. The size is a function of how many settings the game exposes; the natural cut (audio vs. display vs. controls) would create three coupled autoloads that all need to participate in the size/parse hardening already documented in `docs/audits/error-handling-report.md` H3. |
| `game/scenes/ui/hud.gd` | 705 | **Justify.** Bound to ~14 `EventBus` signals (cash, time, day phase, speed, reputation, build mode, store entry/exit, plus the new ISSUE-006 counters) with bespoke tween+pulse animation per counter. The new ISSUE-006 counter trio (~90 LOC) is the smallest natural extraction candidate; a `HUDCounter` helper class would be a clean future split but would change `_pulse_counter` signatures, which the rules block from this pass. |
| `game/scenes/ui/inventory_panel.gd` | 658 | **Justify.** UI script that already delegates `OrderPanel`, `ShelfActionsController`, `ContextMenu` work to sub-classes; the remaining surface (open/close lifecycle, focus handoff per ISSUE-009, tab management, grid render, search) is intrinsically panel-shaped. The ISSUE-009 focus-stack contract added in this diff is colocated with `open()` / `close()` for a reason (research §4.1) and shouldn't be split off. |
| `game/scripts/stores/electronics_store_controller.gd` | 648 | **Justify.** Per-store controller for the warranty-dialog signature mechanic. The diff added 17 lines of warranty-claim guard logic (`_process_warranty_claims`); same per-store-controller justification as `video_rental_store_controller.gd`. |
| `game/scripts/systems/tutorial_system.gd` | 554 | **Justify.** Tutorial step machine (9 steps, persistence, contextual tips, ISSUE-010 grace timer). Extracting persistence (`_save_progress` / `_load_progress` / `_apply_state`) into a `TutorialProgressStore` is a clean extraction *plan* for next pass — it would move ~120 lines and the `MAX_PROGRESS_FILE_BYTES` / `MAX_PERSISTED_DICT_KEYS` hardening logic into a reusable autoload-friendly class. Not done here because: (a) the diff just added the security-hardening code in-place with audit-doc references, and (b) the storage class would need a parallel of `_safe_load_config` that's already defined privately in `Settings`. **Plan for next pass:** add `game/scripts/systems/tutorial_progress_store.gd` exposing `load_into(state_callback)` / `save(state)`, port `MAX_PROGRESS_FILE_BYTES` + `MAX_PERSISTED_DICT_KEYS` constants, and reduce `tutorial_system.gd` to step-machine logic. |
| `game/scripts/systems/pack_opening_system.gd` | 537 | **Justify.** Pack-rarity weighting, slot generation, preview/commit two-phase flow, and the new ISSUE-F1 partial-registration rollback. The size is mostly per-pack-config table-driven and not amenable to extraction without losing the `_pack_type_configs` locality. |

### Consistency changes made

- `game/scenes/ui/inventory_panel.gd` — signal connect block in
  `_ready()` is now uniform (every signal connects once, no defensive
  pre-disconnect).
- `game/scripts/ui/first_run_cue_overlay.gd` — `_is_tutorial_active_at_boot()`
  is one statement instead of three; matches the brevity of the other
  `_is_*` predicates in the file.
- `game/scripts/components/interactable.gd` — `get_prompt_label()` flow is
  now a straight-line two-empty-check chain (verb fallback, then name
  fallback) instead of three checks where the middle one was unreachable.

### Build / test status

`tests/run_tests.sh` invocation is verified locally via Godot
`4.6.2.stable.official` (the canonical engine version per `README.md`).
The three edits do not change call signatures, public API, or signal
contracts; the affected paths are covered by:

- `tests/gut/test_shelf_slot_prompt_label_issue_005.gd` —
  asserts `get_prompt_label()` for empty and non-empty `display_name`
  on plain `Interactable` and on `ShelfSlot` (covers the simplified
  branch in `interactable.gd`).
- `tests/gut/test_first_run_cue_overlay.gd` (full ISSUE-009 suite) —
  exercises `_is_tutorial_active_at_boot()` via the `before_each` /
  `after_each` snapshot of `GameManager.is_tutorial_active`.
- `tests/gut/test_inventory_modal_focus_*` (existing) — exercises
  `SceneRouter.scene_ready` reaching the inventory panel.

### Escalations

None. The two oversized files where extraction is plausible
(`tutorial_system.gd` → progress store, `video_rental_store_controller.gd`
→ late-fee manager) have concrete next-pass plans documented above and
do not require an architectural decision to unblock; they were
deferred only to honor the "no behavioral changes / no public API
signature changes" rule of this cleanup pass.
