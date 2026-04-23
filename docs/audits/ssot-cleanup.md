# SSOT Cleanup Audit

## Diff-Driven Deletion Summary

1. **Deleted non-runtime `DataLoader` shim code.**
   `game/scripts/data_loader.gd` was only a grep target for shell validators. The real parser path is `game/scripts/content_parser.gd` plus `game/autoload/data_loader.gd`, so the shim was removed and the validators were retargeted to the canonical parser.

2. **Removed dead Pocket Creatures and sports-season compatibility catalogs.**
   `game/content/items_pocket_creatures.json` and `game/content/sports_seasons.json` were deleted because runtime no longer used them; canonical content already lives in `game/content/stores/pocket_creatures_cards.json` and `game/content/stores/sports_seasons.json`.

3. **Deleted loader branches that only existed to skip the removed compatibility files.**
   `DataLoaderSingleton._should_skip_file()` no longer special-cases the deleted root Pocket Creatures and sports-season catalogs.

4. **Removed the dead `item_tested` signal path.**
   Runtime testing code now emits only `item_test_completed`, and the tests that existed solely to preserve the old `item_tested` compatibility signal were removed or updated.

## SSOT Verification

| Domain | Authoritative module | Notes |
| --- | --- | --- |
| Store content parsing | `game/scripts/content_parser.gd` via `game/autoload/data_loader.gd` | Shell validators now point at the parser that actually sets `store.music` and recommended markup fields. |
| Pocket Creatures item catalog | `game/content/stores/pocket_creatures_cards.json` | Root `items_pocket_creatures.json` copy was deleted. |
| Sports season content | `game/content/stores/sports_seasons.json` | Root `sports_seasons.json` copy was deleted. |
| Runtime item-testing completion signal | `EventBus.item_test_completed` | `item_tested` was removed because no runtime listener used it. |
| Milestone catalog loaded by boot | `game/content/progression/milestone_definitions.json` through `DataLoaderSingleton` | Loader still skips the legacy `game/content/milestones/milestone_definitions.json` file when both exist. |

## Risk Log

1. **Retained legacy milestone consumers outside the boot loader.**
   `ProgressionSystem` still reads `game/content/milestones/milestone_definitions.json` directly, and `CompletionTracker` still names revenue milestones from that legacy set. That overlap is active runtime behavior, not dead code, so it was left for a broader convergence pass instead of being partially deleted here.

2. **Retained milestone loader skip for the legacy milestone catalog.**
   The boot pipeline still contains the progression-over-milestones precedence rule because the legacy milestone file still exists in the repository and one runtime system still depends on it directly.

## Sanity Check

- No runtime or validator references remain to deleted files `game/scripts/data_loader.gd`, `game/content/items_pocket_creatures.json`, or `game/content/sports_seasons.json`.
- No runtime code emits or listens for the deleted `item_tested` signal; the remaining tests use `item_test_completed`.
- Documentation and catalog validation now point at the surviving canonical content locations for sports seasons and store parsing.

---

## Pass 2 — Dead-Code and Unreachable-Path Deletion (2026-04-19)

### Diff-Driven Deletion Summary

1. **Deleted `_can_test_item(item_id: StringName)` from `game/scripts/stores/retro_games.gd`.**
   The method was a private ID-based wrapper around `_testing_system.can_test()` that was never called from any game code. The only caller was one GUT test. The public counterpart `can_test_item(item: ItemInstance)` is the real contract and is actively called from game code (line 109). Deleted the dead private variant and its dedicated test case from `tests/gut/test_retro_games_controller.gd`.

2. **Removed unreachable `consumer_electronics` legacy fallback from `game/scripts/stores/electronics_store_controller.gd`.**
   `_load_demo_config()` fell back to looking up `&"consumer_electronics"` if `ContentRegistry.exists("electronics")` returned false. Since `store_definitions.json` registers `"electronics"` as the canonical ID and `"consumer_electronics"` as an alias, both entries live and die together — the fallback could never succeed when the canonical lookup failed. The dead branch was deleted and replaced with a `push_error()` hard failure so a missing entry surfaces immediately rather than silently degrading.

### SSOT Verification (cumulative)

