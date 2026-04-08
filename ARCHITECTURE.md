# Architecture

## High-Level Overview

mallcore-sim is structured around autoload singletons for global state, a linear scene flow for game progression, and a data-driven content pipeline that separates game logic from content definitions.

```
+-----------+     +------------+     +----------------+
|   Boot    | --> | Main Menu  | --> |   Game World   |
+-----------+     +------------+     +----------------+
                                      |  Mall Scene   |
                                      |  +- Stores    |
                                      |  +- Customers |
                                      |  +- Player    |
                                      |  +- UI Layer  |
                                      +----------------+
```

All runtime systems communicate through the EventBus autoload. No system directly references another unless it is a parent-child scene relationship.

## Autoload Singletons

Registered in `project.godot`, always available via global name.

| Autoload       | Path                              | Responsibility                                           |
|----------------|-----------------------------------|----------------------------------------------------------|
| GameManager    | `game/autoload/game_manager.gd`   | Game state machine (menu, playing, paused), session data |
| EventBus       | `game/autoload/event_bus.gd`      | Signal hub for decoupled system communication            |
| AudioManager   | `game/autoload/audio_manager.gd`  | Play SFX/music, manage buses, volume settings            |
| Settings       | `game/autoload/settings.gd`       | User preferences (volume, display, controls), save/load  |

> **Note:** `project.godot` is authoritative for the autoload list. Systems like TimeSystem, EconomySystem, InventorySystem, CustomerSystem, ReputationSystem, and DataLoader exist as standalone class scripts in `game/scripts/` and are instantiated by GameWorld or GameManager at runtime — they are not autoloads. See `docs/architecture/SYSTEM_OVERVIEW.md` for the full system registry.

**Rules for autoloads:**
- No autoload directly calls methods on another autoload. Use EventBus signals.
- Autoloads hold state and provide utility functions. They do not contain scene logic.
- Keep them focused. If an autoload grows past ~300 lines, split it.

## Scene Flow

```
Boot (splash/loading)
  -> Loads DataLoader content, initializes Settings
  -> Transitions to MainMenu

MainMenu
  -> New Game: initializes GameManager session, loads GameWorld
  -> Continue: loads save file, then GameWorld
  -> Settings: opens settings overlay

GameWorld (persistent during play session)
  -> Mall environment scene (static geometry, lighting, navigation)
  -> Player controller (child of GameWorld)
  -> Store instances (dynamically loaded based on save/config)
  -> Customer spawner (manages NPC lifecycle)
  -> UI layer (HUD, inventory, store management panels)
  -> Pause menu (overlay, does not unload GameWorld)
```

Scene transitions use `SceneTree.change_scene_to_packed()` for major transitions and `add_child()` for in-game scene loading.

## Data-Driven Content Pipeline

All game content (items, stores, customer types, events) is defined in JSON files under `game/content/`. This keeps content changes out of GDScript and makes it easy to add new items or store types without touching code.

### Flow

```
JSON files (game/content/)
  |
  v
DataLoader.gd (parses on boot or on-demand)
  |
  v
Typed Resource objects (ItemDefinition, StoreDefinition, etc.)
  |
  v
Runtime systems reference by string ID
```

### Content Structure

```
game/content/
  items/
    sports_cards.json      # Card items with rarity, era, value ranges
    retro_games.json       # Game cartridges, consoles, accessories
    video_rentals.json     # VHS/DVD titles, genres, rental periods
    monster_cards.json     # Fake collectible card game items
    electronics.json       # Gadgets, accessories, cables
  stores/
    store_types.json       # Store type definitions (layout, allowed items, upgrades)
  customers/
    customer_profiles.json # Customer archetypes (collector, casual, bargain hunter)
  events/
    events.json            # Timed events (sales, trends, holidays)
```

### Example Item JSON

```json
{
  "id": "sc_rookie_jordan",
  "name": "1986 Rookie Card - MJ",
  "category": "sports_cards",
  "base_price": 450.00,
  "rarity": "rare",
  "era": "1980s",
  "condition_range": ["poor", "mint"],
  "tags": ["basketball", "rookie", "iconic"]
}
```

## System Breakdown

### Economy System
- Player has a cash balance tracked by EconomyManager
- Items have base values modified by condition, rarity, and market trends
- Customers have willingness-to-pay calculated from profile + item desirability
- Transactions emit signals for UI updates and reputation effects
- Operating costs (rent, utilities, staff) deducted on day transitions

### Inventory System
- Each store has a stock inventory (items on shelves for sale) and a back-stock (overflow storage)
- Player has a personal inventory for items being moved between stores
- Inventory is grid-based in UI, list-based in data (array of item instance IDs)
- Items are instances (with condition, acquisition cost) referencing ItemDefinition resources

### Customer AI
- Customers are scene instances spawned by CustomerSpawner
- Each customer has a profile (archetype) that determines behavior:
  - What store types they visit
  - How long they browse
  - Price sensitivity and haggling behavior
  - Purchase probability per item
- Navigation uses Godot's NavigationServer3D for pathfinding within the mall
- Customer flow: Enter mall -> Pick store -> Browse -> Decide -> Purchase or leave

### Time System
- In-game clock runs at configurable speed (default: 1 real second = 1 game minute)
- Day has phases: morning (low traffic), midday (peak), afternoon (moderate), evening (closing)
- TimeManager emits signals at phase transitions, hour marks, and day boundaries
- Day transition triggers: rent payment, stock delivery, trend shifts

### Reputation System
- Per-store reputation score (0-100) based on: pricing fairness, stock variety, customer satisfaction
- Mall-wide reputation unlocks new store slots and customer types
- Reputation decays slowly if stores are understocked or overpriced

## Resource Types

Custom Godot Resources (`.gd` class definitions, `.tres` instances):

| Resource          | Purpose                                         |
|-------------------|-------------------------------------------------|
| ItemDefinition    | Static item data (name, category, base value)   |
| ItemInstance      | Runtime item with condition, acquisition cost    |
| ProductDefinition | Grouping of items into display products          |
| StoreDefinition   | Store type config (allowed categories, layout)   |
| CustomerProfile   | NPC archetype (preferences, budget, behavior)    |
| EventDefinition   | Timed event config (triggers, effects, duration) |

Resources are created by DataLoader from JSON and referenced by string IDs throughout the codebase.

## Modular Store Architecture

Stores are the core gameplay unit. Each store type shares a common base but defines its own:

- **Allowed item categories** — a sports card shop does not sell electronics
- **Layout template** — shelf arrangements, counter position, display cases
- **Unique mechanics** — video rental has return timers, card shops have grading
- **Upgrade paths** — each store type has its own upgrade tree (better shelves, display cases, signage)

### Store Scene Structure

```
StoreBase (scene root)
  +- StoreInterior (3D environment)
  +- ShelfManager (manages shelf nodes and their item slots)
  +- RegisterArea (purchase interaction zone)
  +- StoreController (script: handles type-specific logic)
  +- CustomerZones (areas where NPCs can browse)
```

`StoreController` is a base class. Each store type extends it:

```
StoreController (base)
  +- SportsCardStoreController
  +- RetroGameStoreController
  +- VideoRentalStoreController
  +- MonsterCardStoreController
  +- ElectronicsStoreController
```

Adding a new store type requires:
1. JSON content file for its items
2. A controller script extending StoreController
3. A layout scene (or reuse an existing template)
4. Entry in `store_types.json`

No changes to core systems needed.
