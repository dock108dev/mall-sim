# Architecture

## Overview

mallcore-sim is a 3D retail simulator built with Godot 4.3+ and GDScript. The architecture uses autoload singletons for global state, a signal bus for decoupled communication, and a data-driven content pipeline that separates game logic from content definitions.

```
Boot -> MainMenu -> GameWorld (persistent during play)
                      +- Mall Hallway (storefront slots)
                      +- Store Interior (swappable per store type)
                      +- Customer Spawner
                      +- Player Controller (orbital camera + raycast)
                      +- UI Layer (CanvasLayer)
                      +- Debug Overlay (debug builds only)
                      +- 25+ runtime systems (see below)
```

All runtime systems communicate through the EventBus autoload. No system directly references another unless it is a parent-child scene relationship.

---

## Autoload Singletons

Four scripts are registered as autoloads in `project.godot`. This is the authoritative source for the autoload list.

| Autoload | Path | Responsibility |
|---|---|---|
| **GameManager** | `game/autoload/game_manager.gd` | Game state machine (MENU, LOADING, PLAYING, PAUSED, DAY_SUMMARY, BUILD), session data, scene transitions |
| **EventBus** | `game/autoload/event_bus.gd` | Signal hub for decoupled communication. 80+ typed signals, zero logic |
| **AudioManager** | `game/autoload/audio_manager.gd` | SFX pool (8 players), music/ambient crossfade, event-triggered sounds |
| **Settings** | `game/autoload/settings.gd` | User preferences (audio, display, controls), persisted to `user://settings.cfg` |

**Rules:**
- No autoload directly calls methods on another autoload. Use EventBus signals.
- Autoloads hold state and provide utility functions. They do not contain gameplay logic.

---

## Runtime Systems

All gameplay systems are standalone class scripts in `game/scripts/systems/`. They are instantiated as children of GameWorld in `game_world.gd:_setup_systems()` — they are NOT autoloads.

### Core Systems

| System | Script | Responsibility |
|---|---|---|
| **TimeSystem** | `time_system.gd` | Game clock (0-1440 minutes/day), day phases (MORNING/MIDDAY/AFTERNOON/EVENING), speed control (1x/2x/4x/pause) |
| **EconomySystem** | `economy_system.gd` | Cash tracking, market value calculations, income/expense tracking, transactions |
| **InventorySystem** | `inventory_system.gd` | Item instance tracking, location management (backroom/shelf/sold), capacity |
| **CustomerSystem** | `customer_system.gd` | Active NPC management, spawning, pooling (5-8 max per store) |
| **ReputationSystem** | `reputation_system.gd` | Score 0-100, tier progression (Unknown/Local Favorite/Destination Shop/Legendary) |
| **CheckoutSystem** | `checkout_system.gd` | Transaction processing with haggling support |
| **RegisterQueue** | `register_queue.gd` | Customer checkout queue with position tracking |
| **SaveManager** | `save_manager.gd` | JSON save/load to `user://saves/`, 3 manual slots + auto-save, versioned migrations |
| **DataLoader** | `data_loader.gd` | JSON content parsing at boot, typed Resource registry, read-only after init |

### Progression Systems

| System | Script | Responsibility |
|---|---|---|
| **ProgressionSystem** | `progression_system.gd` | Milestone evaluation and reward granting |
| **TutorialSystem** | `tutorial_system.gd` | First-day walkthrough and contextual tips |
| **StaffSystem** | `staff_system.gd` | Hiring, firing, wage management, auto-restocking |
| **OrderSystem** | `order_system.gd` | Stock ordering, delivery queues, supplier unlock gates |

> `SupplierTierSystem` (`supplier_tier_system.gd`) is a static utility class. Runtime ordering now lives in `OrderSystem`.

### Economy & Market Systems

| System | Script | Responsibility |
|---|---|---|
| **MarketEventSystem** | `market_event_system.gd` | Market boom/bust/spike/shift events (15% daily chance) |
| **TrendSystem** | `trend_system.gd` | Category/tag demand cycles (0.6-1.5x multipliers) |
| **SeasonalEventSystem** | `seasonal_event_system.gd` | Recurring events (holiday shopping, Black Friday) |
| **RandomEventSystem** | `random_event_system.gd` | Operational challenges (supply shortage, customer surge) |
| **HaggleSystem** | `haggle_system.gd` | Price negotiation with customers |

### Store-Specific Systems

