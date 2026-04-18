# Architecture

Mallcore Sim is a signal-driven Godot project. Runtime bootstraps through a
small boot scene, loads JSON content into typed resources, then transitions into
`GameWorld`, which owns the active gameplay systems and UI layer.

## Boot Flow

1. `project.godot` starts `res://game/scenes/bootstrap/boot.tscn`.
2. `game/scripts/core/boot.gd` calls `DataLoaderSingleton.load_all()`.
3. `DataLoaderSingleton` scans `res://game/content/` recursively for JSON.
4. Parsed resources and entry dictionaries are registered in `ContentRegistry`.
5. Boot fails visibly if content errors exist, the registry is not ready, or
   fewer than five store IDs are registered.
6. `Settings.load()` and `AudioManager.initialize()` run.
7. `GameManager` marks boot complete and opens the main menu.

## Autoloads

Autoloads configured in `project.godot`:

| Name | Script | Role |
| --- | --- | --- |
| `DataLoaderSingleton` | `game/autoload/data_loader.gd` | Boot/session content loading and content lookup helpers. |
| `ContentRegistry` | `game/autoload/content_registry.gd` | Canonical ID registry, aliases, scene paths, typed resource lookup, and reference validation. |
| `EventBus` | `game/autoload/event_bus.gd` | Global signal hub for cross-system communication. |
| `GameManager` | `game/autoload/game_manager.gd` | Game state transitions, scene changes, new game/load orchestration, and boot completion. |
| `AudioManager` | `game/autoload/audio_manager.gd` | Music/SFX playback and audio initialization. |
| `Settings` | `game/autoload/settings.gd` | User settings persistence and settings application. |
| `EnvironmentManager` | `game/autoload/environment_manager.gd` | Shared environment/zone lighting ownership. |
| `CameraManager` | `game/autoload/camera_manager.gd` | Active camera registration and `active_camera_changed` signaling. |
| `StaffManager` | `game/autoload/staff_manager.gd` | Staff-facing global helper state. |
| `ReputationSystemSingleton` | `game/autoload/reputation_system.gd` | Store reputation scores and tiers. |
| `DifficultySystemSingleton` | `game/autoload/difficulty_system.gd` | Difficulty selection, modifiers, and save data. |
| `UnlockSystemSingleton` | `game/autoload/unlock_system.gd` | Unlock grants from milestones and content. |
| `CheckoutSystem` | `game/autoload/checkout_system.gd` | NPC purchase transaction helper. |
| `OnboardingSystemSingleton` | `game/autoload/onboarding_system.gd` | Onboarding hint progress. |
| `MarketTrendSystemSingleton` | `game/autoload/market_trend_system.gd` | Global market trend helper. |
| `TooltipManager` | `game/autoload/tooltip_manager.gd` | Tooltip/panel coordination. |

## GameWorld Composition

`res://game/scenes/world/game_world.tscn` contains the `GameWorld` root,
`UILayer`, `StoreContainer`, and the gameplay systems. `game/scenes/world/game_world.gd`
preloads the main UI panels, instantiates the mall hallway, initializes systems
in dependency tiers, then applies either new-game state or a pending save slot.

Current system nodes in `GameWorld`:

- Time and economy: `TimeSystem`, `EconomySystem`, `DayCycleController`,
  `PerformanceManager`, `PerformanceReportSystem`.
- Store and inventory: `InventorySystem`, `StoreStateManager`,
  `StoreSelectorSystem`, `StoreUpgradeSystem`, `OrderSystem`.
- Customers and checkout: `CustomerSystem`, `MallCustomerSpawner`,
  `NPCSpawnerSystem`, `QueueSystem`, `CheckoutSystem`, `HaggleSystem`.
- Markets and events: `TrendSystem`, `MarketEventSystem`,
  `SeasonalEventSystem`, `RandomEventSystem`, `MarketValueSystem`.
- Build and fixtures: `BuildModeSystem`, `FixturePlacementSystem`,
  `DayPhaseLighting`.
- Progression and meta: `ProgressionSystem`, `MilestoneSystem`,
  `TutorialSystem`, `SecretThreadManager`, `SecretThreadSystem`,
  `AmbientMomentsSystem`, `EndingEvaluatorSystem`, `CompletionTracker`.
- Store-specific systems: `TournamentSystem`, `MetaShiftSystem`.
- Persistence: `SaveManager`.

## UI Layer

`GameWorld` builds the gameplay UI in two phases. Essential panels are created
immediately, then heavier panels are loaded deferred after the first frame.

