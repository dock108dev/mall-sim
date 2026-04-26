# Architecture — Mallcore Sim

## Boot Flow

`game_world.gd` drives a 5-tier initialization sequence on scene ready. Each tier must complete before the next begins:

1. **Tier 1 — Data loading:** `DataLoaderSingleton` reads all JSON content files; `ContentRegistry` builds typed catalogs (items, stores, events, milestones). Boot-time content validator runs immediately: parody-name check, `type` field enforcement, cross-reference validation.
2. **Tier 2 — Autoload services:** `GameManager`, `AudioManager`, `EventBus` confirm ready state via `_on_system_ready` callbacks.
3. **Tier 3 — Store controllers:** Each store controller initializes from `ContentRegistry` data. Controllers are autoload-adjacent singletons referenced by `game_world.gd`, not scene nodes.
4. **Tier 4 — World systems:** `checkout_system`, `haggle_system`, `inventory_system`, `reputation_system`, day-cycle clock, and customer spawner start in dependency order.
5. **Tier 5 — UI layer:** HUD, mall overview, and store entry scenes attach and request `CameraAuthority` slots.

## Autoloads

Declared in `project.godot` in load order. Later autoloads may reference earlier
ones. Two entries are scenes (`ObjectiveRail`, `InteractionPrompt`, `FailCard`)
rather than scripts.

| Autoload | File / scene |
|---|---|
| `DataLoaderSingleton` | `game/autoload/data_loader.gd` — JSON content discovery and raw-data exposure |
| `ContentRegistry` | `game/autoload/content_registry.gd` — typed catalogs and canonical IDs |
| `EventBus` | `game/autoload/event_bus.gd` — cross-system signal hub |
| `GameManager` | `game/autoload/game_manager.gd` — legacy run state and session entry points |
| `AudioManager` | `game/autoload/audio_manager.gd` — buses, streams, SFX; instantiates `AudioEventHandler` (`game/autoload/audio_event_handler.gd`) which is **not** a registered autoload |
| `Settings` | `game/autoload/settings.gd` |
| `EnvironmentManager` | `game/autoload/environment_manager.gd` |
| `CameraManager` | `game/autoload/camera_manager.gd` — read-only viewport observer |
| `StaffManager` | `game/autoload/staff_manager.gd` |
| `ReputationSystemSingleton` | `game/autoload/reputation_system.gd` |
| `DifficultySystemSingleton` | `game/autoload/difficulty_system.gd` |
| `UnlockSystemSingleton` | `game/autoload/unlock_system.gd` |
| `CheckoutSystem` | `game/autoload/checkout_system.gd` |
| `OnboardingSystemSingleton` | `game/autoload/onboarding_system.gd` |
| `MarketTrendSystemSingleton` | `game/autoload/market_trend_system.gd` |
| `TooltipManager` | `game/autoload/tooltip_manager.gd` |
| `ObjectiveRail` | `game/scenes/ui/objective_rail.tscn` |
| `InteractionPrompt` | `game/scenes/ui/interaction_prompt.tscn` |
| `ObjectiveDirector` | `game/autoload/objective_director.gd` |
| `AuditOverlay` | `game/autoload/audit_overlay.gd` |
| `AuditLog` | `game/autoload/audit_log.gd` |
| `SceneRouter` | `game/autoload/scene_router.gd` — sole caller of `change_scene_to_*` |
| `ErrorBanner` | `game/autoload/error_banner.gd` |
| `CameraAuthority` | `game/autoload/camera_authority.gd` — single-current-camera authority |
| `InputFocus` | `game/autoload/input_focus.gd` — modal/context stack |
| `StoreRegistry` | `game/autoload/store_registry.gd` — runtime cache seeded from `ContentRegistry` |
| `StoreDirector` | `game/autoload/store_director.gd` |
| `GameState` | `game/autoload/game_state.gd` — run-state SSOT (active store, day, money) |
| `FailCard` | `game/scenes/ui/fail_card.tscn` |
| `TutorialContextSystem` | `game/autoload/tutorial_context_system.gd` |

