# Cleanup report

This cleanup pass stayed intentionally narrow because the worktree already
contained unrelated in-progress edits across several large runtime systems. The
changes below were limited to untouched files so the pass could improve
maintainability without colliding with ongoing feature work.

## Dead code removed

| File | Cleanup |
| --- | --- |
| `game/autoload/audio_manager.gd` | Removed a stale commented-out EventBus wiring block and replaced it with a short intent comment pointing to `AudioEventHandler`. |
| `game/scenes/ui/haggle_panel.gd` | Removed a duplicate legacy marker line (`PanelAnimator.kill_tween(_anim_tween)`) from the scene-path compatibility wrapper. |

## Files refactored

| File | Refactor |
| --- | --- |
| `game/autoload/audio_manager.gd` | Replaced code-like comments with a concise explanation of why event wiring lives in the delegated handler. |
| `game/scenes/ui/haggle_panel.gd` | Added a top-level doc comment so the wrapper matches the scene-wrapper pattern already used by `boot.gd` and `upgrade_panel.gd`. |

## Consistency changes made

1. Normalized the `haggle_panel.gd` wrapper so it uses the same "backward-compatible wrapper" framing as other scene-path shims.
2. Replaced commented pseudo-code in `audio_manager.gd` with a short "why" comment, which matches the repo guidance to prefer intent over restating implementation.

## Files still over 500 LOC

These files were inventoried during the pass and are flagged for follow-up.
None were split in this pass because the safest extraction points either live in
active in-progress files or in high-risk orchestration code.

### Runtime scripts

| LOC | File | Follow-up note |
| ---: | --- | --- |
| 1242 | `game/scripts/core/save_manager.gd` | High-value extraction target, but already modified in the current worktree; defer until save/load changes settle. |
| 1232 | `game/scenes/world/game_world.gd` | Central bootstrap/orchestration root; split by initialization tier only after active scene wiring work lands. |
| 977 | `game/autoload/data_loader.gd` | Candidate to keep shrinking into parser/helpers, but still a core content bootstrap path that needs dedicated follow-up. |
| 870 | `game/scripts/systems/customer_system.gd` | Good extraction target for spawn scheduling and satisfaction helpers; currently modified in the worktree. |
| 857 | `game/scripts/content_parser.gd` | Large by design because it owns content-shape parsing; follow-up should split by content domain. |
| 843 | `game/scripts/systems/inventory_system.gd` | Candidate for stock movement / persistence helper extraction. |
| 721 | `game/scripts/systems/order_system.gd` | Candidate for cart, supplier, and delivery sub-components; currently modified in the worktree. |
| 715 | `game/autoload/audio_manager.gd` | Still oversized, but much of the remaining size is catalog/config surface area rather than dead code. |
| 707 | `game/scripts/characters/shopper_ai.gd` | Candidate for state transition and pathing helper extraction. |
| 679 | `game/scripts/world/storefront.gd` | Candidate for interaction/UI split; currently modified in the worktree. |
| 655 | `game/scripts/systems/checkout_system.gd` | Candidate for transaction receipt / queue helper extraction. |
| 642 | `game/scripts/systems/ambient_moments_system.gd` | Candidate for trigger evaluation extraction; currently modified in the worktree. |
| 638 | `game/scripts/systems/secret_thread_system.gd` | Candidate for watcher/counter helpers if secret-thread work resumes. |
| 628 | `game/scripts/characters/customer.gd` | Candidate for movement/intent helpers once NPC flow is stable. |
| 618 | `game/scripts/systems/seasonal_event_system.gd` | Candidate for tournament/event split. |
| 610 | `game/scripts/systems/economy_system.gd` | Candidate for report-generation and transaction-history helpers. |
| 569 | `game/scenes/ui/inventory_panel.gd` | Candidate for filter and row-action extraction. |
| 564 | `game/scripts/systems/store_state_manager.gd` | Candidate for persistence/registration helpers; currently modified in the worktree. |
| 559 | `game/scripts/systems/build_mode_system.gd` | Candidate for placement-preview helper extraction. |
| 545 | `game/scenes/ui/day_summary.gd` | Candidate for view-model/presentation split. |
| 536 | `game/scripts/stores/video_rental_store_controller.gd` | Candidate for rental lifecycle helper extraction. |
| 533 | `game/autoload/staff_manager.gd` | Candidate for staffing registry vs. runtime coordination split. |
| 531 | `game/scripts/systems/fixture_placement_system.gd` | Candidate for validation/save-load helper extraction. |
| 518 | `game/scenes/ui/settings_panel.gd` | Candidate for input-rebinding helper extraction. |
| 513 | `game/scripts/characters/customer_animator.gd` | Candidate for animation-state helper extraction. |
| 511 | `game/autoload/reputation_system.gd` | Candidate for persistence/reporting helper extraction. |
| 505 | `game/scripts/ui/day_summary_panel.gd` | Candidate for section rendering helpers. |

### Tests

| LOC | File | Follow-up note |
| ---: | --- | --- |
| 782 | `game/tests/test_save_load_integration.gd` | Large integration matrix; consider splitting by subsystem round-trip. |
| 776 | `tests/gut/test_shopper_ai.gd` | Split by movement, decisions, and state-machine coverage. |
| 697 | `tests/gut/test_customer_spawn_scheduling.gd` | Split by spawn cadence, caps, and difficulty modifiers. |
| 672 | `tests/gut/test_order_system.gd` | Split by supplier tiers, cart flow, and delivery lifecycle. |
| 625 | `tests/gut/test_mall_hallway_scene.gd` | Split by scene composition vs. interaction coverage. |
| 582 | `tests/gut/test_random_event_system.gd` | Split by event selection vs. effect application. |
| 562 | `tests/gut/test_eventbus_signal_compat.gd` | Split by signal domain to reduce fixture churn. |
| 560 | `tests/gut/test_checkout_system.gd` | Split by happy path, failure path, and queue behavior. |
| 541 | `tests/gut/test_data_loader.gd` | Split by content type or parser responsibility. |
| 539 | `tests/gut/test_store_lease_dialog.gd` | Split by submission state vs. failure/success UI. |
| 537 | `tests/gut/test_ambient_moments_system.gd` | Split by trigger type or ambient moment family. |

## Follow-up recommendations

1. Revisit the oversized files that are already dirty in the current worktree before doing structural extraction there.
2. Tackle large orchestration files (`game_world.gd`, `save_manager.gd`, `data_loader.gd`) in dedicated refactor-only changes so behavior review stays tractable.
3. Split the biggest integration test files by scenario family first; they offer the safest LOC reduction with the lowest runtime risk.
