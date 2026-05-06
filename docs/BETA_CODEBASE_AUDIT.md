# Beta Codebase Audit

## Project Structure
- Runtime boot path is `project.godot -> run/main_scene -> res://game/scenes/bootstrap/boot.tscn`.
- Boot enters main menu, then gameplay through `GameManager` and `mall_hub -> game_world`.
- The repository currently supports multiple store types; beta target is one store (`retro_games`).
- Gameplay orchestration is concentrated in `game/scenes/world/game_world.gd` (monolithic runtime host).

## Current Scenes
- Boot: `game/scenes/bootstrap/boot.tscn`.
- Main menu: `game/scenes/ui/main_menu.tscn`.
- Gameplay root: `game/scenes/mall/mall_hub.tscn`.
- Runtime systems host: `game/scenes/world/game_world.tscn`.
- Stores present: `retro_games`, `sports_memorabilia`, `video_rental`, `pocket_creatures`, `consumer_electronics`.
- Day summary UI: `game/scenes/ui/day_summary.tscn`.

## Current Scripts
- Core run FSM: `game/autoload/game_manager.gd`.
- Run state holder: `game/autoload/game_state.gd`.
- Data bootstrap: `game/autoload/data_loader.gd`, `game/autoload/content_registry.gd`.
- Store player movement: `game/scripts/player/store_player_body.gd`.
- Interaction ray + prompts: `game/scripts/player/interaction_ray.gd`, `game/scripts/components/interactable.gd`.
- Day/shift/time loop: `game/scripts/systems/time_system.gd`, `day_cycle_controller.gd`, `day_manager.gd`, `shift_system.gd`.
- Save pipeline: `game/scripts/core/save_manager.gd`.
- Hidden thread tracking: `game/autoload/hidden_thread_system.gd`.

## Current Autoloads / Singletons
Large autoload surface in `project.godot` including:
- Core: `GameManager`, `GameState`, `EventBus`, `SceneRouter`, `InputFocus`.
- Content/data: `DataLoaderSingleton`, `ContentRegistry`.
- Gameplay globals: `StoreDirector`, `StoreRegistry`, `CheckoutSystem`, `ReturnsSystem`, `HiddenThreadSystemSingleton`, `EmploymentSystem`.
- UI globals: `InteractionPrompt`, `ObjectiveRail`, `MorningNotePanel`, `MiddayEventCard`, `FailCard`.

Assessment:
- Too many always-on autoloads for a single-store beta.
- Ownership boundaries exist in comments but not yet reduced to a minimal beta runtime profile.

## Current Input Map
Working first-person essentials are present:
- Move: `move_forward`, `move_back`, `move_left`, `move_right`.
- Interact: `interact`.
- Pause/menu: `pause_menu`, `ui_cancel` handling in menu scripts.
- Sprint: `sprint`.

Also present are many non-beta bindings (`toggle_build_mode`, pricing/staff/order panels, nav zone hotkeys, debug camera toggles), which increase cognitive load for Day 1.

## Current Save / State Systems
- Save owner is `SaveManager` node under `GameWorld`.
- Save schema versioned in `save_manager.gd`.
- Run state is split:
  - `GameState` (day/money/flags, signal fan-out)
  - `GameManager` (FSM, current day shadow, store ownership, transitions)
  - System nodes (`TimeSystem`, `StoreStateManager`, etc.)

Assessment:
- State is partially centralized but still fragmented across manager + systems.
- For beta, one explicit run-state authority should be enforced and other systems should consume it.

## Current UI / Overlay Systems
- Main menu works and routes new/load flow.
- In gameplay, many panels are prewired in `GameWorld` (inventory, checkout, pricing, haggle, orders, staff, milestones, completion tracker, pause, save/load, settings, tutorial, day summary, etc.).

Assessment:
- Overlay complexity is high and currently beyond Day 1 vertical-slice needs.
- Risk: modal stack/input focus conflicts and tutorial noise.

## Current Movement / Player Controller
- First-person body (`StorePlayerBody`) provides:
  - WASD movement
  - Mouse look
  - Interact signal
  - Store bounds clamp
  - InputFocus gating
- Legacy orbit camera controller (`PlayerController`) still exists and is toggled in some store flows.

Assessment:
- First-person movement is viable for beta.
- Orbit/debug camera path should be quarantined from normal Day 1 flow.

## Current Store / World Scene
- `retro_games.tscn` is the strongest candidate and has recent visual polish.
- `GameWorld` currently acts as an all-systems shell for all store types.