| Domain | Authoritative module | Notes |
| --- | --- | --- |
| Store content parsing | `game/scripts/content_parser.gd` via `game/autoload/data_loader.gd` | Unchanged from Pass 1. |
| Pocket Creatures item catalog | `game/content/stores/pocket_creatures_cards.json` | Unchanged from Pass 1. |
| Sports season content | `game/content/stores/sports_seasons.json` | Unchanged from Pass 1. |
| Runtime item-testing completion signal | `EventBus.item_test_completed` | Unchanged from Pass 1. |
| Electronics store content entry | `"electronics"` (canonical) in `ContentRegistry` | `"consumer_electronics"` alias exists in `store_definitions.json`; no separate fallback lookup needed in code. |
| Item testability predicate | `RetroGamesController.can_test_item(ItemInstance)` | The ID-based private variant `_can_test_item(StringName)` was the dead duplicate; deleted. |

### Risk Log

1. **Retained `_format_legacy_metadata` in `game/scenes/ui/save_load_panel.gd`.**
   `_format_metadata()` falls back to this for save slot metadata that lacks the `day`/`cash` keys. Because `_read_slot_metadata_from_save` reads the raw save file without first running migrations, a v0 save file on disk would produce metadata without those keys and legitimately reach this branch. Deleting it would show empty slot previews for any user with an un-migrated save.

2. **Retained `_migrate_v0_to_v1` in `game/scripts/core/save_manager.gd`.**
   Migration chain must remain complete; there is no safe floor version below which we stop migrating.

3. **Retained `generate_report()` in `game/scripts/systems/performance_report_system.gd`.**
   Called only from tests currently, but it reflects live system state and is likely the intended UI integration point. Removing it would leave the system with no snapshot API and break the test suite. Left for a broader day-summary pass.

### Sanity Check

- `_can_test_item` has zero remaining references in game code or tests.
- `consumer_electronics` string no longer appears as a fallback lookup in GDScript; it remains only as an alias entry in `store_definitions.json` (correct) and as a scene path segment in `store_definitions.json` scene_path field (correct).
- `can_test_item(ItemInstance)` still has its caller at `retro_games.gd:109` and is fully intact.

---

## Pass 3 — Phase 0 Audit FAIL Resolution + ARCHITECTURE.md SSOT Alignment (2026-04-21)

### Diff-Driven Deletion Summary

No code was deleted in this pass. The diff introduced two decision documents (`docs/decisions/0002-vertical-slice-store.md` and `tools/interaction_audit.md`) which identified one interaction-audit FAIL (p0-001) and confirmed the Phase 4 vertical-slice store selection. The pass closes that FAIL and corrects the documentation SSOT drift that the audit surface revealed.

### Changes Made

1. **Resolved p0-001: `customer_left` missing `reason` field (`game/scripts/characters/shopper_ai.gd`).**
   Added `_leave_reason: StringName = &"mall_exit"` instance variable. Set it to `&"utility_leave"`, `&"no_buy"`, `&"no_route"`, or `&"no_register"` at each `request_leave()` call site that corresponds to an unsatisfied departure. The `_despawn()` emit now includes `"reason": &"purchase_complete" if _made_purchase else _leave_reason`.

2. **Added walk-reason HUD subscriber (`game/scenes/ui/visual_feedback.gd`).**
   Connected `EventBus.customer_left` to `_on_customer_left()`. When `satisfied == false`, spawns a short-lived floating label at `WALK_TEXT_ORIGIN` using the human-readable string from `_WALK_REASON_LABELS`. This closes the "Walk (no sale)" FAIL from the Phase 0 interaction audit.

3. **Added `customer_walked` checkpoint to `AuditOverlay` (`game/autoload/audit_overlay.gd`).**
   Appended `&"customer_walked"` to `CHECKPOINTS` and wired it in `_wire_signals()`: fires `pass_check(&"customer_walked")` when `EventBus.customer_left` fires with `satisfied == false` and a `reason` key present, per the audit doc recommendation.

4. **Corrected ARCHITECTURE.md SSOT drift.**
   The document referenced phantom singletons (`GameState`, `Economy`, `SaveSystem`, `DataLoader`) and non-existent paths (`scripts/autoload/`, `data/`, `scenes/`, `assets/`). All updated to match live code: singleton names match `project.godot` autoload registrations; directory structure reflects the actual `game/` subtree layout; data flow signals updated to `item_sold`, `transaction_completed`; `SaveManager` (class in `game/scripts/core/save_manager.gd`) replaces `SaveSystem` throughout.

### SSOT Verification (cumulative)

