# Cleanup Report

## Dead code removed

- `game/autoload/audio_manager.gd`
  - Removed storefront-specific handler methods and the matching private
    store-music helper that had become stale after signal routing was
    centralized in `game/autoload/audio_event_handler.gd`.

## Files refactored

| File | Cleanup |
| --- | --- |
| `game/scripts/core/save_manager.gd` | Extracted shared save-file read/failure handling so `mark_run_complete()`, `load_game()`, and slot metadata reads all use the same open/size/parse/root validation path. |
| `game/autoload/data_loader.gd` | Consolidated duplicate JSON file loading into `_read_json_file()` and `_report_json_error()` so test helpers and boot-time loading stay in sync. |
| `game/autoload/audio_manager.gd` | Removed stale storefront routing code and clarified that `AudioEventHandler` owns EventBus wiring while `AudioManager` owns playback state. |

## Files still over 500 LOC

### Runtime and scene scripts

| File | LOC | Status |
| --- | ---: | --- |
| `game/scripts/core/save_manager.gd` | 1246 | Follow-up: split slot index I/O, schema migration, and state distribution into focused helpers/classes. |
| `game/scenes/world/game_world.gd` | 1232 | Follow-up: extract initialization tiers and scene/UI composition helpers. |
| `game/autoload/data_loader.gd` | 1003 | Justified for now: central content bootstrap still spans discovery, parsing, validation, and compatibility getters. |
| `game/scripts/content_parser.gd` | 879 | Follow-up: break parser families into per-content-type helpers. |
| `game/scripts/systems/customer_system.gd` | 870 | Follow-up: split spawning/scheduling from customer intent orchestration. |
| `game/scripts/systems/inventory_system.gd` | 843 | Follow-up: separate inventory queries, mutation, and persistence helpers. |
| `game/tests/test_save_load_integration.gd` | 782 | Test follow-up: large integration fixture coverage; split by save/load scenario when touched next. |
| `game/scripts/systems/order_system.gd` | 721 | Follow-up: split supplier catalog, cart/order state, and delivery flow. |
| `game/scripts/characters/shopper_ai.gd` | 707 | Follow-up: separate state transitions from navigation/interaction helpers. |
| `game/scripts/world/storefront.gd` | 679 | Follow-up: split leasing/interactions from visual presentation. |
| `game/autoload/audio_manager.gd` | 667 | Justified for now: still owns player pools, crossfades, zone audio, and bus controls in one script. |
| `game/scenes/ui/order_panel.gd` | 666 | Follow-up: split cart state from panel presentation and input wiring. |
| `game/scripts/systems/checkout_system.gd` | 655 | Follow-up: split queue orchestration, haggling, and warranty/rental branches. |
| `game/scripts/systems/ambient_moments_system.gd` | 642 | Follow-up: split catalog filtering from trigger execution. |
| `game/scripts/systems/secret_thread_system.gd` | 638 | Follow-up: split condition evaluation from state persistence. |
| `game/scripts/characters/customer.gd` | 628 | Follow-up: split state machine behaviors from movement/interaction helpers. |
| `game/scripts/systems/seasonal_event_system.gd` | 618 | Follow-up: split schedule lookup from effect application. |
| `game/scripts/systems/economy_system.gd` | 610 | Follow-up: split reporting/history and transaction logic. |
| `game/scenes/ui/inventory_panel.gd` | 569 | Follow-up: split filtering/sorting state from widget rendering. |
| `game/scripts/systems/store_state_manager.gd` | 564 | Follow-up: split ownership persistence from active-store transitions. |
| `game/scripts/systems/build_mode_system.gd` | 559 | Follow-up: split input/controller flow from placement previews. |
| `game/scenes/ui/day_summary.gd` | 545 | Follow-up: split summary formatting from panel lifecycle wiring. |
| `game/scripts/stores/video_rental_store_controller.gd` | 536 | Follow-up: split rental lifecycle from returns/fees helpers. |
| `game/autoload/staff_manager.gd` | 533 | Follow-up: split registry helpers from event-driven mutations. |
| `game/scripts/systems/fixture_placement_system.gd` | 531 | Follow-up: split validation rules from placement persistence. |
| `game/scenes/ui/settings_panel.gd` | 518 | Follow-up: split binding helpers from panel presentation logic. |
| `game/scripts/ui/day_summary_panel.gd` | 513 | Follow-up: split formatting helpers from modal flow control. |
| `game/scripts/characters/customer_animator.gd` | 513 | Follow-up: split animation state mapping from runtime update loop. |

### Test scripts

| File | LOC | Status |
| --- | ---: | --- |
| `tests/gut/test_shopper_ai.gd` | 776 | Large but acceptable as scenario-heavy AI coverage; split by AI domain on next edit. |
| `tests/gut/test_customer_spawn_scheduling.gd` | 697 | Large but acceptable as scheduler matrix coverage; split by spawn source on next edit. |
| `tests/gut/test_order_system.gd` | 672 | Follow-up: split catalog/cart/delivery scenarios. |
| `tests/gut/test_mall_hallway_scene.gd` | 625 | Follow-up: split scene composition from interaction flow assertions. |
| `tests/gut/test_random_event_system.gd` | 582 | Follow-up: split event categories into focused files. |
| `tests/gut/test_eventbus_signal_compat.gd` | 562 | Justified for now: compatibility matrix is easier to audit in one place. |
| `tests/gut/test_checkout_system.gd` | 560 | Follow-up: split queue/haggle/warranty/rental coverage. |
| `tests/gut/test_data_loader.gd` | 541 | Follow-up: split loader discovery, validation, and content-family coverage. |
| `tests/gut/test_store_lease_dialog.gd` | 539 | Follow-up: split unlock gating from transaction/result UI. |
| `tests/gut/test_ambient_moments_system.gd` | 537 | Follow-up: split trigger conditions from dispatch behavior. |

## Consistency changes made

- Centralized repeated JSON-loading behavior in `DataLoader` instead of keeping
  separate open/parse logic for public and boot-time code paths.
- Centralized repeated save-file read and failure reporting in `SaveManager`
  instead of repeating the same file-open, size, parse, and root-dictionary
  checks in multiple methods.
- Clarified ownership comments in `AudioManager` so the script's responsibilities
  match the current `AudioEventHandler` wiring split.
