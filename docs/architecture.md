# Architecture

Mallcore Sim is a signal-driven Godot project with a small boot scene, a menu
scene, and a `GameWorld` scene that owns the active gameplay systems and UI.

## Scene entry points

1. `project.godot` starts `res://game/scenes/bootstrap/boot.tscn`.
2. `boot.gd` runs synchronous boot checks and either shows a boot error panel or
   transitions to `res://game/scenes/ui/main_menu.tscn`.
3. The main menu starts a new run or sets `GameManager.pending_load_slot` before
   transitioning to `res://game/scenes/world/game_world.tscn`.
4. `GameWorld` instantiates the hallway, initializes runtime systems, builds the
   gameplay UI, and then applies either new-game state or loaded save data.

## Boot flow

Boot succeeds only when the current content set is usable:

1. `DataLoaderSingleton.load_all()` scans `res://game/content/` recursively.
2. Typed resources and raw entry dictionaries are registered in
   `ContentRegistry`.
3. Boot stops with a visible error panel if content errors were recorded, the
   registry is not ready, or fewer than five store IDs were registered.
4. `Settings.load()` and `AudioManager.initialize()` run.
5. `GameManager.mark_boot_completed()` is called and the main menu opens.

## Autoloads

`project.godot` currently configures these autoloads:

| Name | Script | Responsibility |
| --- | --- | --- |
| `DataLoaderSingleton` | `game/autoload/data_loader.gd` | Boot/session content loading and collection-style data access. |
| `ContentRegistry` | `game/autoload/content_registry.gd` | Canonical IDs, aliases, scene paths, typed resource lookup, and reference validation. |
| `EventBus` | `game/autoload/event_bus.gd` | Global cross-system signal hub. |
| `GameManager` | `game/autoload/game_manager.gd` | State transitions, scene changes, new game/load flow, and boot completion. |
| `AudioManager` | `game/autoload/audio_manager.gd` | Music/SFX initialization and playback. |
| `Settings` | `game/autoload/settings.gd` | User settings persistence and application. |
| `EnvironmentManager` | `game/autoload/environment_manager.gd` | Shared environment and zone-lighting ownership. |
| `CameraManager` | `game/autoload/camera_manager.gd` | Active camera registration and `active_camera_changed`. |
| `StaffManager` | `game/autoload/staff_manager.gd` | Staff-facing global helper state. |
| `ReputationSystemSingleton` | `game/autoload/reputation_system.gd` | Store reputation scores and tiers. |
| `DifficultySystemSingleton` | `game/autoload/difficulty_system.gd` | Difficulty tier persistence and modifier access. |
| `UnlockSystemSingleton` | `game/autoload/unlock_system.gd` | Unlock grants and restore. |
| `CheckoutSystem` | `game/autoload/checkout_system.gd` | Global checkout helper. |
| `OnboardingSystemSingleton` | `game/autoload/onboarding_system.gd` | Onboarding hint state. |
| `MarketTrendSystemSingleton` | `game/autoload/market_trend_system.gd` | Global trend catalog helper. |
| `TooltipManager` | `game/autoload/tooltip_manager.gd` | Tooltip coordination. |

## `GameWorld` composition

`res://game/scenes/world/game_world.tscn` contains:

- `UILayer` for gameplay UI
- `StoreContainer` for the mall hallway and active store scene
- runtime systems for time, economy, inventory, stores, events, customers,
  checkout, progression, build mode, reporting, save/load, and endings

The checked-in `GameWorld` system nodes currently include:

- `TimeSystem`, `EconomySystem`, `DayCycleController`,
  `PerformanceManager`, `PerformanceReportSystem`
- `InventorySystem`, `StoreStateManager`, `StoreSelectorSystem`,
  `StoreUpgradeSystem`, `OrderSystem`
- `CustomerSystem`, `MallCustomerSpawner`, `NPCSpawnerSystem`,
  `QueueSystem`, `CheckoutSystem`, `HaggleSystem`
- `TrendSystem`, `MarketEventSystem`, `SeasonalEventSystem`,
  `RandomEventSystem`, `MarketValueSystem`
- `BuildModeSystem`, `FixturePlacementSystem`, `DayPhaseLighting`
- `ProgressionSystem`, `MilestoneSystem`, `TutorialSystem`,
  `SecretThreadManager`, `SecretThreadSystem`, `AmbientMomentsSystem`,
  `EndingEvaluatorSystem`, `CompletionTracker`
- `TournamentSystem`, `MetaShiftSystem`
- `SaveManager`

## Initialization order

`game_world.gd` initializes runtime in five dependency tiers:

1. **Tier 1** - time and economy base state
2. **Tier 2** - inventory, store state, trend, market, seasonal, and market
   value state
3. **Tier 3** - reputation, customers, NPCs, haggle, checkout, queue,
   progression, milestones, orders, staffing, and meta-shift runtime
