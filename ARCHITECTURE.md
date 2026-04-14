# Architecture

mallcore-sim is a 3D retail simulator built on Godot 4.3+ using GDScript with static typing throughout. Runtime is organized into four tiers: autoload singletons, gameplay systems, store controllers, and the UI layer. All cross-system communication flows through the EventBus signal hub.

## Autoload Singletons

Four global singletons are always present:

| Singleton | Responsibility |
|-----------|----------------|
| `GameManager` | Top-level state machine (main_menu, gameplay, paused, game_over). Entry point for scene transitions. |
| `EventBus` | Signal hub (~90 signals). All cross-system communication goes here. No system holds a direct reference to another. |
| `AudioManager` | SFX and music. `play_sfx(id)`, `play_music(id)`, fade helpers. |
| `Settings` | User preferences (volume, display, controls). Persisted to `user://settings.cfg`. |

`DataLoader` is a boot-time utility (not a persistent autoload) that parses all JSON content files and populates `ContentRegistry` with immutable resource templates.

## Gameplay Systems

Systems live under `game/scripts/systems/` as `Node` subclasses, registered in the `GameWorld` scene. They communicate via EventBus signals only.

### Time and Economy
- `TimeSystem` — Day/night cycle, hour simulation, phase transitions. Owns `current_day`. Emits `day_started`, `hour_changed`, `day_ended`.
- `EconomySystem` — Player cash, store revenue, expense tracking. Emits `transaction_completed(amount, success, message)`.
- `MarketValueSystem` — Dynamic item pricing (rarity × condition × trend modifiers).
- `MarketEventSystem` — Triggered demand spikes/sinks (sports wins, new releases, holidays).
- `TrendSystem` — Slow-moving popularity curves per item category.
- `SeasonalEventSystem` — Calendar-based demand multipliers.
- `RandomEventSystem` — Random occurrences (theft, bulk orders, competitor sales).

### Inventory and Store
- `InventorySystem` — Per-store item stock, shelf placement, restocking queues.
- `StoreStateSystem` — Active store identity, slot ownership map (`slot_index → store_id`), storefront state.
- `StoreSelectorSystem` — Transitions between hallway and store interiors.
- `OrderSystem` — Supplier ordering, delivery timers, tier unlock tracking.
- `CheckoutSystem` — Sale processing, receipt emission.
- `HaggleSystem` — Multi-round haggling state machine.

### Customer and Reputation
- `CustomerSystem` — Spawn scheduling, budget assignment, intent generation.
- `ReputationSystem` — Per-store reputation tiers, daily decay, event-driven adjustments.
- `QueueSystem` — Checkout queue management.

### Progression
- `TutorialSystem` — Step-gated first-play prompts.
- `MilestoneSystem` — Achievement-style unlocks.
- `StaffSystem` — Hiring, assignment, morale, daily wages.
- `PerformanceReportSystem` — End-of-day summary generation.

### World and Build
- `BuildModeSystem` — Fixture placement grid and snap logic.
- `FixturePlacementSystem` — Validates and executes fixture placement.
- `NPCSpawnerSystem` — Customer/staff NPC lifecycle in the active store.

### Meta
- `SecretThreadSystem`, `AmbientMomentsSystem`, `EndingEvaluatorSystem` — Hidden narrative, flavor events, ending detection.

## Store Controllers

Each store type has a specialized controller extending `StoreController` (base class):

| Store | Controller | Unique Mechanics |
|-------|------------|------------------|
| Sports Memorabilia | `SportsMemorabilia` | Authentication dialogs, season cycle demand |
| Retro Games | `RetroGames` | Console testing, refurbishment workflow |
| Video Rental | `VideoRental` | Rental lifecycle, late fee tracking |
| PocketCreatures Cards | `PocketCreaturesStore` | Pack opening, tournament events |
| Consumer Electronics | `Electronics` | Demo units, product depreciation curves |

## Data Pipeline