Assessment:
- Visual direction for the store is now recognizable.
- Runtime still carries multi-store and mall-hub complexity not required for one-store beta.

## Current Customer Systems
- Customer runtime stack exists (`CustomerSystem`, spawners, queue, checkout integration).
- Existing tests indicate broad behavior coverage.

Assessment:
- Preserve base customer flow and queueing; avoid reimplementing low-level spawn/move primitives.

## Current Inventory / Economy Systems
- Inventory, economy, trends, seasonal and market events exist and are wired.
- Pricing logic exists but is distributed across systems.

Assessment:
- Preserve these systems but expose a beta-facing simplified pricing service API for decision cards.

## Current Dialogue / Decision Systems
- Decision-like UIs already exist (checkout card, midday event card, returns, trade-in).
- Shared visual style exists (`decision_card_style.gd`).

Assessment:
- Preserve and adapt existing decision UI surface rather than creating an all-new card stack.

## Current Day / Shift Loop
- Time/day progression: `TimeSystem`.
- Day closure orchestration: `DayCycleController`.
- Arc unlock and win/loss checks: `DayManager`.
- Shift tracking with penalties: `ShiftSystem`.

Assessment:
- Loop exists and is usable, but day flow should be narrowed for Day 1 first-run clarity.

## Current Tutorial Systems
- Tutorial systems and context routing are present with EventBus integration.

Assessment:
- Preserve, but aggressively scope to Day 1 embedded prompts only.

## Current Hidden / Suspicion / Secret Thread Systems
- `HiddenThreadSystem` already tracks interactions, awareness, risk, artifacts.
- Supports day-based progression and save persistence.

Assessment:
- Strong foundation exists for hidden thread.
- Needs explicit beta route rules wired into ending resolution, including framed-zero-interaction route.

## Broken or Unused Systems
- Observed recurring script error in prior logs: assignments into freed `game_manager.gd` instance (`data_loader` write attempts).
- `scripts/godot_exec.sh` is not executable in current workspace environment (permission denied unless invoked via `sh`).
- Warnings in tests around unknown store route for `retro_games`/`sports` indicate content load ordering or registry timing inconsistency in some harnesses.
- Dual camera/controller model (FP + orbit) is active in codebase and increases input/focus complexity.

## Systems to Preserve
- `StorePlayerBody` + `InteractionRay` + `Interactable` contract.
- `retro_games.tscn` as the initial beta store scene baseline.
- `TimeSystem`, `DayCycleController`, `DayManager` as day-flow backbone.
- `HiddenThreadSystem` tracking substrate.
- Existing save serialization in `SaveManager`.
- Existing decision-card UI style and panel patterns.

## Systems to Quarantine
- Non-beta store scenes and their bespoke systems from default beta path.
- Mall-walkable pathways and nonessential hub overlays for Day 1 vertical slice.
- Build mode and fixture placement in normal Day 1 gameplay route.
- Excess panel toggles not required for Day 1 completion.

(Full quarantine list in `docs/QUARANTINED_SYSTEMS.md`.)

## Systems to Delete
- None deleted in this phase.
- Deletion deferred until quarantine and beta path pass end-to-end validation.

## Proposed Beta Architecture
Target architecture for beta should be a narrowed runtime profile:
- Boot -> MainMenu -> BetaGameRoot (single-store mode)
- BetaGameRoot mounts:
  - BetaRunState authority (`GameState` replacement or narrowed extension)
  - Day/shift managers
  - Retro store scene
  - Player FP controller
  - Interaction prompt + decision card UI
- Keep EventBus for decoupling, but reduce active listeners to beta-required flows.
- Maintain data-driven content via existing JSON/Resource pipelines.

## Implementation Risks
- Monolithic `GameWorld` contains many coupled systems; isolation errors can introduce regressions.
- InputFocus/modal stack complexity can still trap movement if non-beta overlays are accidentally enabled.
- Save schema breadth may include legacy fields not relevant to beta; careless edits can break load compatibility.
- Hidden-thread logic already deep; adding framed-route rule without deterministic test coverage risks ending bugs.

## Validation Checklist
- [x] Identify launch scene and boot path.
- [x] Identify movement owner and interaction owner.
- [x] Identify state owners and save owner.
- [x] Identify Day 1 loop components.
- [x] Identify hidden-thread system owner.
- [x] Identify major blockers to Day 1 reliability.
- [ ] Confirm end-to-end Day 1 path in manual runtime playthrough (next phase).
- [ ] Confirm framed ending rule route in deterministic test.
