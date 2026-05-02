# Cleanup Report — 2026-05-02

**Scope:** code-quality cleanup pass on the working-tree state ahead of
commit. Two passes ran on this date:

* **Pass 1** — initial dead-code sweep + first attempt at "broken-link"
  cleanup after the audit-report consolidation.
* **Pass 2** (this pass) — citation-consistency repair after re-reading
  the audit-report set. Pass 1 stripped citations under the assumption
  that `security-report.md` and `ssot-report.md` had been deleted, but
  both still exist as active reports (modified, not deleted) and still
  carry §F-NN / "Risk log" indexes that link back to source. Pass 2
  restores the bidirectional links that Pass 1 over-trimmed and corrects
  one wrong repoint to a different report.

**Verification:** `bash tests/run_tests.sh` after Pass 2 — **4858/4858
GUT tests pass, 0 failures, 1 warning** (canvas RID leak unrelated to
this branch). All SSOT tripwires green
(`validate_translations.sh`, `validate_single_store_ui.sh`,
`validate_tutorial_single_source.sh`, ISSUE-009 SceneRouter sole-owner,
ISSUE-016 15/15). Pre-existing validator failures (ISSUE-018, ISSUE-023,
ISSUE-024, ISSUE-154, ISSUE-239) are on `main` ahead of this branch and
do not touch the files edited in either pass.

---

## Changes made this pass

### Citation-consistency repair

Pass 1 stripped six in-source `§F-NN` cites on the basis that the
referenced reports had been deleted. After re-reading `docs/audits/`,
only the dated `2026-05-01-audit.md` was deleted at the time of Pass 2;
`security-report.md` and `ssot-report.md` are present, fresh on
2026-05-02, and still publish §F-NN indexes that reverse-point at code.
(`docs-consolidation.md` was also absent during Pass 2 and has since been
re-created by the subsequent docs-consolidation pass; that re-creation
does not change the citation-restoration decisions made here.) Pass 2
restores the live links and corrects one mis-targeted repoint.

