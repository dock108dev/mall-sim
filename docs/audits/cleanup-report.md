# Code Quality Cleanup Report — 2026-05-01

**Scope:** structural cleanup pass over the GDScript working tree, with the
working-branch diff (shelf placement hint UI, orthographic camera mode,
MALL_OVERVIEW HUD cash visibility, retro_games scene geometry, close-day
preview) as the primary focus.

## Changes made this pass

A follow-up pass (Pass 2) was run after the original two edits below. Pass 2
revisited the SSOT report's J-2 "keep both" decision in light of the cleanup
pass directive ("Duplicate utilities — consolidate") and consolidated the
`_format_thousands` helper into `UIThemeConstants`. Details under
**## Pass 2 — `_format_thousands` consolidation** below. Behavior unchanged;
GUT suite continues to pass (4808/4808 — verified after Pass 2 edits).

The original pass applied two concrete edits. Both leave behavior identical
and the GUT suite (`tests/gut/`) continues to pass.

### Dead code removed

- **`game/scenes/ui/day_summary.gd`** — removed the two-line tombstone
  comment that flagged milestone-completion rendering as having moved to the
  standalone `milestone_card` notification "(P1.5)". The comment did not
  describe code present in the function; it described code that had already
  been removed. Per the project rule "Don't reference the current task, fix,
  or callers (… added for the Y flow …) since those belong in the PR
  description and rot as the codebase evolves," the marker is now gone. The
  `milestone_card` notification path is still discoverable via grep when a
  reader needs it.

### Splits and consolidations

- **`game/scripts/stores/retro_games.gd`** — `_apply_day1_quarantine` was
  iterating a single-element array literal (`for node_name in
  ["refurb_bench"]:`) left over from when the loop also touched
  `testing_station`. Collapsed to a direct `get_node_or_null("refurb_bench")`
  guard with an early return. Behavior is unchanged — the missing-node
  branch still returns silently, the visibility/Interactable toggles run
  identically. The `## §F-41` rationale doc-comment was updated from
  "silent `continue` on a missing node" → "silent return on a missing node"
  to match the new control flow.

### Per-finding outcomes (Act / Justify)

| # | Finding | Outcome | Rationale |
|---|---|---|---|
| 1 | Tombstone comment in `day_summary.gd` flagging milestones moved to `milestone_card` (P1.5) | **Act** | Removed. Refactor-marker comments belong in commit/PR descriptions, not source. |
| 2 | Single-element `for node_name in ["refurb_bench"]:` loop in `retro_games.gd:_apply_day1_quarantine` | **Act** | Collapsed to direct guarded call; doc-comment word `continue` → `return` to match. |
| 3 | `resolve_pivot_step` (public) wrapping `_resolve_pivot_step` (private) in `player_controller.gd` | **Justify** | The public wrapper is a deliberate test seam — `tests/gut/test_player_controller_fixture_collision.gd` calls `controller.call("resolve_pivot_step", …)`. The asymmetry with other underscore-prefixed helpers in this file is intentional: this is the only one a test driver needs to invoke without reaching past the underscore convention. Inlining would either rename a private helper (breaking the project-wide underscore convention) or force the test to bypass the convention via `.call("_resolve_pivot_step", …)`. Both are worse than the 2-line wrapper. |
| 4 | `emit_store_ready`, `emit_store_failed`, `emit_scene_ready`, `emit_input_focus_changed`, `emit_camera_authority_changed`, `emit_stocking_cursor_active`, `emit_stocking_cursor_inactive` in `event_bus.gd:655–686` look unused at first grep | **Justify** | All seven are exercised by `tests/unit/test_event_bus.gd` (lines 21, 26, 33, 38, 46, 82, 89). They are typed-signature wrappers that let tests drive signal emission without an `emit_signal("…", …)` string call. Removing them would force tests to use the stringly-typed path, losing the GDScript typecheck the wrappers exist to provide. |
| 5 | `_set_selected_as_demo` and `_remove_selected_from_demo` in `inventory_panel.gd:670–689` are near-mirror 9-line functions (only `place_demo_item`/`remove_demo_item` differs) | **Justify** | Two parallel functions with one differing call do not warrant a Callable-parameterized helper at this size — the duplication is exactly two short functions with self-documenting names that produce a clearer call site than a `_demo_helper(callable, …)` indirection. Per the project rule "three similar lines is better than a premature abstraction," this stays. |
| 6 | Doc-comments on `player_controller.gd` `@export` vars and public methods | **Justify** | Godot surfaces `##` doc comments as inspector tooltips and editor hover text — they are user-facing UX, not narrative bloat. Removing them would degrade the editor experience. |
| 7 | `_DEFAULT_PROMPT` and `_ITEM_PROMPT_FORMAT` in `placement_hint_ui.gd` differ only by `"item"` vs `"%s"` | **Justify** | Two named constants is clearer than runtime `%` substitution against a different copy string. The default and per-item prompts are intentionally worded differently; collapsing them costs grep clarity for no real-world LOC savings. |
| 8 | Underscore-prefixed `_message_label` accessed by `test_placement_hint_ui.gd` | **Justify** | Project-wide convention: 359 such test→underscore-private accesses across 30 test files. Adding a public getter for tests only would be inconsistent with the rest of the suite. |
| 9 | `test_glass_case_slots_sit_at_or_above_case_top` (in `test_placed_item_prop_visibility.gd`) overlaps with `test_glass_case_slots_rest_on_case_top` (in `test_retro_games_fixture_geometry.gd`) | **Justify** | The two tests check different contracts: the strict `assert_almost_eq` (±0.05) protects against drift in either direction; the lax `assert_gte` (Y ≥ top − 0.01) protects against placeholder props sinking inside the case. Removing the lax check on the assumption it is subsumed by the strict check would couple two test files together — if the strict tolerance is later relaxed for animation, the lax invariant would silently disappear. Preserving both keeps the contracts orthogonal. |
| 10 | `SCENE_PATH = "res://game/scenes/stores/retro_games.tscn"` constant repeated across 9 test files | **Justify** | Each test file is self-contained — extracting to a shared `tests/gut/_retro_games_paths.gd` would create coupling for a single literal that has not changed in this branch and that is grep-able. Repetition is the existing in-tree style; matching it is a Rule 3 ("match the surrounding style") concern. |
| 11 | Verbose split `push_warning(...)` strings in `inventory_shelf_actions.gd` (e.g. `"prefix..." + "...suffix"`) | **Justify** | The line wraps are on `gdtoolkit`-recommended 80-column boundaries (CI runs `gdlint`); concatenation is the in-tree pattern for long warning strings. Joining onto a single line would fail lint in CI. |