| System | Script | Store Type |
|---|---|---|
| **SeasonCycleSystem** | `season_cycle_system.gd` | Sports Memorabilia — league rotation every ~10 days |
| **AuthenticationSystem** | `authentication_system.gd` | Sports Memorabilia — card authentication |
| **RefurbishmentSystem** | `refurbishment_system.gd` | Retro Games — console refurbishment queue |
| **TapeWearTracker** | `tape_wear_tracker.gd` | Video Rental — tape condition degradation |
| **PackOpeningSystem** | `pack_opening_system.gd` | PocketCreatures — booster pack opening |
| **MetaShiftSystem** | `meta_shift_system.gd` | PocketCreatures — card meta demand shifts |
| **TournamentSystem** | `tournament_system.gd` | PocketCreatures — tournament hosting |
| **TradeSystem** | `trade_system.gd` | PocketCreatures — card trading |
| **ElectronicsLifecycleManager** | `electronics_lifecycle_manager.gd` | Consumer Electronics — product generation management |

### Meta Systems

| System | Script | Responsibility |
|---|---|---|
| **SecretThreadManager** | `secret_thread_manager.gd` | Hidden narrative thread state tracking |
| **AmbientMomentsSystem** | `ambient_moments_system.gd` | 5 guaranteed "something weird" ambient moments |
| **EndingEvaluator** | `ending_evaluator.gd` | Determines ending variant based on milestones + secret thread |
| **PerformanceManager** | `performance_manager.gd` | Frame rate monitoring and market value caching |

### World & Store Management

| System | Script | Responsibility |
|---|---|---|
| **MallCustomerSpawner** | `mall_customer_spawner.gd` | Mall-level spawner distributing customers across owned stores |
| **StoreStateManager** | `store_state_manager.gd` | Store snapshot saving/loading for background simulation |
| **StoreSelector** | `store_selector.gd` | Weighted random store selection for mall-level spawning |
| **BuildMode** | `build_mode.gd` | Fixture placement mode toggle |
| **FixturePlacementSystem** | `fixture_placement_system.gd` | Grid-based placement validation and execution |

---

## Communication Pattern

Systems communicate through EventBus signals. No system holds a direct reference to another system.

```gdscript
# EventBus declares all signals (no logic):
signal item_sold(item_id: String, sale_price: float, customer_id: String)

# Systems emit:
EventBus.item_sold.emit(item.instance_id, price, customer.id)

# Other systems connect:
func _ready() -> void:
    EventBus.item_sold.connect(_on_item_sold)
```

### Key Signal Groups

EventBus contains 80+ typed signals organized by domain:

- **Game State:** `game_state_changed`
- **Time:** `day_started`, `day_ended`, `hour_changed`, `day_phase_changed`, `speed_changed`
- **Economy:** `item_sold`, `money_changed`
- **Inventory:** `item_stocked`, `item_removed_from_shelf`, `inventory_changed`
- **Customer:** `customer_entered`, `customer_left`, `customer_ready_to_purchase`
- **Reputation:** `reputation_changed`
- **Build Mode:** `build_mode_entered/exited`, `fixture_placed/removed/upgraded`
- **Store-Specific:** authentication, refurbishment, rental, pack opening, tournament, meta shift, electronics lifecycle signals
- **UI:** panel toggles, tooltips, notifications

---

## Data Pipeline

All game content is defined in JSON files under `game/content/`. This separates content authoring from code.

```
JSON files (game/content/)
  -> DataLoader.gd (parses at boot)
  -> Typed Resource objects (ItemDefinition, StoreDefinition, etc.)
  -> Runtime systems reference by string ID
```

### Content Structure

```
game/content/
  items/              8 JSON files (one per store type + variants)
  stores/             store_definitions.json (5 store types)
  customers/          6 JSON files (per-store customer profiles)
  economy/            pricing_config.json
  events/             market_events.json, seasonal_events.json, random_events.json
  fixtures/           fixture_definitions.json
  staff/              staff_definitions.json
  milestones/         milestone_definitions.json
  endings/            ending_config.json
```

### Resource Types