Single-owner responsibilities for the ownership-enforcing subset are tracked
in [`docs/architecture/ownership.md`](architecture/ownership.md).

## Signal Bus Model

All inter-system communication flows through `EventBus`. Direct `$NodePath` or `get_node()` references across system boundaries are merge-blocked. Systems may hold refs to their own child nodes only.

Pattern:

```
emitter.gd  →  EventBus.emit_signal("signal_name", payload)  →  receiver.gd
```

Signal name conventions:

| Prefix | Domain |
|---|---|
| `store_` | Store entry/exit, shelf interaction, checkout events |
| `day_` | Phase transitions (PRE_OPEN → MORNING_RAMP → MIDDAY_RUSH → AFTERNOON → EVENING), day open/close |
| `customer_` | Spawn, browse decision, haggle, purchase, depart |
| `inventory_` | Stock change, item add/remove, price set |
| `reputation_` | Tier change, decay tick |
| `progression_` | Unlock triggered, milestone reached, completion tracker update |
| `ui_` | Panel open/close, tooltip show/hide, interactable focus |

## Scene Entry Points

| Scene | Role |
|---|---|
| `game/scenes/world/game_world.tscn` | Root; owns all store scenes as children, drives tier init |
| `game/scenes/mall/mall_overview.tscn` | Hub screen — store selection cards, per-store KPI display |
| `game/scenes/stores/<name>.tscn` | Per-store 3D interior; camera framing via `CameraAuthority` |
| `game/scenes/ui/day_summary.tscn` | End-of-day summary panel |
| `game/scenes/ui/hud.tscn` | Persistent overlay: time/phase indicator, funds, reputation tier |

Store entry is routed through `game_world._on_hub_enter_store_requested`, which activates the store scene and calls `CameraAuthority.request_current` for the store's `Camera3D`. `StoreDirector.enter_store(store_id)` is the intended long-term single entry point, but currently delegates to `SceneRouter.route_to_path` (full-scene replacement), which would tear down `GameWorld`. Sub-tree hosting in `StoreDirector` is a future refactor before the hub signal path can be retired.

## Visual Systems

The following reusable building blocks govern all visual work. Any PR adding a visual feature MUST reference at least one entry; new controllers, shaders, or tooltip panels are merge-blocked unless the existing one is reused or an ADR overrides it.

| Need | Use this | File |
|---|---|---|
| Orbit / pan / zoom camera with Tween transitions | `BuildModeCamera` | `game/scripts/world/build_mode_camera.gd` |
| Camera ownership / single-current assertion | `CameraAuthority.request_current(cam, source)` | `game/autoload/camera_authority.gd` |
| Hover highlight shader on 3D interactable | `Interactable.highlight()` + `mat_outline_highlight.tres` | `game/scripts/components/interactable.gd` |
| Hover tint on 2D Controls | `InteractableHover` (`self_modulate` → `ACCENT_INTERACT`) | `game/scripts/ui/interactable_hover.gd` |
| Delayed hover tooltip at cursor | `TooltipManager.show_tooltip(text, pos)` + `TooltipTrigger` | `game/autoload/tooltip_manager.gd` |
| `[E] to interact` contextual hint | `InteractionPrompt` listening to `EventBus.interactable_focused` | `game/scenes/ui/interaction_prompt.tscn` |
| One-unit shelf slot with empty→stocked mesh swap | `ShelfSlot` (extends Interactable) | `game/scripts/stores/shelf_slot.gd` |
| Day/night light interpolation | `DayPhaseLighting` tweening `DirectionalLight3D` | `game/scripts/world/day_phase_lighting.gd` |
| CRT scanline post-process shader (2D UI) | `crt_overlay.gdshader` | `game/resources/shaders/crt_overlay.gdshader` |
| Modal open/close tween pattern | `PanelAnimator.modal_open / slide_open / stagger_fade_in` | `game/scripts/ui/panel_animator.gd` |