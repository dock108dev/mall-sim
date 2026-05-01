# Code Quality Cleanup Report — 2026-04-27

---

## Pass 2 — 2026-04-27

### Dead Code Removed

**`game/scenes/ui/hud.gd`** — `_has_modal_open()` + panel-count tracking chain
`_has_modal_open()` was defined but never called anywhere in the codebase (confirmed via full
repo grep). With the reader gone, the entire write side became dead: `_open_panel_count: int`,
the `EventBus.panel_opened` / `panel_closed` connections in `_ready()`, and the two
`_on_panel_opened_track` / `_on_panel_closed_track` handlers were all writing a counter
that nothing consumed. Removed all five artifacts. The `panel_opened` / `panel_closed` signals
themselves remain active — other systems (inventory, pricing, tutorial, etc.) still subscribe.
Net: −12 lines.

**`game/autoload/data_loader.gd:686–687`** — `get_item_definition()` alias
Wrapper that forwarded to `get_item()`. Every caller in the codebase uses
`ContentRegistry.get_item_definition()` instead; the `DataLoader` version was
never invoked outside its own definition. Removed.

**`game/autoload/data_loader.gd:734–735`** — `get_store_definition()` alias
Same pattern as above. All callers (`audio_event_handler.gd`,
`npc_spawner_system.gd`, tests) use `ContentRegistry.get_store_definition()`.
Removed.

**`game/autoload/data_loader.gd:679`** — section comment updated
`# --- Public getters (backward-compatible API) ---` → `# --- Public getters ---`
With both backward-compat aliases removed, the "backward-compatible" claim was
no longer accurate.

### Comments — Stale ISSUE References Stripped

ISSUE-XXX references in code comments rot because they point to closed tickets
whose decisions are baked into the code. The text that matters is the WHY; the
issue number is metadata that belongs only in commit messages and PR descriptions.
The following locations had ISSUE prefixes stripped while preserving all
behavioral context:

| File | Location | Change |
|---|---|---|
| `game/scenes/ui/hud.gd` | `_on_objective_text_changed` docstring | Removed `ISSUE-017:` prefix |
| `game/scenes/ui/hud.gd` | `_seed_counters_from_systems` docstring | Removed `ISSUE-006:` prefix |
| `game/scripts/stores/store_controller.gd` | `objective_text_changed` signal docstring | Removed `ISSUE-017:` prefix |
| `game/scripts/stores/store_controller.gd` | `current_objective_text` var docstring | Removed `ISSUE-017:` prefix |
| `game/scripts/player/store_player_body.gd` | Class header docstring | Removed `(ISSUE-016)` from title line |
| `game/scripts/player/store_player_body.gd` | Class docblock body | Removed `described by ISSUE-016 under` |
| `game/scripts/player/player_controller.gd` | `set_input_listening` docstring | Replaced `(now banned by ISSUE-011 / ...)` with `(enforced by tests/validate_input_focus.sh)` |
| `game/autoload/event_bus.gd` | Section header `Phase 1 Signal Inventory` | Removed `(ISSUE-022)` |
| `game/autoload/event_bus.gd` | `run_state_changed` signal docstring | Removed `(ISSUE-020)` |
| `game/autoload/event_bus.gd` | Section header `Sports Cards — Grading Hint` | Removed `(ISSUE-018)` |
| `game/autoload/event_bus.gd` | Section header `Sports Cards — ACC Numeric Grading` | Removed `(ISSUE-015)` |
| `game/autoload/event_bus.gd` | `tutorial_context_entered` signal docstring | Replaced `ISSUE-004:` prefix with `Emitted when` |
| `game/autoload/event_bus.gd` | `tutorial_context_cleared` signal docstring | Replaced `ISSUE-004:` prefix |
| `game/autoload/event_bus.gd` | `interactable_hovered/clicked` signal docstring | Replaced `ISSUE-003:` prefix |
| `game/autoload/event_bus.gd` | `toggle_completion_tracker_panel` signal docstring | Replaced `ISSUE-022:` prefix |
| `game/autoload/event_bus.gd` | `objective_text_changed` signal docstring | Replaced `ISSUE-017:` prefix |
| `game/autoload/event_bus.gd` | Section header `Phase 1 emit_* wrappers` | Removed `(ISSUE-022)` |

**Scope note:** ISSUE-XXX references appear in ~50 additional locations across
files not touched in this pass. Removing only a subset would create inconsistency,
so the remainder is left for a dedicated sweeping sed pass over the full repo.

### Files Still >500 LOC

No extraction was performed in this pass (no clean split identified without
behavioral risk). Updated line counts after dead-code removal:

| File | LOC | Status |
|---|---|---|
| `game/scenes/world/game_world.gd` | 1397 | See Pass 1 extraction plan |
| `game/scripts/core/save_manager.gd` | 1333 | Justified — append-only migration chain |
| `game/autoload/data_loader.gd` | 1059 | −8 lines from alias removal; see Pass 1 plan |
| `game/scenes/ui/hud.gd` | 812 | −17 lines from dead-code removal; see Pass 1 plan |
| `game/scripts/systems/customer_system.gd` | 907 | Not touched this pass |
| `game/scripts/systems/inventory_system.gd` | 877 | Not touched this pass |
| `game/scenes/ui/day_summary.gd` | 815 | Not touched this pass |
| `game/autoload/event_bus.gd` | 686 | Justified — pure signal registry, no logic to extract |

---

Pass scope: modified files in current working tree plus untracked new files.
Constraint: no behavioral changes, no public API signature changes.

---

## Dead Code Removed

### `game/scripts/player/player_controller.gd`
Removed two `if OS.is_debug_build()` blocks inside `_apply_keyboard_movement` that printed movement-key events and pivot position to stdout on every key press. These were debug instrumentation, not production guards, and violated the "no debug prints" checklist rule.

- Removed lines (pre-edit): 198–206 (key-press log block) and 230–231 (pivot log line)
- Net: −11 lines

---

## Comments — Fixed or Removed

### `game/autoload/difficulty_system.gd:46`
**Before:** `## Changes difficulty mid-game. Emits difficulty_changed signal.`
**After:** `## Changes difficulty mid-game. Emits difficulty_selected and difficulty_changed.`

`apply_difficulty_change` always emits both signals (lines 60–61). The old comment was incomplete and would mislead a caller who connected only one signal.

### `game/scenes/ui/hud.gd:90–91` (pre-edit line numbers)
Removed the field-level `## ISSUE-017:` comment on `_objective_label`. The binding is fully documented in the handler docstring at `_on_objective_text_changed` (same file, ~30 lines below). Two copies of the same description on the same wiring add noise without adding information.