| Type | Base Class | Purpose |
|---|---|---|
| **ItemDefinition** | Resource | Immutable item template from JSON (rarity, base_price, tags) |
| **ItemInstance** | RefCounted | Mutable runtime item (condition, location, acquired_day, pricing) |
| **StoreDefinition** | Resource | Store template (shelves, capacity, mechanics, foot traffic) |
| **CustomerProfile** | Resource | Customer behavior template (patience, price_sensitivity, budget) |
| **FixtureDefinition** | Resource | Shelf/display template with tiered upgrades |
| **EconomyConfig** | Resource | Pricing formulas, condition/rarity multipliers, reputation tiers |
| **MarketEventDefinition** | Resource | Market boom/bust event template |
| **SeasonalEventDefinition** | Resource | Recurring seasonal event template |
| **RandomEventDefinition** | Resource | Random operational challenge template |
| **StaffDefinition** | Resource | Staff member template (wage, skill, specialization) |

Definitions extend Resource (immutable templates). Instances extend RefCounted (mutable runtime state). Instances hold a reference to their definition, never duplicate its data.

### DataLoader API

- `get_item(id: String) -> ItemDefinition`
- `get_items_by_store(store_type: String) -> Array[ItemDefinition]`
- `get_items_by_category(category: String) -> Array[ItemDefinition]`
- `get_store(id: String) -> StoreDefinition`
- `get_customer_types_for_store(store_type: String) -> Array[CustomerProfile]`
- `get_economy_config() -> EconomyConfig`
- `get_all_market_events() -> Array[MarketEventDefinition]`

---

## Scene Structure

### Boot (`game/scenes/bootstrap/boot.tscn`)

Entry point. Loads settings and content, transitions to MainMenu.

### Main Menu (`game/scenes/ui/main_menu.tscn`)

New Game, Continue, Load, Settings, Quit. Save slot selection with metadata preview.

### Game World (`game/scenes/world/game_world.tscn`)

Persistent during play session. Instantiates all 25+ runtime systems in `_setup_systems()`. Contains:

- **Mall Hallway** — Hub scene with 5 storefront slots
- **Store Interiors** — Swappable per store type (5 scenes, one per store)
- **Player Controller** — Orbital camera with raycast interaction (not a walking character)
- **Customer Spawner** — Manages NPC lifecycle and pooling
- **UI Layer** — CanvasLayer with HUD, panels, tooltips, day summary
- **Debug Overlay** — Dev builds only (`OS.is_debug_build()` gated)

### Store Scenes

Each store type has its own interior scene:
- `game/scenes/stores/sports_memorabilia.tscn`
- `game/scenes/stores/retro_games.tscn`
- `game/scenes/stores/video_rental.tscn`
- `game/scenes/stores/pocket_creatures.tscn`
- `game/scenes/stores/consumer_electronics.tscn`

Loaded as children of GameWorld. When switching stores, the current interior is freed and the new one instanced.

### Store Controllers

Each store type has a controller extending `StoreController` base class:

```
StoreController (base)
  +- SportsMemorabiliaController
  +- RetroGameStoreController
  +- VideoRentalStoreController
  +- PocketCreaturesStoreController
  +- ElectronicsStoreController
```

Adding a new store type requires: JSON content + controller script + scene + entry in `store_definitions.json`. No core system changes needed.

---

## Ownership Rules

1. Each system owns its data exclusively. No other system writes to it directly.
2. Systems request changes by emitting signals or calling public methods on the owning system.
3. GameManager orchestrates sequences but does not contain gameplay logic.
4. EventBus contains no logic — it is a signal declaration file only.
5. DataLoader is read-only after initialization. Content is never modified at runtime.
6. Each saveable system implements `get_save_data() -> Dictionary` and `load_save_data(data: Dictionary) -> void`.

---

## Directory Structure

```
game/
  autoload/           4 singleton scripts
  assets/
    audio/            SFX, music, ambient tracks
    materials/        65 PBR material resources
    models/           (placeholder — final art pending)
    textures/         (placeholder — final art pending)
  content/            23 JSON content files
  resources/          11 Resource/RefCounted class definitions + UI theme
  scenes/             39 .tscn scene files
    bootstrap/        Boot scene
    characters/       Customer scene
    debug/            Debug overlay
    player/           Player controller and camera
    stores/           5 store interiors + shelf_slot component
    ui/               28 UI panels and dialogs
    world/            GameWorld, mall hallway, storefront
  scripts/            77 GDScript files
    characters/       Customer AI and animation
    components/       Interactable component
    core/             Constants, SaveManager, InputHelper
    debug/            Debug commands
    player/           Player controller, camera, interaction ray
    stores/           Store controllers and store-specific scripts
    systems/          35 gameplay systems
    ui/               UI helpers (tooltip, panel animator, theme)
    world/            Build mode, fixture placement, mall geometry
  tests/              2 test files (register queue, store navigation)
```
