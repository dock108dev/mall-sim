# Issue 087: Create GameWorld integration scene and day cycle orchestration

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `tech`, `gameplay`, `phase:m1`, `priority:high`
**Dependencies**: issue-001, issue-002, issue-004, issue-005, issue-009, issue-010, issue-011, issue-013, issue-014, issue-018

## Why This Matters

Wave-1 issues 001-014 each specify an individual system (DataLoader, Player, Interaction, Store scene, Inventory, Shelf placement, Inventory UI, Price setting, TimeSystem, EconomySystem, Customer AI, Purchase flow, HUD, Day summary). But no issue covers the integration layer that wires them all together into a playable game. The existing `game_world.tscn` is a minimal stub (flat plane + sample shelf) and `game_world.gd` only sets state and emits one signal. Without this issue, wave-1 produces isolated systems that can't form a first playable.

## Current State

### GameManager (`game/autoload/game_manager.gd`)
- Has states: `BOOT`, `MAIN_MENU`, `PLAYING`, `PAUSED`
- **Missing**: `DAY_SUMMARY`, `LOADING` states (described in `docs/architecture/SYSTEM_OVERVIEW.md`)
- Has `transition_to_game()` which loads `game_world.tscn`
- No day cycle orchestration, no system initialization

### GameWorld (`game/scenes/world/game_world.gd` + `.tscn`)
- Stub scene: flat 20x20 floor, one sample shelf, one sample item
- Script only sets `GameManager.current_state = PLAYING` and emits `day_started(1)`
- Does NOT instantiate any gameplay systems (TimeSystem, EconomySystem, InventorySystem, etc.)
- Does NOT load the sports store scene
- Does NOT spawn the player
- Does NOT add the HUD

### EventBus (`game/autoload/event_bus.gd`)
- Has basic signals but is missing many declared by individual system issues (item_stocked, reputation_changed, money_changed, etc.)
- Individual system issues (005, 009, 010, 018) specify the signals they need added — this issue does NOT own EventBus signals, those are added by their respective system issues

## Scope

This issue creates the integration layer that makes all wave-1 systems work together as a playable game:

1. **Expand GameManager** state machine with `DAY_SUMMARY` and `LOADING` states + day cycle orchestration
2. **Rewrite GameWorld scene** to instantiate all gameplay systems, load the store, and spawn the player
3. **Implement day start/end sequence** — the orchestration logic that ties TimeSystem, EconomySystem, InventorySystem, and the Day Summary screen together
4. **Implement new game initialization** — create starter inventory from store definition, set starting cash

## Implementation Spec

### Step 1: Expand GameManager State Machine

Update `game/autoload/game_manager.gd`:

```gdscript
enum GameState { BOOT, MAIN_MENU, LOADING, PLAYING, PAUSED, DAY_SUMMARY }

# Session data (set on New Game or Load)
var current_store_id: String = ""
var current_day: int = 1
var store_name: String = ""

# DataLoader — initialized once at boot, available globally
var data_loader: DataLoader

# State transitions
func start_new_game(store_id: String, player_store_name: String) -> void
func start_day() -> void
func end_day() -> void
func show_day_summary() -> void
func close_day_summary_and_advance() -> void
func pause_game() -> void
func resume_game() -> void
```

**DataLoader Boot (Decision: Option A)**: GameManager owns the DataLoader instance and calls `load_all_content()` during its own `_ready()`, before any scene transitions occur. This ensures content is available globally before GameWorld or MainMenu loads.

```gdscript
# In GameManager._ready():
func _ready() -> void:
    current_state = GameState.BOOT
    data_loader = DataLoader.new()
    data_loader.load_all_content()
    current_state = GameState.MAIN_MENU
    # Main scene (main menu or game world) can now safely query data_loader
```

Other scripts access it via `GameManager.data_loader.get_item(id)`, etc. This avoids adding DataLoader as a separate autoload while keeping it globally accessible.

**Day Cycle Orchestration** (owned by GameManager, triggered by TimeSystem reaching close hour):

```
start_day():
  current_state = PLAYING
  EventBus.day_started.emit(current_day)
  # TimeSystem starts ticking, CustomerSystem starts spawning

end_day():  # Called when TimeSystem hits STORE_CLOSE_HOUR
  current_state = DAY_SUMMARY
  EventBus.day_ended.emit(current_day)
  # CustomerSystem stops spawning, remaining customers leave
  # EconomySystem calculates daily summary
  # Show DaySummaryScreen (issue-014)

close_day_summary_and_advance():
  current_day += 1
  current_state = PLAYING
  start_day()
```

### Step 2: Rewrite GameWorld Scene

Replace the stub `game_world.tscn` with a proper integration scene:

```
GameWorld (Node3D) — scene root, script: game_world.gd
  +- Systems (Node) — container for runtime systems
  |    +- TimeSystem (instantiated from game/scripts/systems/time_system.gd)
  |    +- EconomySystem (instantiated from game/scripts/systems/economy_system.gd)
  |    +- InventorySystem (instantiated from game/scripts/systems/inventory_system.gd)
  |    +- ReputationSystem (instantiated from game/scripts/systems/reputation_system.gd)
  |    +- CustomerSystem (instantiated from game/scripts/systems/customer_system.gd)
  +- StoreContainer (Node3D) — store scene loaded here
  |    +- (sports_memorabilia.tscn loaded as child, from issue-004)
  +- Player (loaded from game/scenes/player/player.tscn, from issue-002)
  +- UILayer (CanvasLayer)
       +- HUD (from issue-013)
       +- DaySummaryScreen (from issue-014, hidden by default)
       +- InventoryPanel (from issue-007, hidden by default)
       +- PricePanel (from issue-008, hidden by default)
```