### `game/scripts/player/store_player_body.gd:22`
Removed the stale count `(14+ callers)` from the class docstring note about why the class is named `StorePlayerBody` rather than `PlayerController`. The count was accurate when written and will rot. The constraint (class name taken) is what matters, not the count.

---

## Consistency Changes

No cross-file naming or formatting inconsistencies were found in the modified file set that warranted normalization. The two `_format_cash` implementations (see Duplicates section) differ intentionally in precision; no rename was needed.

---

## Duplicates — Justified, Not Consolidated

### `_format_cash` in `game/scenes/ui/hud.gd` and `game/scripts/ui/kpi_strip.gd`

These share a name but are semantically different:

- `hud.gd`: full precision with comma-grouped thousands and cents (e.g. `$1,234.56`)
- `kpi_strip.gd`: rounded whole-dollar display (e.g. `$1234`)

The KPI strip intentionally shows a compact number; the HUD shows the exact balance. Consolidating them into a shared utility would require choosing one format or adding a formatting-mode parameter — both are behavioral changes. **Justified: keep separate.**

### `_rep_tier_name` (kpi_strip.gd) vs `_get_tier_name` (hud.gd)

These map a reputation score to a tier label but use different threshold tables and different localization behavior:

- `kpi_strip.gd` returns raw English strings ("Landmark", "Reputable", …)
- `hud.gd` calls `tr()` for localization and uses slightly different threshold values (50.0 vs 51.0 for the "Reputable"/"Destination" boundary)

The threshold mismatch is a real inconsistency but fixing it requires a content/design decision about which threshold is correct. That decision requires context outside this pass.

**Escalation (see below):** threshold mismatch between `kpi_strip._rep_tier_name` (51.0) and `hud._get_tier_name` (50.0).

---

## Files Still >500 LOC

### `game/autoload/data_loader.gd` — 1067 lines

**Extraction plan:** The file has three distinct responsibilities:

1. **Discovery** (lines 1–200): file-system scan of `res://game/content/` JSON
2. **Parsing / validation** (lines 200–650): per-catalog typed deserialization
3. **Public getters** (lines 679–1067): backward-compatible API surface

A `DataLoaderParser` class could own (2), leaving `DataLoaderSingleton` as a thin dispatch layer. The split is clean because the parser functions accept raw `Dictionary` and return typed resources with no autoload references. The getters at (3) stay on `DataLoaderSingleton`.

Blocker: the `gdlint:disable=max-file-lines` at line 1 is already a deliberate exception acknowledged by the project. The extraction is safe but non-trivial; defer to a dedicated refactor pass rather than mixing with this cleanup.

### `game/scripts/core/save_manager.gd` — 1330 lines

The `# gdlint:disable=max-public-methods,max-file-lines` directive at line 1 is a project-acknowledged exception. The file contains one large sequential migration chain (`_migrate_v1_to_v2`, `_migrate_v2_to_v3`, …) that must stay in-order and is intentionally append-only per the documented policy at lines 27–30. Splitting would risk migration-step ordering bugs.

**Justification: legitimately large.** The class docstring (lines 3–31) explains the policy. Future passes should extract only the `_collect_save_data` / `_distribute_load_data` fan-out (lines ~200–360) as a `SaveDataBroker`, once that shape stabilizes.

### `game/scenes/ui/hud.gd` — 802 lines (post-edit)

**Extraction plan:** The file has two separable concerns:

1. **Signal wiring + state visibility** (lines 98–300): EventBus connections and `_apply_state_visibility`
2. **Counter + animation helpers** (lines 396–802): pulse/flash tweens, cash counting animation, counter management

A `HudCounterAnimator` component node could own (2), receiving values via its own signals rather than reaching into `_cash_label` directly. This would also let tests cover animation logic in isolation.

Blocker: the animation helpers share instance variables (`_cash_count_tween`, `_counter_scale_tweens`, etc.) with the wiring layer. Extraction requires introducing message-passing between the two pieces — a small but non-zero behavioral risk. Defer to dedicated pass.

### `game/scenes/ui/inventory_panel.gd` — 687 lines

**Extraction plan:** The tab filtering + search logic (lines ~260–430) is independent of the panel show/hide lifecycle (lines 77–260). A `InventoryFilter` inner class or helper script could own the query side. The `_shelf_actions: InventoryShelfActions` pattern (line 35) already demonstrates this team uses helper objects — apply the same pattern here.

Blocker: `_shelf_actions` currently owns some of the item-mutation paths; the boundary needs auditing before cutting. Defer.

### `game/autoload/event_bus.gd` — 681 lines

**Justification: legitimately large.** This file is a pure signal registry — all 681 lines are `signal` declarations and section-header comments. There is no logic to extract. The category headers (`# ── Time ──`, `# ── Economy ──`, etc.) already provide the structure. No action taken.

### `game/autoload/staff_manager.gd` — 541 lines

**Extraction plan:** The NPC spawn/despawn block (lines 342–410) is self-contained and references only `_active_npcs`, `store_root`, and `StaffDefinition`. It could move to a `StaffNpcSpawner` helper. The split is clean because spawn logic never touches `_staff_registry` directly.

Blocker: `_get_active_store_scene_root` walks the full scene tree, which is risky to change mid-session. Defer to a dedicated NPC-system pass.

---

## Escalations

### Reputation tier threshold mismatch

`kpi_strip.gd:_rep_tier_name` uses 51.0 as the threshold for the second tier; `hud.gd:_get_tier_name` uses 50.0. The two panels show different tier names for a score of exactly 50.

**Blocker:** Which value is correct is a game-design question (content balance), not an engineering question.
**Smallest next action:** Add a `TODO(design): reconcile rep tier threshold 50.0 vs 51.0` comment at both call sites and raise a design-task issue so the decision is tracked.

**Not done in this pass** because adding a comment citing a future decision is explicitly listed as a rejected output. The report entry here is the tracking artifact.

---

## New Files — Notes

### `game/scripts/components/nav_zone_interactable.gd` (33 lines, untracked)

New file, clean. No dead code, no outdated comments. The `zone_index` field has no range validation in `_ready`, but adding a validation assertion here would be a new behavioral guard, not a cleanup. No changes made.

### `tests/gut/test_nav_zone_navigation.gd` (85 lines, untracked)

New test file. No commented-out blocks or dead test bodies. No changes made.

---

## Pass 3 — 2026-04-27