Panels instantiated directly from `game_world.gd` include:

- HUD, inventory, pricing, checkout, haggle, item tooltip, visual feedback
- tutorial overlay and ending screen
- day summary, fixture catalog, milestone popup/banner, milestones panel
- order panel, trends panel, settings panel, pause menu, save/load panel
- pack opening panel, staff panel, upgrade panel
- debug overlay in debug builds only

## Initialization Tiers

`GameWorld.initialize_systems()` runs systems in ordered tiers:

1. Data-independent runtime state, including time and economy.
2. State systems that depend on loaded content, including inventory, store
   state, trends, events, seasonal events, and market value.
3. Operational systems, including reputation, customers, NPC spawning,
   checkout, haggling, ordering, staffing, tutorials, reporting, random events,
   upgrades, and completion tracking.
4. World-facing systems, including store selection, build mode, fixtures, and
   scene/world wiring.
5. Meta systems and final signal wiring.

New games call `bootstrap_new_game_state()`, lease the default `sports` store
slot, create starting inventory, initialize tutorial state, and emit
`day_started(1)`. Loads use `GameManager.pending_load_slot` and
`SaveManager.load_game(slot)`.

## Communication Rules

Systems communicate through `EventBus` signals for cross-system events.
`GameWorld` still injects explicit dependencies during initialization where a
system needs a concrete collaborator, such as inventory into economy or store
controller references into customer systems. Global state changes should still
be announced by signals so UI and other systems can react without polling.

Important signal domains in `EventBus` include:

- content boot: `content_loaded`, `content_load_failed`
- time: `day_started`, `hour_changed`, `day_ended`, `day_phase_changed`
- game state: `game_state_changed`, `gameplay_ready`, `game_over_triggered`
- economy: `transaction_completed`, `money_changed`, `player_bankrupt`
- store flow: `store_entered`, `store_exited`, `active_store_changed`
- inventory/order: `inventory_updated`, `stock_changed`, `order_placed`,
  `order_delivered`
- customers/checkout: `customer_spawned`, `customer_purchased`,
  `customer_left`, `checkout_started`, `checkout_completed`
- build mode: `build_mode_entered`, `fixture_placed`, `fixture_removed`
- progression: `milestone_unlocked`, `unlock_granted`, `completion_reached`
- endings: `ending_requested`, `ending_stats_snapshot_ready`,
  `ending_triggered`

Use `game/autoload/event_bus.gd` as the source of truth for the full signal
catalog.

## Store Controllers

Store scenes live under `game/scenes/stores/`. Controllers under
`game/scripts/stores/` extend `StoreController` directly or through a
store-specific base:

| Store scene | Controller area |
| --- | --- |
| `sports_memorabilia.tscn` | Sports memorabilia authentication and sports-season behavior. |
| `retro_games.tscn` | Retro game testing and refurbishment behavior. |
| `video_rental.tscn` | Rental lifecycle, tape wear, late fees, and returns. |
| `pocket_creatures.tscn` | Pack inventory tracking, tournaments, and card-store hooks. |
| `consumer_electronics.tscn` | Demo-unit, warranty, and product-lifecycle hooks. |

## Save and Load

`SaveManager` writes JSON saves under `user://`:

- Auto-save slot: `save_slot_0.json`
- Manual slots: `save_slot_1.json` and above, constrained by
  `SaveManager.MAX_MANUAL_SLOTS`
- Slot index: `user://save_index.cfg`

Save data includes a `save_version`, `save_metadata`, core system state
(`time`, `economy`, `inventory`, `reputation`, `owned_slots`), and optional
state for systems that are present in the current `GameWorld`, including orders,
progression, milestones, trends, market events, staff, tutorial, endings,
upgrades, completion, unlocks, and onboarding. The current save version is `1`;
older save dictionaries are migrated before distribution.

## State Ownership

Current authoritative owners:

| State | Owner |
| --- | --- |
| Game state and scene transitions | `GameManager` |
| Current day/hour/phase | `TimeSystem` |
| Cash and daily financials | `EconomySystem` |
| Store slot ownership and active store | `StoreStateManager` |
| Inventory item instances and stock | `InventorySystem` |
| Reputation scores | `ReputationSystemSingleton` |
| Difficulty tier and modifiers | `DifficultySystemSingleton` |
| Save slot persistence | `SaveManager` |
| Active camera | `CameraManager` |
| Environment resource | `EnvironmentManager` |

Avoid documenting ownership claims unless they can be traced to current scripts.