| Domain | Authoritative module | Notes |
| --- | --- | --- |
| Store content parsing | `game/scripts/content_parser.gd` via `game/autoload/data_loader.gd` | Unchanged from Pass 1. |
| Pocket Creatures item catalog | `game/content/stores/pocket_creatures_cards.json` | Unchanged from Pass 1. |
| Sports season content | `game/content/stores/sports_seasons.json` | Unchanged from Pass 1. |
| Runtime item-testing completion signal | `EventBus.item_test_completed` | Unchanged from Pass 1. |
| Electronics store content entry | `"electronics"` (canonical) in `ContentRegistry` | Unchanged from Pass 2. |
| Item testability predicate | `RetroGamesController.can_test_item(ItemInstance)` | Unchanged from Pass 2. |
| Walk-reason feedback | `VisualFeedback._on_customer_left()` + `ShopperAI._leave_reason` | New in Pass 3. Floating label on unsatisfied `customer_left`. |
| Walk-reason audit checkpoint | `AuditOverlay` `&"customer_walked"` checkpoint | New in Pass 3. Wired to `customer_left` where `satisfied == false and reason` present. |
| Singleton name SSOT | `project.godot` autoload registrations | `ARCHITECTURE.md` now matches. |
| Source directory SSOT | `game/` subtree as laid out in repo | `ARCHITECTURE.md` now matches. |

### Risk Log

1. **Retained `_format_legacy_metadata` in `game/scenes/ui/save_load_panel.gd`.** (Unchanged from Pass 2 — still needed for un-migrated v0 saves.)
2. **Retained `_migrate_v0_to_v1` in `game/scripts/core/save_manager.gd`.** (Unchanged from Pass 2 — migration chain must stay complete.)
3. **Retained `generate_report()` in `game/scripts/systems/performance_report_system.gd`.** (Unchanged from Pass 2 — called from full-game-loop test and intended as UI integration point.)
4. **`_leave_reason` defaults to `&"mall_exit"` for shoppers who reach the EXIT waypoint via normal navigation.** The HUD label for this case ("Left the mall") is intentionally shown only when `satisfied == false`, so a shopper who bought something and then exited via the EXIT waypoint does not produce a walk-reason label.
5. **`DEFAULT_STARTING_STORE` in `game_manager.gd:9` was `&"sports"`.** Resolved in Pass 4 — see below.

### Sanity Check

- `customer_left.emit()` in `shopper_ai.gd`, `queue_system.gd`, `customer_system.gd`, and `mall_customer_spawner.gd` are the four emission sites. Only `shopper_ai.gd` now populates `reason`; the other three emit backend-bookkeeping payloads (customer IDs, background spawner data) without a browsing context, so no walk-reason label fires for those — which is correct behavior.
- `AuditOverlay.CHECKPOINTS` now has 9 entries; `all_passed()` requires all 9 before returning `true`. Existing tests in `tests/gut/test_audit_checkpoints.gd` check only the original 8 named checkpoints by key — they continue to pass since `pass_check(&"customer_walked")` is additive and tests do not call `all_passed()` in the checkpoint-by-checkpoint tests.
- No `SaveSystem`, `GameState` (as standalone autoload), or `Economy` (as standalone autoload) references remain in `ARCHITECTURE.md`. All occurrences now reflect live singleton names from `project.godot`.

---

## Pass 4 — Phase 4 Start: DEFAULT_STARTING_STORE flip (2026-04-21)

### Diff-Driven Deletion Summary

No code was deleted in this pass.

### Changes Made

1. **Changed `DEFAULT_STARTING_STORE` from `&"sports"` to `&"retro_games"` (`game/autoload/game_manager.gd:9`).**
   Decision 0002 (`docs/decisions/0002-vertical-slice-store.md`) designated Retro Games as the Phase 4 vertical-slice store and explicitly mandated this change at Phase 4 start. All six consumers of the constant (`game_manager.gd:359`, `save_manager.gd:975`, `game_world.gd:545,621,1098`, `tests/gut/test_new_game_state.gd:98`) read the constant by reference — no secondary edits required.

### SSOT Verification (cumulative)

