# Issue 045: Implement second store type: retro game store

**Wave**: wave-3
**Milestone**: M3 Progression + Content Expansion
**Labels**: `gameplay`, `store:video-games`, `phase:m3`, `priority:high`
**Dependencies**: issue-041, issue-006, issue-011, issue-004

## Why This Matters

Second store proves the modular architecture works. If adding retro games requires changing core systems, the architecture needs fixing before stores 3-5. This issue is the single most important validation of Pillar 5 (Modular Variety).

## Prerequisites

- StoreController base class must exist (extracted from sports store during wave-1 or early wave-3)
- Fixture/slot system from issue-006 must support arbitrary fixture IDs
- CustomerSystem from issue-011 must be store-type agnostic
- Content already exists: `game/content/items/retro_games.json` (28 items), `game/content/customers/retro_games_customers.json` (4 types)
- Store definition exists in `store_definitions.json` with ID `"retro_games"`

## Implementation Spec

### Step 1: StoreController Base Class (if not already extracted)

If wave-1 produced a monolithic sports store script, extract a base class first:

```
StoreController (Node) — base class
  - var store_id: String
  - var store_definition: StoreDefinition
  - func initialize(store_def: StoreDefinition) -> void
  - func get_fixture_ids() -> PackedStringArray
  - func on_day_start() -> void
  - func on_day_end() -> void
  - func get_unique_mechanics() -> PackedStringArray
  - func _apply_store_specific_modifiers(customer, item) -> Dictionary  # override point
```

### Step 2: RetroGameStoreController

`game/scripts/stores/retro_game_store_controller.gd` extending StoreController:

```gdscript
class_name RetroGameStoreController extends StoreController

var _testing_stations: Dictionary = {}  # platform_name -> {console_instance_id, active_customer}
var _active_tests: Array = []  # customers currently testing

func _apply_store_specific_modifiers(customer, item) -> Dictionary:
    var mods = {}
    # If item's platform has an active testing station, boost conversion
    var platform = item.definition.extra.get("platform", "")
    if platform in _testing_stations:
        if item.definition.category == "cartridges":
            mods["conversion_bonus"] = 0.20  # +20%
        elif item.definition.category == "consoles":
            mods["conversion_bonus"] = 0.30  # +30%
    return mods

func setup_testing_station(platform: String, console_instance_id: String) -> bool:
    # Validate: console exists, is working, platform matches
    # Move console from shelf/backroom to testing station
    # Return true if setup succeeded

func remove_testing_station(platform: String) -> void:
    # Return console to backroom
    # Remove conversion bonus

func _process_testing_queue(delta: float) -> void:
    # Each test takes 30-60 seconds of game time
    # One customer at a time per station
    # Small chance (5%) of controller damage or disc scratch per test
```

### Step 3: Store Interior Scene

`game/scenes/stores/retro_games.tscn` — follows the same pattern as `sports_memorabilia.tscn` (issue-004).

Dimensions: 8m wide x 10m deep x 3m tall (small store per MALL_LAYOUT.md).