```
game/content/*.json
    │ parsed at boot by DataLoader
    ▼
ContentRegistry (autoload)
    │ resolve(id) → canonical StringName
    │ get_entry(id) → Dictionary
    ├── item templates (ItemDefinition resources)
    ├── store definitions (StoreDefinition resources)
    ├── customer profiles
    └── event configs
```

JSON is the single source of truth for all game content. ContentRegistry normalizes IDs, validates references, and exposes immutable data to runtime systems.

## EventBus Signal Domains

~90 signals organized by domain:

```
# Time
day_started(day: int)
hour_changed(hour: int)
day_ended(day: int, summary: Dictionary)

# Store transitions
store_entered(store_id: StringName)
store_exited(store_id: StringName)
active_store_changed(store_id: StringName)

# Economy / Leasing
transaction_completed(amount: float, success: bool, message: String)
lease_requested(store_id: StringName, slot_index: int)
lease_completed(store_id: StringName, success: bool, message: String)

# Customers
customer_spawned(customer: Node)
customer_purchased(item_id: StringName, price: float)
customer_left(customer: Node, satisfied: bool)

# Camera
active_camera_changed(camera: Camera3D)

# Build mode
build_mode_entered()
build_mode_exited()

# Reputation
reputation_changed(store_id: StringName, old_tier: int, new_tier: int)
```

Full signal catalog: `docs/architecture/EVENTBUS_SIGNAL_CATALOG.md`.

## Single-Truth Contracts (Critical)

Each piece of game state has exactly one owner. Other systems learn about changes via signals.

| Truth | Owner | How others learn it |
|-------|-------|---------------------|
| Current day | `TimeSystem.current_day` | `day_started` signal |
| Active store | `StoreStateSystem.active_store_id` | `active_store_changed` signal |
| Player cash | `EconomySystem.player_cash` | `transaction_completed` signal |
| Ownership map | `StoreStateSystem.owned_slots` | `lease_completed` signal |
| Active camera | `CameraManager.active_camera` | `EventBus.active_camera_changed` signal |
| World environment | `EnvironmentManager` (single `WorldEnvironment` node) | `EventBus.store_entered` triggers resource swap |

`GameManager` must not shadow these values. `GameManager.current_day` (legacy) stays in sync by listening to `TimeSystem` signals, not by being a second source of truth.

## Key Architectural Invariants

1. **Canonical IDs** — All entity references use `StringName` in `snake_case`. Resolved via `ContentRegistry.resolve()` at system boundaries. Never use display names as keys.
2. **Transactional UI** — Dialogs close only on confirmed backend success. Backends emit `*_completed(success, message)`. Dialogs disable inputs while pending.
3. **Camera safety** — All camera-dependent systems subscribe to `EventBus.active_camera_changed`. Never cache `get_viewport().get_camera_3d()` long-term.
4. **One WorldEnvironment** — Single `WorldEnvironment` node in `EnvironmentManager` autoload. Zone transitions swap the `Environment` resource; no scene carries its own `WorldEnvironment`.
5. **No direct autoload cross-refs** — Autoloads communicate via EventBus only.
6. **Save/load symmetry** — The save dictionary shape must exactly match the shape produced by a fresh runtime session. `load_state()` calls the same init paths as `new_game()`, just with pre-populated data.

## Directory Layout

```
project.godot
game/
  autoload/           4 singletons
  content/            JSON data files (items, stores, customers, economy, events)
  resources/          Resource class definitions (ItemDefinition, StoreDefinition, ...)
  scenes/
    game_world.tscn   persistent root; contains all systems as children
    ui/               39 panel/dialog scenes
    stores/           5 store interior scenes
    mall_hallway.tscn
  scripts/
    systems/          35 gameplay system scripts
    stores/           5 store controllers + store-specific scripts
    ui/               28 UI panel scripts
    player/           camera controller, interaction ray
    world/            build mode, geometry builders, mall hallway
    characters/       customer, customer_animator
    components/       interactable
    core/             save_manager, constants, input_helper
docs/                 all documentation
tests/                GUT test files
```
