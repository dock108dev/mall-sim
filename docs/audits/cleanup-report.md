# Cleanup Report

## Scope

This pass stayed behavior-safe and deliberately avoided the unrelated in-flight
runtime/docs changes already present in the worktree. The cleanup focused on
test-suite consistency: removing repeated local disconnect helpers, reusing the
existing shared helper, and refreshing the large-file inventory instead of
forcing risky runtime extractions.

## Dead code removed

| File | Cleanup |
| --- | --- |
| `tests/integration/test_build_mode_placement.gd` | Removed the file-local `_safe_disconnect()` helper after switching teardown to the shared helper. |
| `tests/integration/test_difficulty_hard_mode_purchase_probability.gd` | Removed the file-local `_safe_disconnect()` helper after switching teardown to the shared helper. |
| `tests/integration/test_fixture_upgrade_persistence.gd` | Removed the file-local `_safe_disconnect()` helper after switching teardown to the shared helper. |
| `tests/gut/test_checkout_autoload.gd` | Removed the file-local `_safe_disconnect()` helper after switching teardown to the shared helper. |
| `tests/gut/test_queue_system_wiring.gd` | Removed the file-local `_safe_disconnect()` helper after switching teardown to the shared helper. |
| `tests/unit/test_checkout_system.gd` | Removed the file-local `_safe_disconnect()` helper after switching teardown to the shared helper. |
| `tests/unit/test_day_cycle_controller.gd` | Removed the file-local `_safe_disconnect()` helper after switching teardown to the shared helper. |
| `tests/unit/test_returns_bin.gd` | Removed the file-local `_safe_disconnect()` helper after switching teardown to the shared helper. |

## Files refactored

| File | Change |
| --- | --- |
| `game/tests/test_signal_utils.gd` | Clarified that the shared typed `safe_disconnect()` helper is the canonical teardown helper for both test trees. |
| `tests/integration/test_build_mode_placement.gd` | Reused `TEST_SIGNAL_UTILS.safe_disconnect()` for fixture-placement signal cleanup. |
| `tests/integration/test_difficulty_hard_mode_purchase_probability.gd` | Reused `TEST_SIGNAL_UTILS.safe_disconnect()` for checkout difficulty signal cleanup. |
| `tests/integration/test_fixture_upgrade_persistence.gd` | Reused `TEST_SIGNAL_UTILS.safe_disconnect()` for fixture save/load signal cleanup. |
| `tests/gut/test_checkout_autoload.gd` | Reused `TEST_SIGNAL_UTILS.safe_disconnect()` for checkout autoload signal cleanup. |
| `tests/gut/test_queue_system_wiring.gd` | Reused `TEST_SIGNAL_UTILS.safe_disconnect()` for queue wiring signal cleanup. |
| `tests/unit/test_checkout_system.gd` | Reused `TEST_SIGNAL_UTILS.safe_disconnect()` for sale receipt signal cleanup. |
| `tests/unit/test_day_cycle_controller.gd` | Reused `TEST_SIGNAL_UTILS.safe_disconnect()` for bankruptcy/day-start signal cleanup. |
| `tests/unit/test_returns_bin.gd` | Reused `TEST_SIGNAL_UTILS.safe_disconnect()` for late-fee signal cleanup. |

## Consistency changes made

- Standardized the helper constant name to `TEST_SIGNAL_UTILS` in the updated
  `tests/` files so teardown code now matches the existing `game/tests`
  convention.
- Kept all shared disconnect paths on the existing typed
  `safe_disconnect(sig: Signal, callable: Callable)` helper instead of
  maintaining more file-local copies with identical logic.
- Updated the shared helper comment so its intent matches current usage across
  both test trees, making the "why" visible at the declaration site.

## Files still over 500 LOC

These files were inventoried and flagged for follow-up rather than split during
this pass. The goal here was to avoid behavior changes in core runtime systems,
large scenario-heavy tests, and vendored GUT code.

