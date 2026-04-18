# Cleanup Report

## Scope

This pass stayed behavior-safe and avoided unrelated in-flight files where
possible. The cleanup focused on removing duplicated test helpers, trimming
code-shaped compatibility comments, and recording large-file follow-up work
instead of forcing risky runtime refactors.

## Dead code removed

| File | Cleanup |
| --- | --- |
| `game/tests/test_checkout_system.gd` | Removed the file-local `_safe_disconnect()` helper after switching to a shared helper. |
| `game/tests/test_customer_system.gd` | Removed the file-local `_safe_disconnect()` helper after switching to a shared helper. |
| `game/tests/test_day_cycle_integration.gd` | Removed the file-local `_safe_disconnect()` helper after switching to a shared helper. |
| `game/tests/test_trade_system.gd` | Removed the file-local `_safe_disconnect()` helper after switching to a shared helper. |
| `game/scenes/ui/haggle_panel.gd` | Replaced a commented-out pseudo-code marker block with a compact prose note that preserves the legacy validator tokens without looking like executable dead code. |

## Files refactored

| File | Change |
| --- | --- |
| `game/tests/test_signal_utils.gd` | Added a shared `safe_disconnect()` helper for defensive EventBus teardown in legacy `game/tests` GUT coverage. |
| `game/tests/test_checkout_system.gd` | Switched teardown to `TEST_SIGNAL_UTILS.safe_disconnect()`. |
| `game/tests/test_customer_system.gd` | Switched teardown to `TEST_SIGNAL_UTILS.safe_disconnect()`. |
| `game/tests/test_day_cycle_integration.gd` | Switched teardown to `TEST_SIGNAL_UTILS.safe_disconnect()`. |
| `game/tests/test_trade_system.gd` | Switched teardown to `TEST_SIGNAL_UTILS.safe_disconnect()`. |
| `game/scenes/ui/haggle_panel.gd` | Normalized the wrapper comment so its compatibility intent is clear and the file no longer carries a block of commented code fragments. |

## Consistency changes made

- Standardized shared test-helper usage with the `TEST_SIGNAL_UTILS` constant in
  the updated `game/tests` files.
- Kept the haggle-panel wrapper comment in "why" form instead of "what" form,
  while preserving the exact legacy marker tokens that external validators
  expect.
- Used the existing typed `Signal`/`Callable` signature in the shared helper so
  the cleanup matches current GDScript typing conventions.

## Files still over 500 LOC

These files were inventoried and flagged for follow-up rather than split during
this pass. The goal here was to avoid behavior changes in high-churn runtime
systems and vendored dependencies.

