# Architecture — Mallcore Sim

## Boot Flow

The configured entry scene is `res://game/scenes/bootstrap/boot.tscn`. The boot
script (`game/scripts/core/boot.gd`, wrapped by `game/scenes/bootstrap/boot.gd`)
runs synchronous startup checks before opening the main menu:

1. `DataLoaderSingleton.load_all()` discovers JSON content under
   `res://game/content/` and aggregates load errors.
2. `arc_unlocks.json` and `objectives.json` are schema-validated.
3. `ContentRegistry.is_ready()` is asserted.
4. The shipping store roster is asserted to contain at least five IDs.
5. `Settings.load()` then `AudioManager.initialize()` runs.
6. `GameManager.mark_boot_completed()` is called and `EventBus.boot_completed`
   is emitted.
7. `GameManager.transition_to(GameManager.State.MAIN_MENU)` opens the menu.

If any boot step fails, an in-scene error panel is shown and the transition
does not occur.

## GameWorld init tiers

`game/scenes/world/game_world.gd` runs five named initialization tiers when
the playable world scene is brought up. The tiers are ordered explicitly and
each runs in the entered phase of the previous; they are not the same as the
boot script above.

| Tier | Function | Systems started |
|---|---|---|
| 1 — data | `initialize_tier_1_data` | `time_system`, `economy_system` (with starting cash), end-of-day summary callable |
| 2 — state | `initialize_tier_2_state` | `inventory_system`, `store_state_manager`, `trend_system`, `market_event_system`, `seasonal_event_system`, `market_value_system` |
| 3 — operational | `initialize_tier_3_operational` | per-store `ReputationSystemSingleton`, `customer_system`, `mall_customer_spawner`, `npc_spawner_system`, `haggle_system`, `checkout_system`, `queue_system`, `progression_system`, `milestone_system`, `order_system`, `staff_system`, `meta_shift_system` |
| 4 — world | `initialize_tier_4_world` | `store_selector_system`, build mode, `tournament_system`, `day_phase_lighting` |
| 5 — meta | `initialize_tier_5_meta` | `performance_manager`, `performance_report_system`, `random_event_system`, `ambient_moments_system`, `regulars_log_system`, `ending_evaluator`, `DayManager` (instantiated and added as a child here), `store_upgrade_system`, `completion_tracker`, `day_cycle_controller` |

These tier functions are scene nodes' `initialize(...)` calls — not
autoloads. The autoload roster below is initialized earlier by Godot before
any scene loads.

## Autoloads

Declared in `project.godot` in load order. Later autoloads may reference
earlier ones. Three entries are scenes (`ObjectiveRail`, `InteractionPrompt`,
`FailCard`); the rest are scripts.

| # | Autoload | Source |
|---|---|---|
| 1 | `DataLoaderSingleton` | `game/autoload/data_loader.gd` — JSON content discovery and raw-data exposure |
| 2 | `ContentRegistry` | `game/autoload/content_registry.gd` — typed catalogs and canonical IDs |
| 3 | `EventBus` | `game/autoload/event_bus.gd` — cross-system signal hub |
| 4 | `GameManager` | `game/autoload/game_manager.gd` — top-level FSM (`MAIN_MENU`, `GAMEPLAY`, `PAUSED`, `GAME_OVER`, `LOADING`, `DAY_SUMMARY`, `BUILD`, `MALL_OVERVIEW`, `STORE_VIEW`) and run-session entry points |
| 5 | `AudioManager` | `game/autoload/audio_manager.gd` — buses, streams, SFX; instantiates `AudioEventHandler` (`game/autoload/audio_event_handler.gd`) as a child node, not a registered autoload |
| 6 | `Settings` | `game/autoload/settings.gd` |
| 7 | `EnvironmentManager` | `game/autoload/environment_manager.gd` |
| 8 | `CameraManager` | `game/autoload/camera_manager.gd` — read-only viewport observer |
| 9 | `StaffManager` | `game/autoload/staff_manager.gd` |
| 10 | `ReputationSystemSingleton` | `game/autoload/reputation_system.gd` |
| 11 | `DifficultySystemSingleton` | `game/autoload/difficulty_system.gd` |
| 12 | `UnlockSystemSingleton` | `game/autoload/unlock_system.gd` |
| 13 | `CheckoutSystem` | `game/autoload/checkout_system.gd` |
| 14 | `OnboardingSystemSingleton` | `game/autoload/onboarding_system.gd` |
| 15 | `MarketTrendSystemSingleton` | `game/autoload/market_trend_system.gd` |
| 16 | `TooltipManager` | `game/autoload/tooltip_manager.gd` |
| 17 | `ObjectiveRail` | `game/scenes/ui/objective_rail.tscn` (scene) |
| 18 | `InteractionPrompt` | `game/scenes/ui/interaction_prompt.tscn` (scene) |
| 19 | `ObjectiveDirector` | `game/autoload/objective_director.gd` |
| 20 | `AuditOverlay` | `game/autoload/audit_overlay.gd` |
| 21 | `AuditLog` | `game/autoload/audit_log.gd` |
| 22 | `SceneRouter` | `game/autoload/scene_router.gd` — sole caller of `change_scene_to_*` |
| 23 | `ErrorBanner` | `game/autoload/error_banner.gd` |
| 24 | `CameraAuthority` | `game/autoload/camera_authority.gd` — single-current-camera authority |
| 25 | `InputFocus` | `game/autoload/input_focus.gd` — modal/context stack |
| 26 | `StoreRegistry` | `game/autoload/store_registry.gd` — runtime cache seeded from `ContentRegistry` |
| 27 | `StoreDirector` | `game/autoload/store_director.gd` |
| 28 | `GameState` | `game/autoload/game_state.gd` — run-state SSOT (active store, day, money) |
| 29 | `FailCard` | `game/scenes/ui/fail_card.tscn` (scene) |
| 30 | `TutorialContextSystem` | `game/autoload/tutorial_context_system.gd` |
| 31 | `Day1ReadinessAudit` | `game/autoload/day1_readiness_audit.gd` — composite Day 1 playable check that subscribes to `StoreDirector.store_ready` and emits `AuditLog.pass_check(&"day1_playable_ready", …)` / `fail_check(&"day1_playable_failed", …)` |