No bare `TODO` / `follow-up: investigate` lines were introduced in source by
this report.

## Files still >500 LOC

Files >500 lines under `game/` (excluding `addons/`), with extraction
posture. None were split this pass. Items 1–10 are the candidates that would
deliver the most LOC reduction; they are sequenced for a future structural
pass and called out explicitly here so they are not silently re-deferred.

| LOC | File | Posture |
|---|---|---|
| 1507 | `game/scenes/world/game_world.gd` | **Plan** — five named init tiers (1 data → 5 meta) listed in `docs/architecture.md`. Clean split: extract one `*_world_initializer.gd` helper per tier, leaving `game_world.gd` as the orchestrator. Holds because tier transitions cross-reference tier-1/2 state and a partial extraction would split a single ownership boundary. Defer to a dedicated tier-extraction pass. |
| 1364 | `game/scripts/core/save_manager.gd` | **Plan** — atomic write, schema migration, slot indexing, and serialization are four distinct concerns. Clean split: extract `save_serializer.gd` (schema/dict shape) and `save_io.gd` (atomic write + slot file paths). Deferred — touching save-format code without a dedicated migration test pass risks the save-load contract documented in `docs/configuration-deployment.md`. |
| 1059 | `game/autoload/data_loader.gd` | **Plan** — JSON discovery, per-schema loaders, and registry handoff are separable. Clean split: one `*_loader.gd` per content category (items, suppliers, ARC unlocks, objectives), aggregated by `data_loader.gd`. Defer — needs a content-loading regression suite already in scope for a future pass. |
| 1044 | `game/scripts/stores/sports_memorabilia_controller.gd` | **Justify** — store-specific gameplay surface (display layout + grading + memorabilia haggle hooks). Splitting would scatter store contract logic across files and violate "one owner per responsibility" (`docs/architecture/ownership.md` row 3). The store controller IS the per-store boundary. |
| 979 | `game/scripts/stores/video_rental_store_controller.gd` | **Justify** — same reasoning as sports_memorabilia. Per-store controllers are the canonical home for their store's logic. |
| 945 | `game/scripts/content_parser.gd` | **Plan** — multiple `parse_*` schema validators in one module. Extract per-content-type parsers under `game/scripts/content_parsers/`. Defer — content-schema invariants must be preserved across the split. |
| 907 | `game/scripts/systems/customer_system.gd` | **Justify** — single ownership of customer lifecycle (spawn, queue, checkout handoff). Extracting a piece requires changing the system's public contract used by tests; size is a function of the responsibility, not duplication. |
| 877 | `game/scripts/systems/inventory_system.gd` | **Justify** — sole owner of inventory write operations (architecture doc). Splitting moves writes to two locations, which is precisely the failure mode the ownership doc forbids. |
| 840 | `game/scenes/ui/hud.gd` (modified this branch) | **Plan** — three concerns: top-bar label management, telegraphed-event ticker, tutorial-step suppression. Clean split: extract `hud_telegraph.gd` and `hud_tutorial_gate.gd` as child controllers. Defer — this branch already changes one HUD state (`MALL_OVERVIEW` cash visibility) and adds CloseDayPreview wiring; restructuring on top of those changes would muddy the diff. |
| 815 | `game/scenes/ui/day_summary.gd` (modified this branch) | **Plan** — per-section renderers (cash, customers, milestones, comments) could each become a renderer node. Defer — needs a UI-snapshot test pass to verify visual parity. |
| 787 | `game/autoload/settings.gd` | **Plan** — settings I/O + audio-bus + input-binding sections. Clean split: keep core `settings.gd` as the autoload, extract `settings_persistence.gd` for cfg read/write. Defer — touches `user://settings.cfg` contract. |
| 782 | `game/tests/test_save_load_integration.gd` | **Justify** — integration test, intentionally exhaustive against the save format. Test files do not pay LOC tax the same way library code does. |
| 744 | `game/scripts/systems/order_system.gd` | **Plan** — supplier catalog, order placement, order tracking are three concerns; extract `order_catalog.gd`. Defer. |
| 730 | `game/scripts/systems/checkout_system.gd` | **Justify** — single owner of checkout lifecycle, autoload-level. Same reasoning as inventory_system. |
| 729 | `game/scenes/ui/inventory_panel.gd` (modified this branch) | **Plan** — render, context-menu actions, and stocking-mode wiring are separable. Clean split: extract `inventory_panel_actions.gd` (menu IDs 0–11). Defer — the `_shelf_actions` helper already exists for the placement subset; a parallel actions extraction is the next step. |
| 721 | `game/autoload/audio_manager.gd` | **Plan** — bus management vs. SFX vs. music are three concerns; the existing `audio_event_handler.gd` child node already covers signal-routing. Extract `audio_buses.gd`. Defer. |
| 720 | `game/scripts/systems/seasonal_event_system.gd` | **Justify** — owns seasonal event lifecycle as a single autoload. |
| 713 | `game/scripts/characters/shopper_ai.gd` | **Justify** — single AI state machine; splitting fragments the state graph. |
| 708 | `game/scripts/systems/ambient_moments_system.gd` | **Plan** — moment definitions could move to data (JSON under `game/content/`); the system itself would shrink. Defer — a content-extraction pass is its own work item. |
| 685 | `game/autoload/event_bus.gd` (modified this branch) | **Justify** — central signal hub by design (`docs/architecture.md` autoload row 3). Splitting it into category-specific buses would require every consumer to know which bus to listen to, which is explicitly the anti-pattern the single bus replaces. Adding signals one at a time is the intended growth path. |
| 679 | `game/scripts/world/storefront.gd` | **Justify** — storefront is the mall→store handoff contract surface; cohesive responsibility. |
| 667 | `game/scripts/systems/economy_system.gd` | **Justify** — economy formulas and cash bookkeeping have a single owner. |
| 666 | `game/scenes/ui/order_panel.gd` | **Plan** — paired with `order_system.gd`; same extraction shape. Defer with order_system. |
| 664 | `game/autoload/content_registry.gd` | **Justify** — typed catalogs accessor; cohesive. |
| 659 | `game/scripts/systems/performance_report_system.gd` | **Justify** — report aggregation is single-owner; splitting risks double-write on KPIs. |
| 659 | `game/scripts/characters/customer.gd` | **Justify** — customer entity behavior is cohesive. |
| 648 | `game/scripts/stores/electronics_store_controller.gd` | **Justify** — per-store controller, see sports_memorabilia. |
| 634 | `game/scenes/ui/settings_panel.gd` | **Plan** — paired with `settings.gd`. Defer with that extraction. |
| 631 | `game/scripts/stores/store_controller.gd` | **Justify** — base class for per-store controllers; defines the store contract. |
| 625 | `game/scripts/systems/haggle_system.gd` | **Justify** — haggle lifecycle is cohesive. |
| 592 | `game/scripts/systems/build_mode_system.gd` | **Justify** — build-mode is a discrete owned sub-state; cohesive. |
| 571 | `game/scripts/ui/action_drawer.gd` | **Justify** — action-drawer rendering is cohesive. |
| 570 | `game/scripts/stores/retro_games.gd` (modified this branch) | **Justify** — per-store controller (the store this branch primarily edits). LOC dropped slightly from this pass's loop-collapse but stays in the >500 band; per-store controllers are the canonical home for their store's logic. |
| 558 | `game/scripts/systems/store_state_manager.gd` | **Justify** — single owner of store state transitions. |
| 555 | `game/scripts/systems/tutorial_system.gd` | **Justify** — tutorial step state machine; cohesive. |
| 541 | `game/autoload/staff_manager.gd` | **Justify** — staff catalog autoload; cohesive. |
| 537 | `game/scripts/systems/pack_opening_system.gd` | **Justify** — pack-open is a single transactional surface. (See Escalation §E1 in `error-handling-report.md` for the rollback gap that still needs structural work — out of scope for cleanup.) |
| 532 | `game/scripts/systems/fixture_placement_system.gd` | **Justify** — build-mode sibling; cohesive. |
| 522 | `game/scripts/systems/random_event_system.gd` | **Justify** — event scheduler; cohesive. |
| 515 | `game/scripts/characters/customer_animator.gd` | **Justify** — animator wraps a single skeleton/mesh's worth of behavior. |
| 511 | `game/scripts/systems/meta_shift_system.gd` | **Justify** — meta-shift lifecycle; cohesive. |
| 503 | `game/autoload/reputation_system.gd` | **Justify** — reputation autoload; cohesive (see ownership doc). |