| LOC | File | Follow-up |
| ---: | --- | --- |
| 1759 | `game/addons/gut/test.gd` | Third-party vendored code; leave untouched unless updating GUT. |
| 1226 | `game/scenes/world/game_world.gd` | Runtime orchestrator; candidate for staged extraction after current gameplay edits settle. |
| 1224 | `game/addons/gut/gut.gd` | Third-party vendored code; leave untouched unless updating GUT. |
| 1129 | `game/scripts/core/save_manager.gd` | High-risk persistence logic; split only with dedicated save/load coverage. |
| 1028 | `game/autoload/data_loader.gd` | Core boot/content pipeline; refactor under focused loader work. |
| 879 | `game/scripts/content_parser.gd` | Parsing/normalization hotspot; good candidate for format-specific helpers. |
| 870 | `game/scripts/systems/customer_system.gd` | Large gameplay system; extract spawn/decision helpers in a dedicated pass. |
| 846 | `game/scripts/systems/inventory_system.gd` | Central state owner; refactor only with inventory regression coverage. |
| 782 | `game/tests/test_save_load_integration.gd` | Large integration suite; safe target for fixture/helper extraction. |
| 776 | `tests/gut/test_shopper_ai.gd` | Large test file; candidate for scenario-based test splitting. |
| 721 | `game/scripts/systems/order_system.gd` | Multi-responsibility runtime script; extract cart/supplier helpers later. |
| 707 | `game/scripts/characters/shopper_ai.gd` | Candidate for state/behavior helper extraction. |
| 697 | `tests/gut/test_customer_spawn_scheduling.gd` | Large test matrix; split by scheduler scenario. |
| 679 | `game/scripts/world/storefront.gd` | Mixed world-building logic; extract presentation helpers later. |
| 672 | `tests/gut/test_order_system.gd` | Large test matrix; split by ordering flow. |
| 667 | `game/autoload/audio_manager.gd` | Core autoload; isolate player-pool helpers in a future pass. |
| 666 | `game/scenes/ui/order_panel.gd` | UI script already large; extract row/build helpers carefully. |
| 655 | `game/scripts/systems/checkout_system.gd` | Runtime-critical; split only with checkout regression coverage. |
| 653 | `game/autoload/settings.gd` | Autoload persistence/wiring hotspot; refactor with settings coverage. |
| 642 | `game/scripts/systems/ambient_moments_system.gd` | Candidate for scheduler/history helper extraction. |
| 638 | `game/scripts/systems/secret_thread_system.gd` | Candidate for state-transition helper extraction. |
| 628 | `game/scripts/characters/customer.gd` | Candidate for movement/state helper extraction. |
| 625 | `tests/gut/test_mall_hallway_scene.gd` | Large scene-contract suite; split by subsystem. |
| 618 | `game/scripts/systems/seasonal_event_system.gd` | Candidate for calendar/config helpers. |
| 611 | `game/scripts/systems/economy_system.gd` | Core state owner; split only with economy regression coverage. |
| 582 | `tests/gut/test_random_event_system.gd` | Large scenario suite; split by event family. |
| 580 | `game/addons/gut/utils.gd` | Third-party vendored code; leave untouched unless updating GUT. |
| 569 | `game/scenes/ui/inventory_panel.gd` | Large UI script; extract row/render helpers in a dedicated pass. |
| 562 | `tests/gut/test_eventbus_signal_compat.gd` | Large compatibility suite; split by signal domain. |
| 560 | `tests/gut/test_checkout_system.gd` | Large test suite; split by checkout path. |
| 559 | `game/scripts/systems/build_mode_system.gd` | Candidate for grid normalization/transition helpers. |
| 557 | `game/scripts/systems/store_state_manager.gd` | Candidate for persistence/query helper extraction. |
| 556 | `game/addons/gut/input_sender.gd` | Third-party vendored code; leave untouched unless updating GUT. |
| 545 | `game/scenes/ui/day_summary.gd` | Candidate for section-render helper extraction. |
| 541 | `tests/gut/test_data_loader.gd` | Large loader suite; split by content type. |
| 539 | `tests/gut/test_store_lease_dialog.gd` | Large UI flow suite; split by success/failure path. |
| 537 | `tests/gut/test_ambient_moments_system.gd` | Large scenario suite; split by scheduler behavior. |
| 536 | `game/scripts/stores/video_rental_store_controller.gd` | Candidate for rental/returns helper extraction. |
| 533 | `game/autoload/staff_manager.gd` | Candidate for scene lookup and data helpers. |
| 531 | `game/scripts/systems/fixture_placement_system.gd` | Candidate for validation/save helpers. |
| 521 | `game/addons/gut/cli/optparse.gd` | Third-party vendored code; leave untouched unless updating GUT. |
| 518 | `game/scenes/ui/settings_panel.gd` | Large UI script; extract section-binding helpers later. |
| 513 | `game/scripts/ui/day_summary_panel.gd` | Candidate for row/formatting helper extraction. |
| 513 | `game/scripts/characters/customer_animator.gd` | Candidate for per-animation builder helpers. |

## Verification notes

- Focused GUT coverage for the touched legacy tests passed after the helper
  consolidation.
- The repository-wide `bash tests/run_tests.sh` command was already failing
  before this cleanup pass; the remaining failures are tracked separately from
  the cleanup edits.