4. **Tier 4** - hallway-facing world systems such as store selection, build
   mode, fixtures, tournaments, and day-phase lighting
5. **Tier 5** - reporting, random events, ambient systems, endings, upgrades,
   completion tracking, and final day-cycle wiring

After tiered initialization, `GameWorld` wires `SaveManager` references, store
controller-specific systems, and then asks `GameManager` to apply either the
pending load slot or the default new-game state.

## New-game and load flow

- New runs bootstrap the default `sports` store through
  `bootstrap_new_game_state()`.
- `StoreStateManager.lease_store()` claims the starting slot.
- Default inventory is created for that store.
- Tutorial state is initialized for a fresh run.
- `EventBus.day_started.emit(1)` starts day one.

When loading instead, `apply_pending_session_state()` calls
`SaveManager.load_game(slot)` after the UI and systems are in place.

## UI construction

`GameWorld` builds gameplay UI in two phases.

### Immediate UI

Created in `_setup_ui()`:

- HUD
- inventory panel
- pricing panel
- checkout panel
- haggle panel
- item tooltip
- visual feedback
- tutorial overlay

### Deferred UI

Created in `_setup_deferred_panels()` after the first frame:

- day summary
- fixture catalog
- milestone popup and banner
- milestones panel
- order panel
- trends panel
- settings panel
- pause menu
- save/load panel
- pack opening panel
- staff panel
- upgrade panel
- ending screen

Additional dialogs are instantiated lazily only when the current store needs
them:

- authentication dialog for sports memorabilia
- refurbishment dialog and refurb queue panel for retro games

The debug overlay is instantiated only in debug builds.

## Communication model

Cross-system events are published through `EventBus`. Common signal domains are:

- content boot (`content_loaded`, `content_load_failed`)
- time (`day_started`, `hour_changed`, `day_ended`, `day_phase_changed`)
- game state (`game_state_changed`, `gameplay_ready`, `game_over_triggered`)
- economy (`transaction_completed`, `money_changed`, `player_bankrupt`)
- store flow (`store_entered`, `store_exited`, `active_store_changed`)
- inventory and orders (`inventory_updated`, `stock_changed`, `order_placed`,
  `order_delivered`)
- customers and checkout (`customer_spawned`, `customer_purchased`,
  `customer_left`, `checkout_started`, `checkout_completed`)
- build mode (`build_mode_entered`, `fixture_placed`, `fixture_removed`)
- progression (`milestone_unlocked`, `unlock_granted`, `completion_reached`)
- endings (`ending_requested`, `ending_stats_snapshot_ready`,
  `ending_triggered`)

Use `game/autoload/event_bus.gd` as the source of truth for the complete signal
catalog.

## Store-specific controller wiring

Store scenes live under `game/scenes/stores/`. `GameWorld` wires additional
systems based on the active controller:

| Store scene | Controller hooks wired by `GameWorld` |
| --- | --- |
| `sports_memorabilia.tscn` | Authentication UI and sports season-cycle wiring. |
| `retro_games.tscn` | Testing system, refurbishment system, and refurb UI. |
| `video_rental.tscn` | Rental controller references and inventory-panel rental hooks. |
| `pocket_creatures.tscn` | Pack opening, tournament, and meta-shift hooks. |
| `consumer_electronics.tscn` | Warranty manager and electronics controller hooks. |

## Save and load

`SaveManager` writes JSON save files under `user://`:

- auto-save: `save_slot_0.json`
- manual saves: `save_slot_1.json` through `save_slot_3.json`
- slot index: `user://save_index.cfg`

The authoritative save dictionary always includes:

- `save_version`
- `save_metadata`
- `time`
- `economy`
- `inventory`
- `reputation`
- `owned_slots`

It conditionally adds save data for systems that are present and wired in the
current `GameWorld`, including progression, milestones, refurbishment, trends,
market events, fixtures, tournaments, meta shifts, seasonal events, random
events, staff, tutorial, season cycle, secret threads, ambient moments,
endings, upgrades, completion, performance reporting, unlocks, and onboarding.
Current save version is `1`, and older save dictionaries are migrated before
distribution.

## State ownership

Current authoritative owners that are directly traceable in code:

| State | Owner |
| --- | --- |
| Game state and scene transitions | `GameManager` |
| Current day/hour/phase | `TimeSystem` |
| Cash and day-end financial totals | `EconomySystem` |
| Store slot ownership and active store | `StoreStateManager` |
| Inventory item instances and stock | `InventorySystem` |
| Reputation | `ReputationSystemSingleton` |
| Difficulty tier and modifiers | `DifficultySystemSingleton` |
| Save-slot persistence | `SaveManager` |
| Active camera | `CameraManager` |
| Shared environment resource | `EnvironmentManager` |