| Path | Edit | Why |
|---|---|---|
| `game/scripts/systems/tutorial_system.gd:43` | Restored `See docs/audits/security-report.md §F1.` on the `MAX_PROGRESS_FILE_BYTES` cap. | `security-report.md` index row §F1 explicitly reverse-points at `tutorial_system.gd:43`; without the inline tag the bidirectional link is half-broken. |
| `game/scripts/systems/tutorial_system.gd:47` | Restored `See docs/audits/security-report.md §F2.` on the `MAX_PERSISTED_DICT_KEYS` cap. | Same — `security-report.md` index row §F2 reverse-points at `tutorial_system.gd:47`. |
| `game/scripts/systems/tutorial_system.gd:405` | Restored `See security-report.md §F1.` on the `_load_progress` size pre-check. | Same hardening surface as the const cap; the §F1 cite is the canonical pointer. |
| `game/scripts/systems/tutorial_system.gd:476` | Restored `See security-report.md §F2.` on the `_apply_state` `completed_steps` cap. | Same — both dict caps share §F2. |
| `game/scripts/systems/tutorial_system.gd:504` | Restored `See security-report.md §F2.` on the `_apply_state` `tips_shown` cap. | Same — both dict caps share §F2. |
| `tests/gut/test_save_load_numeric_hardening.gd:5` | Repointed `See docs/audits/error-handling-report.md §F-09.` back to `security-report.md §F-09`. | Pass 1 sent this to `error-handling-report.md`, but that report's §F-09 is about `data_loader.gd::_record_load_error` push_warning. The save-load NaN/Inf hardening lives in `security-report.md` (Prior-passes line: "§F-09 — save-load numeric hardening"), with sub-rows F-09.1 / F-09.2 / F-09.10–F-09.19. The Pass 1 repoint was to the wrong report. |
| `docs/index.md` | Rewrote the Audit-notes block to list `security-report.md` and `ssot-report.md` as standalone active reports. Pass 1 wrote "earlier `cleanup-report.md`, `security-report.md`, and `docs-consolidation.md` passes have been folded into this single report" but only the docs-consolidation report had actually been folded at that time. | The index now reflects the actual `docs/audits/` directory contents. |
| `docs/roadmap.md:46` | Repointed the Phase-2 SSOT-outcomes link back from `error-handling-report.md` to `ssot-report.md`. | Pass 1 redirected this on the assumption `ssot-report.md` had been deleted; it still exists and is the canonical home for SSOT outcomes (the file's title is literally "SSOT Enforcement Pass"). |

### Cites Pass 1 stripped that **stay stripped** (correct after re-check)

| Path / line | Stripped cite | Why this stays as Pass 1 left it |
|---|---|---|
| `game/scripts/systems/tutorial_system.gd:466` (now :465 area) | `; see docs/audits/security-report.md §3 finding 1.` | The current `security-report.md` indexes by `§F-NN` / `§SR-NN` / `§DR-NN`, not `§3 finding N`. The cite was syntactically stale. WHY content (`_resolve_resume_step` clamp note) is preserved verbatim. |
| `game/autoload/settings.gd:145` | `; see docs/audits/ssot-report.md "Risk log" for the known parallel-CRT divergence` | `ssot-report.md` "Risk log" no longer carries an entry for parallel-CRT divergence (the surviving rows are `_sync_to_camera_authority`, orbit-controller subtree, `_resolve_store_id`, `set_current_interactable`, `ProvenancePanel`, deleted-report breadcrumbs). The cite was a real dead link. Pass 1's replacement clause "(parallel-CRT divergence is a known limitation)" preserves the WHY without the broken pointer. |
| `game/autoload/settings.gd:339` | `See security-report.md §F4.` | `security-report.md` does not list `§F4` in its index (only §F1, §F2, §F-04..§F-29, §F-57). The cite was orphan. WHY (TOCTOU note) preserved verbatim. |
| `game/scenes/ui/inventory_panel.gd:244` | `— see docs/audits/security-report.md §F3.` | Same — `§F3` is not in the security-report index. Orphan cite. |
| `tests/gut/test_day_summary_occlusion.gd:9` | `Tracked in docs/audits/ssot-report.md "Risk log".` | `ssot-report.md` "Risk log" no longer covers the tutorial-band/day_summary occlusion. Cite was a dead link. WHY preserved. |

### Cites Pass 1 already handled and Pass 2 leaves alone

`game/scripts/stores/retro_games.gd:698` (the F3 debug-toggle §F-58 cite)
and the §F-65 `_toggle_debug_overhead_camera` annotation set were added
or renumbered by `error-handling-report.md` Pass 9 in the same
working-tree change set; they are correct against the live
`error-handling-report.md` index.

---

## Files still >500 LOC

The repo contains 39 GDScript files over 500 LOC. Pass 2 makes no
splits; Pass 1's per-file dispositions are still accurate and the
edits in this pass touch comments and docs, not size. The full table
from Pass 1 is reproduced below for continuity.

| LOC | File | Disposition |
|---|---|---|
| 1567 | `game/scenes/world/game_world.gd` | **Justify.** Top of the file is 33 `const _*_PANEL_SCENE: PackedScene = preload(...)` declarations + ~30 `@onready var <system>: <Type> = $<Node>` lines wiring this scene root to its child systems. The body is the documented Tier-1..Tier-5 init machine plus the hub-mode injector callable. A registry-extraction would force every panel/system reference through an indirection layer, which crosses the "don't change call signatures" rule. The file already carries `# gdlint:disable=max-file-lines` at the top. **Concrete extraction plan for a future pass:** move the panel `_setup_deferred_panels` body into a `GameWorldPanelLoader` helper Node (input: `_ui_layer`, output: stored panel references); ~150 LOC reduction without changing the public surface of `GameWorld`. |
| 1368 | `game/scripts/core/save_manager.gd` | **Justify.** Save format owns ~30 system snapshots; each `set_*_system` setter and its corresponding serializer/deserializer is a single cohesive unit. Splitting per-system would multiply file count without reducing complexity at any single call site. Save-format migration logic is the legitimate driver of the size. |
| 1059 | `game/autoload/data_loader.gd` | **Justify.** JSON-content loader; one method per content category. The `load_*` family is the canonical surface used by `ContentRegistry`; pulling categories into separate files would force the loader to round-trip through a registry layer it currently sidesteps. |
| 1044 | `game/scripts/stores/sports_memorabilia_controller.gd` | **Justify.** Per-store controller carrying the season-cycle, condition-picker, authentication-risk, and price-multiplier flows that constitute the store's signature mechanic. Each chunk depends on the controller's `_inventory_system` / `_economy_system` / `_reputation` references; an extracted helper would receive the same five+ refs as parameters. |
| 979 | `game/scripts/stores/video_rental_store_controller.gd` | **Justify.** Same pattern as sports memorabilia — per-store controller for the rental loop (tape wear, late fees, overdue processing). |
| 945 | `game/scripts/content_parser.gd` | **Justify.** Schema-validated JSON parsing for every content category. Splitting per-category would mirror the `data_loader.gd` rationale above. |
| 914 | `game/scenes/ui/hud.gd` | **Justify.** HUD aggregates ~12 independent counter widgets + objective rail + close-day preview; each widget has its own `_refresh_*` / `_update_*_display` / signal-handler triplet. Extracting would multiply files without consolidating logic. |
| 907 | `game/scripts/systems/customer_system.gd` | **Justify.** Customer FSM with shopping/queueing/leaving phases plus performance counters. The state machine is the file. |
| 896 | `game/scripts/systems/inventory_system.gd` | **Justify.** Inventory ownership matrix (backroom + shelves) with assignment/lookup invariants. Splitting backroom vs shelf would break the canonical "single owner" rule the system enforces. |
| 830 | `game/scenes/ui/day_summary.gd` | **Justify.** Modal report rendering with multiple stat panels. |
| 787 | `game/autoload/settings.gd` | **Justify.** Single autoload owning every persisted preference + the `_safe_load_config` hardening. |
| 765 | `game/scripts/stores/retro_games.gd` | **Justify.** Per-store controller — same rationale as sports/rentals/electronics. |
| 744 | `game/scripts/systems/order_system.gd` | **Justify.** Order pipeline + supplier book + delivery scheduling; one orchestrator. |
| 733 | `game/scripts/systems/checkout_system.gd` | **Justify.** Checkout owns queue / haggle / warranty hand-offs; splitting would require all hand-offs through a router. |
| 729 | `game/scenes/ui/inventory_panel.gd` | **Justify.** Inventory panel with multiple controller-specific renderers (rental, electronics, pack opening, refurbishment) — each branch already gates on whether its system reference is set. |
| 721 | `game/autoload/audio_manager.gd` | **Justify.** Audio bus + stream manager + SFX hooks. |
| 720 | `game/scripts/systems/seasonal_event_system.gd` | **Justify.** Season state machine with event-pool + price-modifier table per season. |
| 720 | `game/scripts/systems/economy_system.gd` | **Justify.** Cash + revenue + day-end summary owner. |
| 713 | `game/scripts/characters/shopper_ai.gd` | **Justify.** NPC FSM that drives the customer agent (intent → browse → consider → checkout). |
| 708 | `game/scripts/systems/ambient_moments_system.gd` | **Justify.** Ambient moments registry + trigger evaluator + cooldown bookkeeping. |
| 685 | `game/autoload/event_bus.gd` | **Justify.** Single signal hub by design (autoload row 3 in `architecture.md`). The size is the public surface. |
| 682 | `game/scripts/world/storefront.gd` | **Justify.** Hallway storefront card with hover/focus/selection state, accent banding, and quarantine flip. |
| 677 | `game/autoload/content_registry.gd` | **Justify.** Single typed-catalog + alias-resolution autoload. |
| 666 | `game/scenes/ui/order_panel.gd` | **Justify.** Order placement UI with supplier filtering + cost preview. |
| 659 | `game/scripts/systems/performance_report_system.gd` | **Justify.** Daily report generator with N panels per day. |
| 659 | `game/scripts/characters/customer.gd` | **Justify.** Customer scene root + animator hooks + interaction surface. |
| 648 | `game/scripts/stores/electronics_store_controller.gd` | **Justify.** Per-store controller — warranty manager + demo unit + electronics-specific pricing. |
| 634 | `game/scenes/ui/settings_panel.gd` | **Justify.** Single settings panel for all `Settings` autoload preferences. |
| 631 | `game/scripts/stores/store_controller.gd` | **Justify.** Base class for all store controllers; the size is the contract. |
| 625 | `game/scripts/systems/haggle_system.gd` | **Justify.** Haggle FSM with reputation-driven bands + per-state evaluators. |
| 592 | `game/scripts/systems/build_mode_system.gd` | **Justify.** Build-mode placement loop + grid + transition. |
| 571 | `game/scripts/ui/action_drawer.gd` | **Justify.** Per-store action-drawer router. |
| 558 | `game/scripts/systems/store_state_manager.gd` | **Justify.** Per-store snapshot owner with lease + restore lifecycle. |
| 552 | `game/scripts/systems/tutorial_system.gd` | **Justify.** Tutorial FSM with persisted progress + 9 steps. |
| 541 | `game/autoload/staff_manager.gd` | **Justify.** Staff schedule + cost rollup autoload. |
| 537 | `game/scripts/systems/pack_opening_system.gd` | **Justify.** Pocket Creatures pack-opening loop. |
| 532 | `game/scripts/systems/fixture_placement_system.gd` | **Justify.** Build-mode placement + footprint validation. |
| 522 | `game/scripts/systems/random_event_system.gd` | **Justify.** Random-event scheduler + outcome table. |
| 515 | `game/scripts/characters/customer_animator.gd` | **Justify.** Customer animation state mapper. |

The single concrete extraction proposal in the table above
(`game_world.gd` → `GameWorldPanelLoader`) is the lowest-risk candidate
if a future pass is permitted to introduce a helper Node. Every other
entry is cohesive enough that a split would split logic, not file size.

---

## Considered but not changed (with reason)

- **Pass 1 dead-code edit (`crosshair.gd:8` unused `_label`).** Already
  removed by Pass 1; verified the file (now 30 lines) reads the
  reticle's `+` glyph straight from the .tscn and the GUT tests look
  the label up via `get_node("CenterContainer/Label")`. No further
  action.
- **Duplicate `_resolve_store_id` helper across 5 files**
  (`inventory_system.gd:35`, `economy_system.gd:570`,
  `store_selector_system.gd:404`, `order_system.gd:677`,
  `reputation_system.gd:326`). Each instance has subtly different
  fallback semantics: `inventory_system` and `economy_system` gate on
  `ContentRegistry.exists(raw)` before resolving; `store_selector_system`
  resolves directly; `order_system` falls back to a cached
  `_active_store_id`; `reputation_system` returns `String` instead of
  `StringName` and falls back to `GameManager.get_active_store_id()`.
  Consolidating would be a behavioral change. **Out of scope for this
  no-behavior-change pass; left as-is.** The cleanest unblock is a
  `StoreIdResolver` static helper exposing one named function per
  fallback policy, with each call site opting into a policy explicitly.
  Also tracked under `ssot-report.md` "Risk log".
- **`StorePlayerBody.set_current_interactable` test seam**
  (`store_player_body.gd:162`) has zero callers in production or tests.
  Removing a public method is technically an API change and the seam is
  documented in `error-handling-report.md` §F-54. A future pass with
  explicit license to drop unused public methods could remove it.
- **`ProvenancePanel`** (`game/scenes/ui/provenance_panel.gd`/`.tscn`)
  has no production-side instantiation reachable from `game_world.gd`
  or any other scene; only `tests/gut/test_provenance_panel.gd`
  references it. The panel's content (acquisition / condition / grade
  history) is referenced from the design docs as a planned in-game
  surface. Left as-is until the design intent is confirmed; a future
  pass with that confirmation can decide to delete or wire up.
- **Audit-log `print()` lines** (`audit_log.gd:29,44`,
  `audit_overlay.gd:75`, `scene_router.gd:131`, `store_director.gd:291,299`,
  `fail_card.gd:143,151`) are intentional audit-trail emissions that
  other parts of the system grep for in CI. Not stale.
- **`store_controller.gd:601` `print("[dev-fallback] …")`** is inside
  `dev_force_place_test_item`, which is already gated by
  `OS.is_debug_build()` at line 553 and exists specifically as a
  development unblock. Not stale.

## Escalations

None. Every Pass 2 finding either acted (citation restoration / wrong
repoint correction) or justified (cites that stayed stripped because
the target index entry never existed or no longer covers the
referenced surface).