```
RetroGameStore (Node3D) — scene root
  +- Environment (Node3D)
  |    +- Floor (MeshInstance3D — dark carpet or concrete texture)
  |    +- Walls (MeshInstance3D — dark walls for neon contrast)
  |    +- Ceiling (MeshInstance3D)
  +- Lighting (Node3D)
  |    +- OverheadLight1 (OmniLight3D — dim, ~3200K)
  |    +- NeonSign1 (OmniLight3D — purple/blue tint, neon glow)
  |    +- NeonSign2 (OmniLight3D — green tint)
  |    +- CRTGlow (OmniLight3D — warm blue, near testing station area)
  +- Fixtures (Node3D)
  |    +- CartWallRack (Node3D) — fixture_id: "cart_wall_rack"
  |    |    +- RackMesh (MeshInstance3D) ... Slot0-Slot9
  |    +- CIBDisplay (Node3D) — fixture_id: "cib_display"
  |    |    +- ShelfMesh ... Slot0-Slot5
  |    +- ConsoleShelf (Node3D) — fixture_id: "console_shelf"
  |    |    +- ShelfMesh ... Slot0-Slot2
  |    +- AccessoriesBin (Node3D) — fixture_id: "accessories_bin"
  |    |    +- BinMesh ... Slot0-Slot7
  |    +- GlassShowcase (Node3D) — fixture_id: "glass_showcase"
  |    |    +- CaseMesh ... Slot0-Slot3
  |    +- CheckoutCounter (Node3D) — fixture_id: "checkout_counter"
  |         +- CounterMesh
  |         +- Slot0, Slot1
  |         +- RegisterPosition (Marker3D)
  +- TestingArea (Node3D) — reserved floor space for testing stations
  |    +- TestingPosition1 (Marker3D) — CRT + console placement
  |    +- TestingPosition2 (Marker3D) — optional second station
  +- DoorTrigger (Area3D)
  +- CustomerZones (Node3D)
  |    +- BrowseZone1 (Marker3D — near cartridge wall)
  |    +- BrowseZone2 (Marker3D — near console shelf)
  |    +- TestingQueue (Marker3D — where customer waits for testing station)
  |    +- WaitPosition (Marker3D — queue at register)
  +- NavigationRegion3D
       +- NavMesh covering walkable floor
```

Layout:
```
+--[ DOOR ]------------------------------------------+
|                                                     |
|  [checkout_counter]     (open floor)                |
|                                                     |
|  [cart_wall_rack]          [accessories_bin]        |
|  (left wall)               (right wall, low bins)   |
|                                                     |
|          (browsing area / testing area)             |
|                                                     |
|  [cib_display]             [console_shelf]          |
|  (left wall shelf)         (right wall)             |
|                                                     |
|               [glass_showcase]                      |
|               (back wall, high-value items)         |
+-----------------------------------------------------+
```

**Total shelf capacity**: 33 slots (matches `shelf_capacity: 33` in store definition).

### Step 4: Integration

- DataLoader already loads retro_games content — no changes needed
- CustomerSystem spawns retro_games customers when player is in the retro store
- InventorySystem creates instances from `starting_inventory` (10 items)
- Store scene is loaded via store_definitions.json `id` -> scene path mapping

## Testing Station Mechanic Details

**Setup flow**:
1. Player has a working console in inventory (e.g., `retro_superstation_console`)
2. Player interacts with TestingPosition Marker3D -> "Set Up Testing Station"
3. Console is consumed (moved to testing station, no longer sellable)
4. Testing station is now active for that platform

**Customer interaction**:
1. Customer browsing cartridges for a platform with a testing station
2. Customer walks to testing station, occupies it for 30-60 game seconds
3. After testing, customer's purchase probability for that item is increased by the conversion bonus
4. 5% chance per test: controller damage ($5 repair/replacement) or disc scratch (item condition drops one grade)

**Constraints**:
- Max 2 testing stations per store (limited by TestingPosition markers)
- One customer at a time per station
- Station setup is permanent until player explicitly removes it
- Removing a station returns the console to backroom (condition may have degraded)

## Deliverables

- `game/scenes/stores/retro_games.tscn` — 6 fixture nodes, 33 total slots
- `game/scripts/stores/retro_game_store_controller.gd` — extends StoreController
- Testing station mechanic (setup, customer interaction, damage chance)
- StoreController base class (if not already extracted from sports store)
- Testing area markers in scene (2 positions)

## Acceptance Criteria

- Store loads and is playable with same core flow as sports store
- All 6 fixtures from store_definitions.json are present with correct slot counts (33 total)
- DataLoader content (28 items, 4 customer types) works without modification
- Starting inventory (10 items) populates correctly
- Testing station can be set up with a console from inventory
- Testing station grants conversion bonus to matching platform items
- Customer testing occupies the station for 30-60 game seconds
- Occasional testing damage occurs (~5% of tests)
- **Architecture validation**: No changes to InventorySystem, EconomySystem, CustomerSystem, TimeSystem, or EventBus were required
- Sports store continues to work identically after retro store is added
- Fixture-to-node mapping uses same convention as sports store