| Domain | Authoritative module | Notes |
| --- | --- | --- |
| Store content parsing | `game/scripts/content_parser.gd` via `game/autoload/data_loader.gd` | Unchanged from Pass 1. |
| Pocket Creatures item catalog | `game/content/stores/pocket_creatures_cards.json` | Unchanged from Pass 1. |
| Sports season content | `game/content/stores/sports_seasons.json` | Unchanged from Pass 1. |
| Runtime item-testing completion signal | `EventBus.item_test_completed` | Unchanged from Pass 1. |
| Electronics store content entry | `"electronics"` (canonical) in `ContentRegistry` | Unchanged from Pass 2. |
| Item testability predicate | `RetroGamesController.can_test_item(ItemInstance)` | Unchanged from Pass 2. |
| Walk-reason feedback | `VisualFeedback._on_customer_left()` + `ShopperAI._leave_reason` | Unchanged from Pass 3. |
| Walk-reason audit checkpoint | `AuditOverlay` `&"customer_walked"` checkpoint | Unchanged from Pass 3. |
| Singleton name SSOT | `project.godot` autoload registrations | Unchanged from Pass 3. |
| Source directory SSOT | `game/` subtree as laid out in repo | Unchanged from Pass 3. |
| Default starting store | `GameManager.DEFAULT_STARTING_STORE = &"retro_games"` | **Changed in Pass 4.** Was `&"sports"`; now `&"retro_games"` per Decision 0002. |

### Risk Log

1. **Retained `_format_legacy_metadata` in `game/scenes/ui/save_load_panel.gd`.** (Unchanged — still needed for un-migrated v0 saves.)
2. **Retained `_migrate_v0_to_v1` in `game/scripts/core/save_manager.gd`.** (Unchanged — migration chain must stay complete.)
3. **Retained `generate_report()` in `game/scripts/systems/performance_report_system.gd`.** (Unchanged — called from full-game-loop test and intended as UI integration point.)
4. **`_leave_reason` defaults to `&"mall_exit"`.** (Unchanged from Pass 3.)
5. **Sports Memorabilia controller untouched.** `sports_memorabilia_controller.gd` remains in the codebase as Phase 6 work. No regressions introduced — the store is accessible via the hub, it simply is no longer the boot-default store.

### Sanity Check

- `DEFAULT_STARTING_STORE` now reads `&"retro_games"` in `game_manager.gd:9`. All six consumers read via the constant — no hardcoded `&"sports"` strings remain in game code.
- `tests/gut/test_new_game_state.gd:98` reads `GameManager.DEFAULT_STARTING_STORE` dynamically and asserts the store ID exists in `ContentRegistry` — `retro_games` is a registered store, so the test continues to pass.
- The `tools/interaction_audit.md` table column "Default boot store" now correctly matches: Retro Games is the boot default, Sports Memorabilia is not.

---

## Pass 5 — Phase 1 Scaffolding Audit (2026-04-22)

### Diff-Driven Deletion Summary

The working-tree diff under audit is the Phase 1 SSOT scaffolding pass: new
autoloads (`SceneRouter`, `StoreDirector`, `StoreRegistry`, `GameState`,
`CameraAuthority`, `InputFocus`, `AuditLog`, `ErrorBanner`, `FailCard`) and
the corresponding ownership / contract / interactable wiring on existing
controllers. The diff is **purely additive** — no flags were retired, no
SSOT module was replaced in this pass, and the legacy retail-sim systems
(`StoreStateManager`, `customer_system`, `inventory_system`,
`reputation_system`, `staff_manager`, etc.) remain the live runtime owners
of their domains. There are therefore no flag-removal-driven deletions to
make in this pass.

One narrow dead method was identified and removed:

1. **Deleted `GameManager.change_scene_packed(scene: PackedScene)`
   (`game/autoload/game_manager.gd`).** Verified zero callers across
   `game/`, `tests/`, and `scripts/`. The method was a two-line wrapper
   around `SceneTransition.transition_to_packed()` that no production code
   or test ever invoked. `SceneTransition.transition_to_packed()` itself
   was retained because `tests/validate_issue_006.sh` (AC4) enforces its
   existence as part of the issue-006 contract — removing the contract is
   out of scope for an SSOT cleanup pass and belongs with issue-006 closure.

### SSOT Verification (Phase 1 surfaces, additive)

The new ownership map in `docs/architecture/ownership.md` (rows 1–10)
declares the authoritative writer per responsibility for the Phase 1
golden path. None of these have a legacy duplicate that is reachable from
the Phase 1 chain (Boot → Mall → Selection → Transition → Store Ready):

