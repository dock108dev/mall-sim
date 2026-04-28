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