**Summary of extraction posture:** 11 files have a concrete extraction plan
deferred to follow-up structural passes. 30 files are justified at their
current size by the ownership-doc rule that each runtime responsibility have
exactly one owner — splitting them would create the multi-owner anti-pattern
the architecture is explicitly designed to prevent.

## Consistency edits (one line per file)

- `game/scripts/stores/retro_games.gd` — `## §F-41` doc-comment phrase
  `silent `continue` on a missing node` updated to `silent return on a
  missing node` to match the post-edit control flow (loop → guarded early
  return).

No other naming, formatting, or import-order drift was found in the modified
set; all files touched on this branch already match the surrounding style
(`gdlint` is enforced in CI via `lint-gdscript`).

## Escalations

No structural blockers were uncovered by this pass that require an external
decision. The one Medium-severity item this codebase carries
(`pack_opening_system.gd` rollback gap — `error-handling-report.md` §E1) is
out of cleanup-pass scope: it requires a `InventorySystem.register_item`
two-phase API redesign, which is architecture work, not cleanup.

## Verification

GUT suite re-run headlessly after edits:

```
Scripts           284
Tests             3571
  Passing         3571
Asserts           21311
---- All tests passed! ----
```

(Engine-shutdown RID/orphan warnings are the long-standing benign noise
documented in `docs/testing.md`; CI's `gut-tests` job filters them.)

---

## Pass 2 — `_format_thousands` consolidation

A second cleanup pass on the same date revisited the byte-identical 9-line
`_format_thousands` helper that lived in both `mall_overview.gd` and
`store_slot_card.gd`. The SSOT report's J-2 decision had marked this as
"keep both" until "a third or fourth call site appears, at which point a
`UIThemeConstants.format_thousands(int)` helper becomes the obvious owner."

Pass 2 acted on that exact path now rather than waiting for a third caller —
the cleanup-pass directive ("Duplicate utilities — consolidate. Pick one
canonical home, delete the duplicate, update callers") is the controlling
guidance, and `UIThemeConstants` is the canonical home the SSOT itself
named.

### Edits applied

- **`game/scripts/ui/ui_theme_constants.gd`** — added a single static helper
  `format_thousands(value: int) -> String` next to the other display
  formatting helpers, with a docstring noting that `hud.gd:_format_cash`
  remains its own function because the cents payload differs.
- **`game/scenes/mall/mall_overview.gd`** — removed the local
  `_format_thousands` copy (9 LOC) and updated the single call site in
  `_refresh_all_locked_states` to use
  `UIThemeConstants.format_thousands(cost)`.
- **`game/scenes/mall/store_slot_card.gd`** — removed the local
  `_format_thousands` copy (9 LOC) and updated `update_revenue` to use
  `UIThemeConstants.format_thousands(int(round(amount)))`.

Net LOC: −18 + ~12 = ~6 lines reduction. The two existing GUT tests that
verify the rendered output (`test_store_slot_card_revenue_label_updates`
asserts `"Cash: $123"`, `test_store_slot_card_revenue_label_thousands_separator`
asserts `"Cash: $1,234"`) pass unchanged because they observe the public
label string, not the helper function name. The thousands-grouping logic
moved one level up but emits the same strings.

### SSOT report follow-up

The SSOT report's J-2 risk-log entry now describes the *prior* state of the
codebase and the consolidation it predicted. A future SSOT pass should
either remove the J-2 entry or update its **Decision** to record that
consolidation has been done. This is a docs-only follow-up and does not
require code work.

### Verification

Headless GUT run after Pass 2:

```
Tests             4808
  Passing         4808
Asserts           27307
---- All tests passed! ----
```

The previous "3571 passing" snapshot above was from the original pass; the
suite has grown to 4808 tests as additional Day-1 coverage landed in this
branch (close-day preview, placement hint UI, save-load numeric hardening,
etc.). All pass.

### Items reconfirmed as Justify (no Pass-2 action)

These borderline items were re-evaluated and the prior **Justify** stands:

| # | Finding | Outcome | Why kept |
|---|---|---|---|
| J-A | `signal continue_pressed` in `day_summary.gd` is emitted but no listener connects to it | **Justify** | Public-surface signal contract on a UI scene. The cleanup-pass rule "no refactors that change call signatures of public API" applies — a scene's signal block is part of its observable surface even when the only emitter is internal. The signal is harmless; removing it is a reversible follow-up. |
| J-B | `_get_trend_multiplier` and `_get_market_event_multiplier` private wrappers in `economy_system.gd:165–170` are no longer called inside the file (the canonical implementation lives in `EconomyValueCalculator`) | **Justify** | The wrappers are kept alive only by `tests/validate_issue_001.sh`'s grep for `_get_market_event_multiplier` and `market_event_system.get_trend_multiplier`. Removing them requires a coordinated validator update so AC3 still verifies "EconomySystem.calculate_market_value() includes market event multiplier" against the new canonical location. The validator-coupled change is bigger than this cleanup pass should take on; flagged in the **Escalations** section below. |
| J-C | `STORE_TYPE` constant on `RetroGames` and `SportsMemorabiliaController` is unused internally — only `PocketCreaturesStoreController` actually uses both `STORE_ID` and `STORE_TYPE` (`initialize_store(STORE_ID, STORE_TYPE)`) | **Justify** | Public-API symmetry: the contract test `tests/gut/test_retro_games_controller.gd:test_store_type_constant` and the matching `test_sports_memorabilia_controller.gd` test assert the constant exists. Removing it would drop a documented public surface point. |
| J-D | Per-test-file `SCENE_PATH = "res://game/scenes/stores/retro_games.tscn"` repeated across 11 files | **Justify** | Already covered by Pass-1 finding #10. Each test file is self-contained; extracting a shared paths module would create coupling for one literal that is grep-able and not changing. |

## Escalations

In addition to the original `pack_opening_system.gd` rollback gap, Pass 2
identified one further item that needs coordinated cross-file work to act
on:

- **§E2 — `_get_trend_multiplier` / `_get_market_event_multiplier` dead
  wrappers in `economy_system.gd`.** The canonical implementation has moved
  to `EconomyValueCalculator.get_trend_multiplier` /
  `get_market_event_multiplier` (both static), but the wrappers in
  `economy_system.gd` are still referenced by `tests/validate_issue_001.sh`
  via grep on the *function name* and the `market_event_system.get_trend_multiplier`
  string (which only appears inside the dead wrapper).

  **Smallest concrete next action:** in a single PR, update
  `tests/validate_issue_001.sh` AC3 to grep
  `game/scripts/systems/economy_value_calculator.gd` for the canonical
  `get_market_event_multiplier` static, then delete the two private
  wrappers from `economy_system.gd`. Both edits ship together so CI sees
  no transient validator failure.

  **Why not done in this pass:** the cleanup pass scope explicitly forbids
  refactors that risk transient test failures, and the validator change
  shifts the AC3 contract surface from `economy_system.gd` to
  `economy_value_calculator.gd` — that's a controlled change worth a
  dedicated PR description rather than burying it in a cleanup pass.