Single-owner responsibilities for the ownership-enforcing subset are tracked
in [`docs/architecture/ownership.md`](architecture/ownership.md).

## Signal Bus Model

All inter-system communication flows through `EventBus`. Direct `$NodePath` or
`get_node()` references across system boundaries are merge-blocked. Systems
may hold refs to their own child nodes only.

Pattern:

```text
emitter.gd  →  EventBus.emit_signal("signal_name", payload)  →  receiver.gd
```

Signal name conventions used in `event_bus.gd`:

| Prefix | Domain |
|---|---|
| `store_` | Store entry/exit, lease, store ready/failed, register/shelf events |
| `day_` / `hour_` | Day open/close/end, hour ticks, phase transitions, speed changes |
| `customer_` | Spawn, browse decision, haggle, purchase, depart |
| `inventory_` | Stock changes, item add/remove, price set |
| `reputation_` | Tier change, decay tick |
| `milestone_` / `unlock_` / `completion_` | Progression triggers |
| `tutorial_` / `onboarding_` | Tutorial step changes, hints |
| `interactable_` / `panel_` | UI focus and modal open/close (`panel_opened` / `panel_closed`); 3D and 2D hover events |

`run_state_changed()` is a parameterless mirror that lets listeners react to
any `GameState` mutation without subscribing to each typed setter.

## Scene Entry Points

| Scene | Role |
|---|---|
| `game/scenes/bootstrap/boot.tscn` | Entry scene; runs boot script, transitions to main menu |
| `game/scenes/mall/mall_hub.tscn` | Mall hub host; embeds `game_world.tscn` and the hub UI overlay |
| `game/scenes/world/game_world.tscn` | Root of the playable world; runs the five init tiers; owns runtime systems |
| `game/scenes/mall/mall_overview.tscn` | Hub screen — store selection cards, per-store KPI display |
| `game/scenes/stores/<name>.tscn` | Per-store 3D interior; camera framing via `CameraAuthority` |
| `game/scenes/ui/day_summary.tscn` | End-of-day summary panel |
| `game/scenes/ui/hud.tscn` | Persistent overlay: time/phase indicator, funds, reputation tier, live counters |

Store entry is routed through `EventBus.enter_store_requested`, which
`game_world._on_hub_enter_store_requested` handles. `StoreDirector.enter_store(store_id)`
is the single entry point; it delegates to `SceneRouter.route_to_path` for the
scene load (full-scene replacement).

## Visual Systems

The following reusable building blocks govern all visual work. Any PR adding
a visual feature should reuse an entry; new controllers, shaders, or tooltip
panels are merge-blocked unless the existing one is reused or a documented
exception applies.

| Need | Use this | File |
|---|---|---|
| First-person in-store player body (WASD, mouse-look, sprint, interact) | `StorePlayerBody` spawned at `PlayerEntrySpawn` by `GameWorld._spawn_player_in_store` | `game/scripts/player/store_player_body.gd` |
| Eye-level interaction ray cast from the FP camera | `InteractionRay` parented to the `StoreCamera` node | `game/scripts/player/interaction_ray.gd` |
| Debug overhead/orbit camera (F1 dev toggle) | `PlayerController` (orbit pivot + ortho framing) | `game/scripts/player/player_controller.gd` |
| Build-mode orbit / pan / zoom camera with Tween transitions | `BuildModeCamera` | `game/scripts/world/build_mode_camera.gd` |
| Camera ownership / single-current assertion | `CameraAuthority.request_current(cam, source)` | `game/autoload/camera_authority.gd` |
| Hover highlight shader on 3D interactable | `Interactable.highlight()` + `mat_outline_highlight.tres` | `game/scripts/components/interactable.gd` |
| Hover tint on 2D Controls | `InteractableHover` (`self_modulate` → `ACCENT_INTERACT`) | `game/scripts/ui/interactable_hover.gd` |
| Delayed hover tooltip at cursor | `TooltipManager.show_tooltip(text, pos)` + `TooltipTrigger` | `game/autoload/tooltip_manager.gd` |
| `[E] to interact` contextual hint | `InteractionPrompt` listening to `EventBus.interactable_focused` | `game/scenes/ui/interaction_prompt.tscn` |
| Screen-center reticle for the FP camera | `Crosshair` CanvasLayer | `game/scenes/ui/crosshair.tscn` |
| One-unit shelf slot with empty→stocked mesh swap | `ShelfSlot` (extends `Interactable`) | `game/scripts/stores/shelf_slot.gd` |
| Day/night light interpolation | `DayPhaseLighting` tweening `DirectionalLight3D` | `game/scripts/world/day_phase_lighting.gd` |
| CRT scanline post-process shader (2D UI) | `crt_overlay.gdshader` | `game/resources/shaders/crt_overlay.gdshader` |
| Modal open/close tween pattern | `PanelAnimator.modal_open / slide_open / stagger_fade_in` | `game/scripts/ui/panel_animator.gd` |
| Canonical CanvasLayer band assignment | `UILayers` constants | `game/scripts/ui/ui_layers.gd` |