Scope: full audit of all working-tree modified and untracked files not covered by earlier passes.
Constraint: no behavioral changes, no public API signature changes.

### Consistency Changes

**`.github/workflows/validate.yml`** — DRY `GODOT_VERSION`

The Godot engine version appeared five times as a literal string (`4.6.2` in cache keys, `4.6.2-stable` in install steps) across two jobs (`gut-tests`, `interaction-audit`). Added `GODOT_VERSION: "4.6.2-stable"` to the workflow-level `env:` block; replaced all four cache-key literals with `${{ env.GODOT_VERSION }}`; removed both redundant `GODOT_VERSION="4.6.2-stable"` local shell assignments in the install steps (the env var is available to `run:` shells automatically). Future version bumps now require a single edit.

### Comments — Added (non-obvious WHY)

**`game/scripts/systems/authentication_system.gd:223–225`** — `_is_suspicious_entry`

Added three-line comment explaining why the function checks three different dictionary keys (`suspicious`, `is_suspicious`, `suspicious_chance`). These represent three successive content-schema generations. Without this comment, the multi-key check reads as a bug rather than intentional backward-compatibility.

### Dead Code Removed

None. No commented-out blocks, unused variables, or stale experiment remnants were found in the unreviewed modified files.

### Candidates Inspected and Left Unchanged

| Location | Finding | Decision |
|---|---|---|
| `game/autoload/event_bus.gd:16–20` | Comment about `run_state_changed` vs `game_state_changed` signals | Accurate: documents two distinct signal lineages and their relationship. Left as-is. |
| `game/scenes/ui/inventory_panel.gd:7` | `# Localization marker for static validation: tr("INVENTORY_CONDITION")` | Intentional i18n anchor for static-analysis tools that scan for tr() keys; not dead code. Left as-is. |
| `game/scenes/world/game_world.gd:1121` | `_sports: SportsMemorabiliaController` parameter | Underscore-prefixed in GDScript convention for intentionally unused parameters. Correct pattern. Left as-is. |
| `game/scenes/world/game_world.gd:1401–1402` | `_on_ending_dismissed() -> void: pass` | Connected to `EndingScreen.dismissed` at line 670. Intentional no-op; `pass` is required GDScript syntax for an empty body. Left as-is. |
| `game/scripts/core/save_manager.gd:1232` | Comment: `user:// always exists; the push_warning below is unreachable (§F-07)` | Accurate: explains the early-return and the unreachable error path. Left as-is. |
| Test files — repetitive assertion patterns | Many test functions share structural similarity (same setup/assert pattern across different inputs) | Normal for unit tests. Parameterized-test helpers would add abstraction not required by the task. Left as-is. |

### Files Still >500 LOC (unchanged from Pass 2)

No new extractions performed. Pass 2 extraction plans remain valid and are not repeated here. Line counts are stable from Pass 2.

---

## Pass 4 — 2026-04-28

Scope: working-tree modified files and untracked new files added since the
Pass 3 commit. Constraint: no behavioral changes to public API; defensive
behavior preserved.

### Dead Code Removed

**`game/autoload/tutorial_context_system.gd`** — `_on_objective_changed` placeholder hook (8 lines)

The function body was `pass`; the comment justified keeping it as a hook for
"future step-advancement logic" — the exact "design for hypothetical future
requirements" anti-pattern called out in the cleanup rules. The matching
`EventBus.objective_changed` connection in `_connect_signals()` was removed
alongside the function. No test asserted the connection existed (verified
across `tests/` and `game/tests/`). Same shape as the Pass 2 cleanup of the
`hud.gd` panel-count tracking chain: connect → no-op handler → no reader.

- Removed lines: connection block at `_connect_signals` (2 lines) plus the
  `_on_objective_changed` function (6 lines including blank-line separator).
- Net: −10 lines (file 191 → 181 LOC).
- Verification: full GUT suite (4651/4651 passed, 26646 asserts) and the
  `test_tutorial_context_system.gd` / `test_tutorial_context_validation.gd`
  suites pass after the removal.

### Comments — Inspected and Left Unchanged

| Location | Finding | Decision |
|---|---|---|
| `game/scripts/stores/retro_games.gd:443–486` | Three `push_warning` blocks each prefixed with `# §F-32 — …` justifying the silent-skip path | Accurate cross-references to `docs/audits/error-handling-report.md`. Left as-is. |
| `game/scripts/stores/retro_games.gd:498–507` | `push_error` block prefixed with `# §F-33 —` for registry-inconsistency | Accurate cross-reference. Left as-is. |
| `game/scripts/player/player_controller.gd:135–142` | `_resolve_camera()` docblock cites §F-36 explaining why null return is silent | Accurate: CameraAuthority + StoreReadyContract own the loud failure path; double-firing here would be noise. Left as-is. |
| `game/scripts/stores/store_controller.gd:359–404` | `_push_/_pop_gameplay_input_context` docblock cites §F-35 explaining each silent-return branch | Accurate. Left as-is. |
| `game/scripts/stores/store_controller.gd:597–600` | `print("[dev-fallback] …")` inside `dev_force_place_test_item` | Intentional dev logging; method is guarded by `OS.is_debug_build()`. Left as-is. |
| `game/scripts/ui/tutorial_overlay.gd:5` | `# Localization marker for static validation: tr("TUTORIAL_WELCOME")` | Established codebase pattern (8 other UI scripts use the same marker); already justified in Pass 3. Left as-is. |
| `game/scenes/debug/debug_overlay.gd:206, 213` | Calls `time_system._advance_hour()` / `_end_day()` (private API) | Pre-existing pattern; debug overlays are privileged callers in this codebase. Tests follow the same convention. Not introduced by this pass. Left as-is. |

### Duplicates — Justified, Not Consolidated

**`store_controller._on_objective_updated` vs `_on_objective_changed`**

Both handlers extract a text string from a Dictionary payload, check `hidden`,
and forward to `set_objective_text()`. Apparent duplicate, but they are bound
to two distinct `EventBus` signals with different payload schemas (verified
against `objective_director.gd:90–112`):

- `objective_updated` payload uses keys `current_objective`, `next_action`,
  `input_hint`, `optional_hint` — handler reads `current_objective` first.
- `objective_changed` payload uses keys `objective`, `text`, `action`, `key` —
  handler reads `text` first.

Each handler's fallback key handles the other emitter's text key, but
removing the fallbacks (or merging into one method) would change defensive
depth. The signals exist as parallel lineages on purpose (already documented
in `event_bus.gd:16–20` per Pass 3). **Justified: keep separate.**