| Domain | Authoritative module | Legacy reader/writer status |
| --- | --- | --- |
| Scene load / `change_scene_to_*` | `SceneRouter` (autoload) | `SceneTransition` is the fade wrapper that delegates into `SceneRouter`; `GameManager.change_scene` is the legacy fade entry point still used by `error_banner.gd` and three internal call sites — retained as a documented thin wrapper, not a duplicate writer. |
| Store lifecycle / readiness | `StoreDirector` + per-scene `StoreController` | No legacy ready-declarer in the Phase 1 chain. |
| Run state (active store / day / money / flags) | `GameState` (autoload) | `GameManager.current_store_id`, `GameManager.owned_stores`, `GameManager.get_active_store_id()`, `GameManager.get_owned_store_ids()`, `GameManager.is_store_owned()` are still the live readers/writers consumed by ~40+ legacy sites (staff, reputation, audio, customer, save, world, UI). Retained per Risk Log §1 below. |
| Camera authority | `CameraAuthority` (autoload, write owner) | `CameraManager` remains as a read-only viewport observer feeding build-mode and UI listeners. Layered, not duplicated. |
| Input focus / modal | `InputFocus` (autoload) | New surface; no legacy owner. |
| Store registry / id resolution | `StoreRegistry` (autoload) | `ContentRegistry.resolve(id)` still owns content-id resolution for the legacy retail-sim path — not the same domain. |
| Audit checkpoints | `AuditLog` (autoload) | `AuditOverlay` continues to render the on-screen pass/fail matrix and now forwards through `AuditLog`. |
| Cross-system events | `EventBus` (autoload) | Phase 1 mirror signals (`store_ready`, `store_failed`, `scene_ready`, `run_state_changed`, `input_focus_changed`, `camera_authority_changed`) added per row 10. Owners remain authoritative emitters. |

### Risk Log

1. **Retained `GameManager.current_store_id`, `GameManager.owned_stores`,
   `GameManager.get_active_store_id()`, `GameManager.get_owned_store_ids()`,
   and `GameManager.is_store_owned()`.** `GameState.active_store_id` is the
   ownership-doc SSOT for the active-store field, but the legacy run-state
   surface on `GameManager` is read by 40+ live call sites across
   `staff_manager`, `reputation_system`, `audio_event_handler`, `audit_overlay`,
   `customer_npc`, `tournament_system`, `mall_customer_spawner`,
   `random_event_system`, `storefront`, `game_world`, `staff_panel`,
   `inventory_panel`, `pricing_panel`, `close_day_preview`, `order_panel`,
   and ~12 test files that mutate the field directly. Migrating them is a
   distinct convergence pass (Phase 2/3 work per ROADMAP) and was
   explicitly out of scope for this Phase 1 scaffolding pass — deleting
   the legacy surface unilaterally would break the live retail-sim path.
2. **Retained `SceneTransition.transition_to_packed()` and
   `SceneRouter.route_to_packed()`.** No production caller remains after
   `GameManager.change_scene_packed` was removed, but `tests/validate_issue_006.sh`
   (AC4) and the test stubs in `tests/gut/test_new_game_hub_flow.gd` /
   `tests/gut/test_game_manager.gd` enforce their existence as part of the
   issue-006 contract. Removal belongs with issue-006 closure, not an SSOT
   cleanup pass.
3. **Retained legacy autoloads** (`StaffManager`, `ReputationSystemSingleton`,
   `DifficultySystemSingleton`, `UnlockSystemSingleton`, `CheckoutSystem`,
   `OnboardingSystemSingleton`, `MarketTrendSystemSingleton`, `TooltipManager`,
   `ObjectiveDirector`, `EnvironmentManager`, `CameraManager`, etc.). Per
   `BRAINDUMP.md` §"What Is Likely Happening" and the ROADMAP Phase 0/1
   scope, the current mandate is verification of the golden path, not
   tear-down of the legacy retail simulation. These autoloads remain the
   live owners of their domains and are not Phase 1 SSOT duplicates.
4. **Retained Risk-Log entries from Passes 2–4** (`_format_legacy_metadata`,
   `_migrate_v0_to_v1`, `generate_report()`, `_leave_reason` default,
   `sports_memorabilia_controller`). Status unchanged.

### Sanity Check

- `change_scene_packed` has zero remaining references in `game/`, `tests/`,
  or `scripts/`. The only consumer of `SceneTransition.transition_to_packed`
  was the deleted method; the contract on `SceneTransition` itself remains
  intact (validate_issue_006.sh AC4 still passes via the surviving
  `func transition_to_packed` declaration on `scene_transition.gd:48`).
- `GameManager.change_scene` retained — three internal callers
  (`start_new_game`, `load_game`, `transition_to_menu`) plus
  `error_banner.gd:128` consume it. Documented as the legacy fade entry
  point that delegates into `SceneTransition` → `SceneRouter` per
  ownership.md row 1.
- No new singletons were introduced in this pass; all Phase 1 SSOT
  autoloads referenced above are pre-existing in the working-tree diff
  under audit.