| LOC | File | Follow-up |
| ---: | --- | --- |
| 1759 | `addons/gut/test.gd` | Vendored GUT code; leave untouched unless updating the dependency. |
| 1226 | `game/scenes/world/game_world.gd` | Runtime orchestrator; extract UI/bootstrap helpers only in a dedicated gameplay pass. |
| 1224 | `addons/gut/gut.gd` | Vendored GUT code; leave untouched unless updating the dependency. |
| 1129 | `game/scripts/core/save_manager.gd` | Persistence hotspot; split only with save/load regression coverage. |
| 1021 | `game/autoload/data_loader.gd` | Core boot/content pipeline; refactor under focused loader work. |
| 879 | `game/scripts/content_parser.gd` | Good candidate for format-specific parser helpers. |
| 870 | `game/scripts/systems/customer_system.gd` | Extract spawn/decision helpers in a dedicated gameplay pass. |
| 846 | `game/scripts/systems/inventory_system.gd` | Central state owner; split only with inventory regression coverage. |
| 782 | `game/tests/test_save_load_integration.gd` | Large integration suite; safe target for fixture/helper extraction. |
| 776 | `tests/gut/test_shopper_ai.gd` | Large scenario suite; split by shopper behavior families. |
| 743 | `game/scripts/systems/order_system.gd` | Multi-responsibility runtime script; extract supplier/cart helpers later. |
| 720 | `tests/gut/test_order_system.gd` | Large test matrix; split by ordering path. |
| 707 | `game/scripts/characters/shopper_ai.gd` | Candidate for state/behavior helper extraction. |
| 697 | `tests/gut/test_customer_spawn_scheduling.gd` | Large scheduler matrix; split by spawn scenario. |
| 679 | `game/scripts/world/storefront.gd` | Mixed world-building logic; extract presentation helpers later. |
| 667 | `game/autoload/audio_manager.gd` | Core autoload; isolate player-pool helpers in a future pass. |
| 666 | `game/scenes/ui/order_panel.gd` | Large UI script; extract row/build helpers carefully. |
| 655 | `game/scripts/systems/checkout_system.gd` | Runtime-critical; split only with checkout regression coverage. |
| 653 | `game/autoload/settings.gd` | Persistence/wiring hotspot; refactor with settings coverage. |
| 642 | `game/scripts/systems/ambient_moments_system.gd` | Candidate for scheduler/history helper extraction. |
| 638 | `game/scripts/systems/secret_thread_system.gd` | Candidate for state-transition helper extraction. |
| 628 | `game/scripts/characters/customer.gd` | Candidate for movement/state helper extraction. |
| 627 | `game/scripts/systems/seasonal_event_system.gd` | Candidate for calendar/config helpers. |
| 625 | `tests/gut/test_mall_hallway_scene.gd` | Large scene-contract suite; split by subsystem. |
| 611 | `game/scripts/systems/economy_system.gd` | Core state owner; split only with economy regression coverage. |
| 582 | `tests/gut/test_random_event_system.gd` | Large scenario suite; split by event family. |
| 580 | `addons/gut/utils.gd` | Vendored GUT code; leave untouched unless updating the dependency. |
| 569 | `game/scenes/ui/inventory_panel.gd` | Large UI script; extract row/render helpers in a dedicated pass. |
| 562 | `tests/gut/test_eventbus_signal_compat.gd` | Large compatibility suite; split by signal domain. |
| 560 | `tests/gut/test_checkout_system.gd` | Large checkout suite; split by sale/decline path. |
| 559 | `tests/gut/test_data_loader.gd` | Large loader suite; split by content type. |
| 559 | `game/scripts/systems/build_mode_system.gd` | Candidate for grid normalization and transition helpers. |
| 557 | `game/scripts/systems/store_state_manager.gd` | Candidate for persistence/query helper extraction. |
| 556 | `addons/gut/input_sender.gd` | Vendored GUT code; leave untouched unless updating the dependency. |
| 545 | `game/scenes/ui/day_summary.gd` | Candidate for section-render helper extraction. |
| 539 | `tests/gut/test_store_lease_dialog.gd` | Large UI flow suite; split by success/failure path. |
| 537 | `tests/gut/test_ambient_moments_system.gd` | Large scenario suite; split by scheduler behavior. |
| 536 | `game/scripts/stores/video_rental_store_controller.gd` | Candidate for rental/returns helper extraction. |
| 533 | `game/autoload/staff_manager.gd` | Candidate for scene lookup and data helpers. |
| 531 | `game/scripts/systems/fixture_placement_system.gd` | Candidate for validation/save helpers. |
| 522 | `addons/gut/cli/optparse.gd` | Vendored GUT code; leave untouched unless updating the dependency. |
| 518 | `game/scenes/ui/settings_panel.gd` | Large UI script; extract section-binding helpers later. |
| 513 | `game/scripts/ui/day_summary_panel.gd` | Candidate for row/formatting helper extraction. |
| 513 | `game/scripts/characters/customer_animator.gd` | Candidate for per-animation builder helpers. |

## Verification notes

- Focused GUT coverage for the touched cleanup files still shows the same
  pre-existing failures in this tree (for example
  `test_difficulty_hard_mode_purchase_probability.gd` and
  `test_fixture_upgrade_persistence.gd`), while the helper-consolidated files
  themselves continue to parse and run.
- The repository-wide `bash tests/run_tests.sh` command was already failing
  before this cleanup pass; the failure state remains external to these edits.