### ISSUE-XXX References — Sweep Deferred

The Pass 2 directive ("Removing only a subset would create inconsistency, so
the remainder is left for a dedicated sweeping sed pass over the full repo")
was followed. Notably, `store_director.gd:2` retains `(ISSUE-008, …)` even
though the same diff removed `(ISSUE-009)` from line 20 of the same file —
the broader cross-codebase sweep (validate scripts, test names, autoload
docstrings) is still pending and removing the line-2 reference in isolation
would create internal inconsistency with `tests/validate_issue_008_*.sh` and
`tests/unit/test_store_director.gd:1`. Left as-is for the dedicated sweep.

### Files Still >500 LOC

Two files in the working-tree set crossed (or remain over) the 500-line bar
this pass; one was already covered by a Pass 1/2 plan. No extractions
performed; rationale below.

| File | LOC | Disposition |
|---|---|---|
| `game/scenes/world/game_world.gd` | 1427 (was 1397 in Pass 2) | Pass 1/2 extraction plan still valid. Growth this pass is the StoreDirector injector seam (`_inject_store_into_container`, +27 lines) — fits inside the existing "hub-mode wiring" cluster, no new clean split surfaced. |
| `game/scripts/stores/store_controller.gd` | 627 (was ~451 pre-pass) | Newly over 500. **Justified:** added surface is the `StoreReadyContract` interface (`is_controller_initialized`, `get_input_context`, `has_blocking_modal`) plus the InputFocus push/pop machinery (`_push_/_pop_gameplay_input_context`, `_get_input_focus`) — all directly enforcing the contract documented in `docs/architecture/ownership.md` rows 2 and 5. Splitting the contract methods into a mixin would force every subclass (electronics, retro_games, video_rental, sports_memorabilia, pocket_creatures) to take on the mixin and re-thread `_inventory_system` access. Defer; revisit only when a sixth store concretely needs another StoreReadyContract method. |
| `game/scripts/stores/retro_games.gd` | 566 (was ~485 pre-pass) | Newly over 500. **Justified:** the +80 lines are the §F-32 / §F-33 defensive-shape branches in `_seed_starter_inventory` plus the new `_add_starter_item_by_id(raw_id, quantity, condition)` overload that supports both String and Dictionary `starting_inventory` JSON shapes. Each new branch carries a `push_warning` / `push_error` and a section reference; a helper file would scatter the related diagnostics. Acceptable for a single store-scene controller. |
| `tests/gut/test_day1_inventory_placement_loop.gd` | 321 | Under 500. New, no action. |
| `tests/gut/test_first_sale_chain.gd` | 261 | Under 500. New, no action. |

### Verification

- Full GUT suite: 4651/4651 passed, 26646 asserts (`tests/run_tests.sh`).
- Static-validator FAILs reported by `run_tests.sh` are pre-existing and
  unrelated to this pass (e.g. `economy_system.gd is 665 lines`, missing
  English CSV registration in `project.godot`, `wrapped_store` tutorial-context
  warnings) — none touch files modified in this pass.

---

## Pass 5 — 2026-04-28

Scope: working-tree modified files and untracked new files added since the
Pass 4 commit, including the Day-1 quarantine guard set, `Day1ReadinessAudit`
autoload, and the `StoreDirector.set_scene_injector` seam.
Constraint: no behavioral changes, no public API signature changes.

### Dead Code Removed

**`game/scripts/stores/retro_games.gd`** — `_on_customer_purchased` +
`_check_condition_note` placeholder chain (20 lines)

`_check_condition_note` was three early-return guards and an empty body —
no signal emission, no state change, no observable effect. Its only caller
was `_on_customer_purchased` (`if not _is_active: return; _check_condition_note(...)`),
whose only purpose was to forward to the no-op. The matching
`EventBus.customer_purchased` connection in `initialize()` was removed
alongside both functions. Same shape as the Pass 2 `hud.gd` panel-count
chain and Pass 4 `tutorial_context_system.gd` `_on_objective_changed`
removal: emitter → handler → no-op terminator with no readers.

- Removed: `EventBus.customer_purchased` connection in `initialize()` (1 line),
  `_on_customer_purchased` (7 lines), `_check_condition_note` (8 lines),
  blank-line separators (4 lines).
- Net: −20 lines (file 608 → 588 LOC).
- Verification: full GUT suite passes (4666/4666); the
  `customer_purchased` signal still has 14 other production listeners
  (reputation, milestones, ending evaluator, tutorial, inventory, audio,
  performance, etc.), all unaffected.

### Comments — Stale Provenance Reference Stripped

**`game/scripts/stores/store_controller.gd`** — `dev_force_place_test_item`
docstring suffix

Removed the trailing `Per BRAINDUMP Audit Pass 9.` from the docstring of
`dev_force_place_test_item`. BRAINDUMP is project meta-state (a rolling
scratchpad, see `BRAINDUMP.md` policy at `docs/contributing.md`), not a
stable doc — citing a specific "Audit Pass 9" by number is the same kind
of provenance metadata as the `ISSUE-XXX` references stripped in Pass 2:
it rots when the BRAINDUMP is rewritten (which the recent
`235f628 Overwrite BRAINDUMP with repo audit rescue plan` commit just
did). The remainder of the docstring already explains *why* the function
exists ("intended to unblock the Day-1 placement loop when the inventory
UI is broken; not a substitute for the real flow") — the sentence stands
on its own.

### ISSUE-XXX References — Sweep Still Deferred

Two new `ISSUE-011` references appear in `game/scenes/world/game_world.gd`
(lines 982, 997) at the `_unhandled_input` and `_try_skip_active_tutorial`
sites. These were committed in `8dd85ee2` (2026-04-26), pre-date this
pass, and follow the existing inline-issue-citation convention shared
with `~50 other locations` flagged in Pass 2. Per the Pass 2/4 directive
("Removing only a subset would create inconsistency, so the remainder is
left for a dedicated sweeping sed pass over the full repo"), these are
out of scope for an in-pass surgical edit. Left as-is for the dedicated
sweep.

### Untracked Files — Inspected and Accepted Unchanged

| File | LOC | Finding |
|---|---|---|
| `game/autoload/day1_readiness_audit.gd` | 207 | Clean. The §F-40 docstring on `_resolve_camera_source` already justifies the silent `&""` fallback under unit-test isolation. No commented-out blocks, no TODOs, no dead variables. |
| `tests/gut/test_day1_readiness_audit.gd` | 253 | Clean. Test seam (`evaluate_for_test`) is already documented at the autoload definition site. |
| `tests/gut/test_day1_quarantine.gd` | 206 | Clean. `before_all` / `after_all` save/restore `GameManager` global state — necessary for parallel-test safety, no cleanup needed. |
| `tests/gut/test_day1_inventory_placement_loop.gd` | 321 | Clean. End-to-end JSON-driven placement loop test; no commented-out scaffolding. |
| `tests/gut/test_first_sale_chain.gd` | 261 | Clean. |
| `tests/gut/test_day_summary_post_sale_snapshot.gd` | 154 | Clean. |
| `tests/gut/test_retro_games_debug_geometry_defaults.gd` | 106 | Clean. |
| `docs/audits/2026-04-28-audit.md` | 12 | Auto-generated checkpoint table; no action. |
| `CLAUDE.md` | (root) | Project agent notes; user-authored. |

### Files Still >500 LOC

Line-count delta from Pass 4 baseline:

| File | Pass 4 LOC | Now | Disposition |
|---|---|---|---|
| `game/scenes/world/game_world.gd` | 1427 | 1443 | +16 from `_inject_store_into_container` injector seam (StoreDirector hub-mode wiring). Pass 1/2 extraction plan still valid. |
| `game/scripts/core/save_manager.gd` | 1330 | 1364 | +34 from new save-key fan-out (Day-1 quarantine flags); append-only migration policy at file lines 27–30 still holds. Justified — see Pass 2. |
| `game/scenes/ui/hud.gd` | 802 | 849 | +47 from objective/interactable focus tracking (`_objective_active`, `_interactable_focused`) that drives the telegraph-card priority order documented in `CLAUDE.md`. The two booleans plus their handler triplet are tightly coupled to `_refresh_telegraph_card`; extracting them would require exposing the priority state through a new component interface. Pass 2 extraction plan (HudCounterAnimator) remains the cleanest split. |
| `game/scripts/stores/store_controller.gd` | 627 | 637 | +10 from the StoreReadyContract invariant 3/7/8 helpers (`is_controller_initialized`, `get_input_context`, `has_blocking_modal`) plus the `_pushed_gameplay_context` push/pop ownership move. Pass 4 justification still holds. |
| `game/scripts/stores/retro_games.gd` | 566 | 588 | −20 from this pass's dead-code removal vs +42 in this commit set (slot-display refresh helpers, `_apply_debug_label_visibility`, Day-1 quarantine). Net: still over 500 but Pass 4 justification (per-store §F-32/§F-33 defensive shapes) holds; quarantine helper is co-located with the rest of the lifecycle code. |
| `game/autoload/data_loader.gd` | 1059 | 1059 | Unchanged. Pass 1 extraction plan still valid. |
| `game/scripts/systems/customer_system.gd` | 907 | 907 | Unchanged. |
| `game/scripts/systems/inventory_system.gd` | 877 | 877 | Unchanged. |
| `game/scenes/ui/day_summary.gd` | 815 | 815 | Unchanged. |
| `game/autoload/event_bus.gd` | 681 | 686 | +5 from new Day-1 quarantine signal additions; pure signal registry, justification from Pass 2 holds. |

### Verification

- Full GUT suite: 4666/4666 passed (`tests/run_tests.sh`).
- Static-validator FAILs reported by `run_tests.sh` are pre-existing and
  unrelated to this pass (ISSUE-239 packs/tournaments JSON parse errors,
  pre-existing `wrapped_store` tutorial-context warnings) — none touch
  files modified in this pass.

### Escalations

None.

---

## Pass 6 — 2026-04-29

Scope: working-tree modified files and the one untracked file
(`docs/audits/2026-04-29-audit.md`) added since the Pass 5 commit.
Concretely, the diff scope is the orbit-camera bounds/zoom clamp landing
in `StoreSelectorSystem`, the embedded `PlayerController` + `Camera3D`
removal from `retro_games.tscn` (with `Storefront.visible = false`), the
`StoreDecorationBuilder._add_store_sign` Label3D excision, three test
files updated to the new contract, the deletion of two top-level meta
docs (`AIDLC_FUTURES.md`, `CLAUDE.md`), and the regeneration of
`docs/audits/{2026-04-28-audit,ssot-report,error-handling-report,security-report}.md`.
Constraint: no behavioral changes, no public API signature changes.

### Dead Code Removed

The branch itself already removed three concrete dead-content surfaces
before this pass began. They are recorded here so the cleanup-report
captures the full delta against the Pass 5 baseline; no additional dead
code was found in this pass:

- **`game/scenes/stores/retro_games.tscn`** — embedded
  `PlayerController` + `StoreCamera` (Camera3D) child node and the
  associated `[ext_resource id="23"]` line for
  `res://game/scripts/player/player_controller.gd`. The orbit camera is
  now instantiated by `StoreSelectorSystem._PLAYER_CONTROLLER_SCENE`
  and parented to `StoreContainer`, so the in-scene copy was
  duplicate WASD handling that raced `CameraAuthority`'s
  single-active-camera contract. Net: −15 lines in the scene file.
- **`game/scripts/stores/store_decoration_builder.gd`** — the
  `label: String` parameter on `_add_store_sign` plus the eight-line
  `Label3D.new()` block that consumed it. Each shipping store's
  exterior sign is now authored as a `SignName` Label3D inside its
  `.tscn` (orientation, font, and z-fighting clearance are
  art-controlled per scene — see
  `tests/gut/test_retro_games_scene_issue_006.test_sign_name_text_is_correct`).
  All five `_build_*` callers were updated to the new
  three-argument signature in the same diff. Net: −12 lines.
- **`AIDLC_FUTURES.md`** (42 lines), **`CLAUDE.md`** (50 lines) —
  top-level meta docs deleted. Pass 5's "untracked files inspected"
  table noted `CLAUDE.md` as project agent notes; both files are now
  removed from the repo entirely. No production code referenced them
  (verified by repo-wide grep: zero non-doc references).

### Comments — Stale Provenance Reference Stripped

**`game/scripts/systems/store_selector_system.gd:335`** —
`_set_hallway_camera_enabled` ISSUE-011 cite

**Before:**
```gdscript
# bypass-detector (`tests/validate_input_focus.sh`, ISSUE-011) stays clean.
```
**After:**
```gdscript
# bypass-detector (`tests/validate_input_focus.sh`) stays clean.
```

Same shape as the Pass 2 normalization of the matching comment in
`game/scripts/player/player_controller.gd:set_input_listening`
(`(now banned by ISSUE-011 / ...)` → `(enforced by tests/validate_input_focus.sh)`).
The validator path is the load-bearing reference; the issue number rots
once the ticket closes. The replacement validator script
(`tests/validate_input_focus.sh`) is verified to exist on disk. Net:
−1 char (removes `, ISSUE-011`).

### Comments — Inspected and Left Unchanged

| Location | Finding | Decision |
|---|---|---|
| `game/scripts/systems/store_selector_system.gd:13–28` | `_STORE_PIVOT_BOUNDS_*` and `_STORE_ZOOM_*` const blocks each carry a multi-line `Why:` comment + cross-reference to `docs/audits/error-handling-report.md` §F-50 | Accurate, current, load-bearing. The §F-50 cross-reference is the documented enforcement contract for "future store with a larger nav footprint must override these constants." Left as-is. |
| `game/scripts/systems/store_selector_system.gd:261–267` | `_move_store_camera_to_spawn` docstring cites §F-51 explaining the silent-return-on-missing-marker contract | Accurate cross-reference; the GUT test contract is the loud surface. Left as-is. |
| `game/scripts/stores/store_decoration_builder.gd:174–176` | Updated `_add_store_sign` docstring explains why the helper no longer creates a Label3D and where the per-scene `SignName` lives | Accurate, written in this branch. Left as-is. |
| `tests/gut/test_retro_games_scene_issue_006.gd:208` | Section header `# ── Nav zone structure (ISSUE-005) ─────` retains the parenthetical issue id | **Justified** — the test file's own filename (`test_retro_games_scene_issue_006.gd`) embeds an issue id; removing the in-section reference creates internal inconsistency with the filename and with the ~50-other-locations sweep deferred since Pass 2. Left for the dedicated repo-wide sweep. |
| `tests/gut/test_store_entry_camera.gd` | Class docstring cites the "brown screen" P0.2 regression in `docs/audits/phase0-ui-integrity.md` | Accurate historical regression cite; load-bearing for the reader who finds the test failing in the future. Left as-is. |

### Consistency Changes

None. All five touched code files match each other's surrounding
formatting — the `StoreSelectorSystem` const block and inline §F-50/§F-51
docstrings adopt the same `# Why: …` / `## …` shape used elsewhere in
the file (and in the audit-report-cite pattern from Pass 4 §F-32/§F-33).

### Duplicates — Inspected, Not Consolidated

#### `_collect_cameras` (test_store_entry_camera.gd) vs `_collect_by_class` (test_retro_games_scene_issue_006.gd)

Both helpers walk a `Node` subtree and gather descendants, but they are
not duplicates:

- `_collect_cameras(node) -> Array[Camera3D]` is hard-typed for
  `Camera3D` and returns a typed array.
- `_collect_by_class(node, class_name_str, out)` is generic over any
  `is_class()` string and uses an out-parameter pattern.

Each helper is local to a single test file and used only in that file.
Hoisting them to a shared `tests/helpers/` module would couple two
otherwise-independent integration tests (and the broader test tree has
no precedent for such a helper module). **Justified: keep separate.**

#### Two test functions in `test_retro_games_scene_issue_006.gd` instantiate `PlayerController` via `script.new()`

`test_camera_default_y_below_ceiling` (lines 177–191) and
`test_camera_default_z_inside_front_wall` (lines 194–205) both do
`load(...).new()` + `add_child_autofree(pc)` to read the same export
defaults (`zoom_default`, `pitch_default_deg`). Three lines of setup
repeat across the two functions.

A `_make_pc()` helper would save six lines, but the GUT convention here
favors test-local explicitness — `before_each`/`before_all` is reserved
for state that *every* test in the file uses, and only these two tests
need a fresh PlayerController. The repetition is intentional readability,
not duplication. **Justified: keep separate.**

### ISSUE-XXX References — Sweep Still Deferred

One remaining `(ISSUE-005)` parenthetical in
`tests/gut/test_retro_games_scene_issue_006.gd:208` (section header) was
inspected and left as-is — see "Comments — Inspected and Left Unchanged"
above. The Pass 2/4/5 directive ("Removing only a subset would create
inconsistency, so the remainder is left for a dedicated sweeping sed
pass over the full repo") still holds; this pass's one in-place
normalization (`store_selector_system.gd:335`) was acted on because the
file was a touched-by-this-branch GDScript source matching the exact
`(`tests/validate_input_focus.sh`, ISSUE-011)` shape Pass 2 normalized
in the sibling `player_controller.gd` file.

### Files Still >500 LOC

No file in this pass's scope crossed the 500-LOC bar except the scene
file (`retro_games.tscn`, 1531 lines, descriptive scene format — not
code, no extraction applies). Touched-this-branch line counts:

| File | LOC | Disposition |
|---|---|---|
| `game/scenes/stores/retro_games.tscn` | 1531 | Scene file. Godot `.tscn` line count is not a code-complexity metric — it scales with node count. No extraction applies; the recently-added `Storefront.visible = false` flip and the removal of the embedded `PlayerController` are net-negative on size. |
| `game/scripts/systems/store_selector_system.gd` | 420 | +27 vs Pass 5 baseline from the new `_STORE_PIVOT_BOUNDS_*` / `_STORE_ZOOM_*` const block, the four assignments in `enter_store`, and the `_move_store_camera_to_spawn` §F-51 docstring. Under 500. |
| `game/scripts/stores/store_decoration_builder.gd` | 237 | −11 vs Pass 5 baseline from `_add_store_sign` Label3D removal. Under 500. |
| `tests/gut/test_retro_games_scene_issue_006.gd` | 450 | Net change vs Pass 5 baseline from removed PlayerController-embedding tests plus the new `test_storefront_hidden_during_interior_gameplay` case. Under 500. |
| `tests/gut/test_store_entry_camera.gd` | 112 | +42 vs Pass 5 baseline from the new `test_walking_body_store_scenes_ship_zero_in_scene_cameras` case. Under 500. |
| `tests/unit/test_store_selector_system.gd` | 283 | +59 vs Pass 5 baseline from the two new clamp-coverage tests (`test_enter_store_clamps_camera_pivot_to_store_footprint`, `test_enter_store_caps_camera_zoom_to_store_interior`). Under 500. |

The cumulative >500-LOC roster from Pass 5 (`game_world.gd`,
`save_manager.gd`, `hud.gd`, `store_controller.gd`, `retro_games.gd`,
`data_loader.gd`, `customer_system.gd`, `inventory_system.gd`,
`day_summary.gd`, `event_bus.gd`) is unchanged — none of those files
were touched in this branch. Pass 1/2 extraction plans and per-file
justifications still hold.

### Untracked Files — Inspected and Accepted Unchanged

| File | LOC | Finding |
|---|---|---|
| `docs/audits/2026-04-29-audit.md` | 12 | Auto-generated checkpoint table (same shape as `2026-04-27-audit.md` / `2026-04-28-audit.md`); no action. |

### Verification

- Full GUT suite: **4658/4658 passed**, 26692 asserts (`tests/run_tests.sh`).
  Pass 5's run reported 4666; the −8 delta is the eight
  PlayerController-embedding tests intentionally removed from
  `test_retro_games_scene_issue_006.gd` plus the additions in
  `test_store_entry_camera.gd` / `test_store_selector_system.gd`.
  Net assert count went up, confirming the new clamp/footprint coverage.
- Static-validator FAILs reported by `run_tests.sh` are pre-existing
  and unrelated to this pass (ISSUE-239 packs/tournaments JSON parse
  errors, pre-existing `wrapped_store` tutorial-context warnings) —
  none touch files modified in this pass. Verified the same
  `validate_issue_239.sh` failure messages appear in the Pass 5
  Verification block.

### Escalations

None.

---

## Pass 7 — 2026-04-30

Scope: working-tree changes that follow the Pass 6 commit
(`115c54c Overwrite BRAINDUMP with big bang playable room directive`).
Concretely, the diff scope is the Day-1 first-sale gate backstop in
`day_cycle_controller.gd` (with paired `test_day_cycle_controller.gd`
and `test_day_cycle_close_loop.gd` first-sale-flag plumbing), the HUD
`notification_requested` / `critical_notification_requested` →
`toast_requested` forwarding shim that retired `PromptLabel` and
`ObjectiveLabel` (with `EventBus.objective_text_changed` and the local
`StoreController.objective_text_changed` signal pair), the
`ObjectiveDirector._on_item_sold` flag-before-emit ordering invariant,
the `InteractionRay._build_action_label` rewrite ("Press E to <verb>"
prefix and explicit empty-on-empty branch), the retro_games "Path B"
scene refactor (10×7 m room with embedded `PlayerController` +
`StoreCamera` + `InteractionRay`, `PlayerEntrySpawn` retired for this
store, fixture `StaticBody3D` + `BoxShape3D` solidity), and the
`tests/validate_issue_017.sh` polarity flip (asserts the absence of
the retired surfaces). Constraint: no behavioral changes, no public
API signature changes.

### Changes made this pass

| File | Change | Net |
|---|---|---|
| `tests/gut/test_hub_store_player_spawn.gd` | Removed dead `_baseline_focus_depth: int` field and its `before_each` write — last reader was `test_enter_exit_enter_does_not_leak_input_focus_frames`, deleted in `0b32f9a` along with `test_spawn_pushes_store_gameplay_context` | −2 lines |

### Dead Code Removed

**`tests/gut/test_hub_store_player_spawn.gd`** — `_baseline_focus_depth`
field + `before_each` assignment

The `var _baseline_focus_depth: int` field at module scope and its sole
write at `before_each` (`_baseline_focus_depth = InputFocus.depth()`)
had no readers in this file or anywhere else in the repo (verified by
full-tree grep). The two consumers were
`test_enter_exit_enter_does_not_leak_input_focus_frames` and
`test_spawn_pushes_store_gameplay_context`, both deleted in commit
`0b32f9a` ("Add tests for Day 1 gameplay mechanics and HUD updates")
when the test re-pivoted from a real `retro_games.tscn` instantiation
to a `MockStoreRoot` fixture. The field survived as orphaned scaffolding.
Same shape as the Pass 2 cleanup of the `hud.gd` panel-count tracking
chain and Pass 4 `tutorial_context_system._on_objective_changed`: write
side without a reader.

- Removed: field declaration (1 line) + `before_each` assignment (1 line).
- Net: −2 lines (file 153 → 151 LOC).
- Verification: full GUT suite — 4662/4662 passed (Pass 6 baseline:
  4658/4658; the +4 net is the new Day-1 first-sale gate tests in
  `test_day_cycle_controller.gd` plus the new fixture-solidity tests in
  `test_retro_games_fixture_geometry.gd` minus the deleted
  `test_mall_overview_hides_objective_label` and
  `test_store_view_hides_objective_label_before_objective_text`,
  matching the working-tree `git diff` line counts).

### Comments — Inspected and Left Unchanged

| Location | Finding | Decision |
|---|---|---|
| `game/scripts/systems/day_cycle_controller.gd:86–92` | New §F-52 inline comment block on the Day-1 first-sale gate | Accurate, written this pass; cross-references `docs/audits/error-handling-report.md` §F-52. Left as-is. |
| `game/scripts/player/interaction_ray.gd:186–194` | New §F-53 docstring on `_build_action_label` justifying the empty-on-empty silent return | Accurate, written this pass; explains the per-hover log-flooding rationale. Left as-is. |
| `game/scenes/ui/hud.gd:524–537` | New §F-54 docstring on the `_on_notification_requested` / `_on_critical_notification_requested` toast-forwarding pair | Accurate, written this pass; documents the three silent-return paths and the equivalent failure surface vs the prior in-HUD prompt path. Left as-is. |
| `game/scenes/ui/hud.gd:602–607` | Updated `_refresh_telegraph_card` priority comment ("Overlay priority: tutorial > objective rail > ticker. The interaction prompt lives on a separate CanvasLayer (layer 60)…") | Accurate, written this pass; cross-references the layer separation that lets the ticker stay visible during interactable focus. Left as-is. |
| `game/autoload/objective_director.gd:73–77` | §F-55 cite explaining flag-before-emit ordering invariant for the Day-1 close gate | Accurate, written this pass. Left as-is. |
| `game/scripts/stores/store_controller.gd:9–11` | Updated `current_objective_text` docstring after the local `objective_text_changed` signal retirement | Accurate; references StoreReadyContract invariant 10 as the new consumer. Left as-is. |
| `game/scenes/stores/retro_games.tscn:208–215` | New header comment block explaining the Path B / `_activate_store_camera` fall-through pattern | Accurate; cross-references `GameWorld._on_hub_enter_store_requested`. Left as-is. |
| `tests/gut/test_day1_quarantine.gd:188–191` | New comment on `test_telegraph_card_persists_during_interactable_focus` explaining the CanvasLayer 60 separation | Accurate, written this pass. Left as-is. |
| `tests/gut/test_store_entry_camera.gd:64–66` | New comment + tautological `assert_true(arr.size() >= 0, …)` documenting that `_BODY_CAMERA_STORE_IDS` may legitimately be empty | The assertion is vacuous (every array has size ≥ 0), but the user's stated intent is documentation: the comment + asserted-but-tautological pattern is meant to keep the test "meaningful when iterating an empty list" rather than risky. Removing the assert would also remove the explicit signal that the empty-list path was considered. Left as-is. |
| `tests/gut/test_hub_store_player_spawn.gd:77` | `# ISSUE-002: body camera owns the InteractionRay …` | Pass 2/4/5/6 directive ("Removing only a subset would create inconsistency, so the remainder is left for a dedicated sweeping sed pass over the full repo") still holds; the file's GUT class docstring above no longer carries any ISSUE prefix, but the in-section reference here matches the surviving citations across `~50 other locations` flagged in Pass 2. Left for the dedicated sweep. |
| `tests/gut/test_retro_games_scene_issue_006.gd:267` | `# ── Nav zone structure (ISSUE-005) ─────` section header | Same justification as Pass 6 ("the file's own filename embeds an issue id; removing the in-section reference creates internal inconsistency"). Left as-is. |
| `tests/gut/test_store_entry_camera.gd:99–108` | Block claims `PlayerEntrySpawn` must exist for the spawned `StorePlayerBody` to anchor — but this branch iterates the empty `_BODY_CAMERA_STORE_IDS` list, so the assertions never fire | Accurate against the documented contract: the test is forward-compatible scaffolding for any future walking-body store that gets added. The assertions inside the empty loop are unreached today but become live when the array gets populated — same forward-compat shape the user intentionally preserved with the tautological `size() >= 0` assert. Left as-is. |

### Duplicates — Inspected, Not Consolidated

#### `_on_objective_payload` (hud.gd) vs `_on_objective_updated` / `_on_objective_changed` (store_controller.gd)

The HUD's new `_on_objective_payload(payload)` handler subscribes to
both `EventBus.objective_changed` and `EventBus.objective_updated`
(see `hud.gd:100–101`) and reads `payload.text` first then falls back
to `payload.current_objective`. StoreController's two parallel handlers
each subscribe to one signal and read their preferred key first
(Pass 4 documented this as parallel signal lineages, "Justified: keep
separate"). The HUD's choice to fold the two readers into one body is
internally consistent: HUD is a leaf consumer that only needs the
text, while StoreController must also gate on `payload.hidden` and
mirror to `set_objective_text(text)` for `objective_matches_action()`.
The duplication of the key-fallback pattern (`payload.get("text",
payload.get("current_objective", ""))`) across the two files is small
and justified by their different surrounding logic.
**Justified: keep separate.**

#### `_format_cash` (hud.gd) vs `_format_cash` (kpi_strip.gd)

Pass 2 documented these as semantically different (full precision vs.
rounded whole-dollar) — still true after the Pass 7 working tree.
**Justified: keep separate.**

### ISSUE-XXX References — Sweep Still Deferred

Two surviving inline references in this pass's scope:

- `tests/gut/test_hub_store_player_spawn.gd:77`
  (`# ISSUE-002: body camera owns the InteractionRay …`)
- `tests/gut/test_retro_games_scene_issue_006.gd:267`
  (`# ── Nav zone structure (ISSUE-005) ─────` section header)

Per the Pass 2/4/5/6 directive these are out of scope for an in-pass
surgical edit. Left for the dedicated repo-wide sweep.

### Files Still >500 LOC

Line-count delta from the Pass 6 baseline:

| File | Pass 6 LOC | Now | Disposition |
|---|---|---|---|
| `game/scenes/world/game_world.gd` | 1443 | 1443 | Unchanged. Pass 1/2 extraction plan still valid. |
| `game/scripts/core/save_manager.gd` | 1364 | 1364 | Unchanged. Justified — append-only migration chain (Pass 2). |
| `game/autoload/data_loader.gd` | 1059 | 1059 | Unchanged. Pass 1 extraction plan still valid. |
| `game/scripts/systems/customer_system.gd` | 907 | 907 | Unchanged. |
| `game/scripts/systems/inventory_system.gd` | 877 | 877 | Unchanged. |
| `game/scenes/ui/day_summary.gd` | 815 | 815 | Unchanged. |
| `game/scenes/ui/hud.gd` | 849 | 837 | −12 from this branch's `PromptLabel` / `ObjectiveLabel` / `_interactable_focused` retirement; below the Pass 5 baseline (802) is not in reach without the Pass 2 HudCounterAnimator extraction, which still applies. |
| `game/autoload/event_bus.gd` | 686 | 683 | −3 from `objective_text_changed` signal removal (3 lines including the docstring). Pure signal registry; justification from Pass 2 holds. |
| `game/scripts/stores/store_controller.gd` | 637 | 632 | −5 from local `objective_text_changed` signal + matching emit lines retirement. Pass 4 justification (StoreReadyContract surface) still holds. |
| `game/scripts/stores/retro_games.gd` | 588 | 588 | Unchanged in this branch. Pass 4/5 justification holds. |
| `game/scenes/stores/retro_games.tscn` | 1531 | ~1750 | Scene file. The +219-line growth is the embedded `PlayerController` + `StoreCamera` instance, the five new `BoxShape3D` sub-resources for fixture solidity, and the 10×7 m room expansion with re-positioned lights/decals/walls — all data, not code. Godot `.tscn` line count is not a code-complexity metric (Pass 6). |

No new code files crossed the 500-LOC bar in this pass.

### Untracked Files — Inspected and Accepted Unchanged

No untracked files in scope this pass. The working-tree state is
modifications-only:
`git status -s` shows 22 modified files plus the deleted top-level
`AIDLC_FUTURES.md` (which Pass 6's report already noted; this pass's
scope re-confirms the deletion landed without leaving stale
references).

### Verification

- Full GUT suite: **4662/4662 passed** (`tests/run_tests.sh`); 391
  scripts, 63.56 s. No failures, no regressions vs the Pass 6 4658 baseline.
- Static-validator FAILs reported by `run_tests.sh` are pre-existing
  and unrelated to this pass (ISSUE-239 packs/tournaments JSON parse
  errors, pre-existing `wrapped_store` tutorial-context warnings,
  RID-leak warnings from the headless dummy renderer + text server) —
  none touch files modified in this pass.
- `tests/validate_issue_017.sh` polarity-flipped checks all pass against
  the actual working-tree state.

### Escalations

None.