### Step 3: GameWorld Initialization (`game_world.gd`)

```gdscript
func _ready() -> void:
    # 1. DataLoader already ran at boot (GameManager._ready())
    # 2. Get store definition
    var store_def = GameManager.data_loader.get_store(GameManager.current_store_id)
    
    # 3. Load store scene into StoreContainer using scene_path from store definition
    var store_scene = load(store_def.scene_path).instantiate()
    $StoreContainer.add_child(store_scene)
    
    # 4. Spawn player at store entrance
    var player_scene = preload("res://game/scenes/player/player.tscn").instantiate()
    player_scene.global_position = store_scene.get_node("DoorTrigger").global_position
    add_child(player_scene)
    
    # 5. Initialize starter inventory (new game only)
    if GameManager.current_day == 1:
        _initialize_starter_inventory(store_def)
    
    # 6. Initialize economy
    $Systems/EconomySystem.set_cash(store_def.starting_cash)
    
    # 7. Start first day
    GameManager.start_day()

func _initialize_starter_inventory(store_def: StoreDefinition) -> void:
    for item_id in store_def.starting_inventory:
        var item_def = GameManager.data_loader.get_item(item_id)
        if item_def == null:
            push_warning("Starter inventory item not found: %s" % item_id)
            continue
        # Random condition weighted toward good/near_mint
        var condition = _random_starter_condition()
        var price = item_def.base_price * _condition_multiplier(condition) * 0.6
        $Systems/InventorySystem.create_instance(item_def, condition, 0, price)
```

### Step 4: Connect Day Cycle Signals

GameWorld connects the orchestration signals:

```gdscript
func _ready() -> void:
    # ... (above) ...
    EventBus.day_ended.connect(_on_day_ended)
    # TimeSystem emits day_ended when hour reaches STORE_CLOSE_HOUR
    # GameManager.end_day() triggers the summary screen

func _on_day_ended(_day: int) -> void:
    GameManager.show_day_summary()
    $UILayer/DaySummaryScreen.populate_and_show()
```

### Helper Methods

```gdscript
func _random_starter_condition() -> String:
    # Weighted random: poor 5%, fair 10%, good 40%, near_mint 35%, mint 10%
    var roll = randf()
    if roll < 0.05: return "poor"
    if roll < 0.15: return "fair"
    if roll < 0.55: return "good"
    if roll < 0.90: return "near_mint"
    return "mint"

func _condition_multiplier(condition: String) -> float:
    # Use economy config if available, otherwise hardcode defaults
    var config = GameManager.data_loader.get_economy_config()
    var multipliers = config.get("condition_multipliers", {})
    return multipliers.get(condition, 1.0)
```

## Deliverables

- Updated `game/autoload/game_manager.gd` — expanded state machine with DAY_SUMMARY/LOADING states, day cycle orchestration methods, session data, DataLoader initialization (Option A: GameManager owns DataLoader instance)
- Rewritten `game/scenes/world/game_world.gd` — system instantiation, store loading via `store_def.scene_path`, player spawning, starter inventory initialization, signal connections
- Rewritten `game/scenes/world/game_world.tscn` — proper scene tree with Systems container, StoreContainer, Player, UILayer
- Day cycle wiring: TimeSystem → GameManager → DaySummaryScreen → next day

## What This Issue Does NOT Own

- Individual system implementations (those are issues 001, 005, 009, 010, 011, 018)
- The store scene (issue-004)
- The player scene (issue-002)
- The HUD (issue-013) or Day Summary Screen (issue-014)
- EventBus signal declarations (each system issue adds its own)
- Save/load integration (issue-026)
- Main menu (issue-059)

This issue is purely the **wiring and orchestration** layer.

## Acceptance Criteria

- Game boots, DataLoader loads all content in GameManager._ready(), GameManager transitions to PLAYING state
- GameWorld scene instantiates all 5 gameplay systems as children
- Sports store scene loads into StoreContainer via `store_def.scene_path`
- Player spawns at store entrance, can move around
- Starter inventory (from store definition) is created in InventorySystem on day 1
- Starting cash is set from store definition
- TimeSystem ticks, day progresses through morning/midday/afternoon/evening
- When TimeSystem hits close hour, GameManager transitions to DAY_SUMMARY
- Day summary screen appears (populated by issue-014's implementation)
- Player can dismiss summary, next day starts (day counter increments)
- GameManager.current_state accurately reflects game phase at all times
- Pausing (Escape or Space) sets state to PAUSED, freezes TimeSystem
- Resuming returns to PLAYING

## Test Plan

1. Launch game → verify DataLoader output in console → verify GameWorld loads
2. Check Systems node has all 5 child systems
3. Verify player spawns inside the store
4. Verify starter inventory items appear in InventorySystem (backroom)
5. Fast-forward time → verify day ends → verify summary screen appears
6. Dismiss summary → verify day 2 starts
7. Pause/resume → verify time freezes/unfreezes
8. Check GameManager.current_state at each transition point