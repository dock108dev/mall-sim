# Issue 049: Implement mall hallway and navigation between stores

**Wave**: wave-3
**Milestone**: M3 Progression + Content Expansion
**Labels**: `gameplay`, `art`, `phase:m3`, `priority:high`
**Dependencies**: issue-002, issue-046, issue-058

## Why This Matters

The mall makes it feel like a real place, not just a menu of stores. Walking between stores, seeing storefronts, and navigating common areas is core to the nostalgic mall fantasy (Pillar 1).

## Design Reference

See `docs/design/MALL_LAYOUT.md` for the full floor plan, dimensions, and hallway features.

## Scope

The mall environment scene containing hallways, the central atrium, store entrance doors, and basic atmosphere. This is the "overworld" that connects all stores. Stores themselves are separate scenes loaded/unloaded on entry/exit.

## Implementation Spec

### Scene Structure

`game/scenes/world/mall_environment.tscn`

```
MallEnvironment (Node3D) — scene root
  +- StaticGeometry (Node3D)
  |    +- Floor (MeshInstance3D — terrazzo tile material)
  |    +- Walls (MeshInstance3D — mall walls, columns)
  |    +- Ceiling (MeshInstance3D — drop ceiling with fluorescent panels)
  |    +- Atrium (Node3D)
  |    |    +- AtriumFloor (MeshInstance3D — center area, slightly different tile)
  |    |    +- DirectorySign (MeshInstance3D — mall directory kiosk)
  |    |    +- Benches (Node3D — 2-3 bench meshes)
  |    |    +- Planter (MeshInstance3D — large planter with fake plant)
  +- Lighting (Node3D)
  |    +- HallwayLights (Node3D — repeated OmniLight3D every 4m, fluorescent ~4200K)
  |    +- AtriumSkylight (DirectionalLight3D — soft daylight from above atrium)
  |    +- StorefrontSpots (Node3D — SpotLight3D per store entrance, warm accent)
  +- StoreFronts (Node3D)
  |    +- StoreFront_Sports (Node3D)
  |    |    +- FacadeMesh (MeshInstance3D — storefront wall with window/signage)
  |    |    +- SignLabel (Label3D or MeshInstance3D — store name)
  |    |    +- DoorTrigger (Area3D — interaction zone)
  |    |    +- DoorPosition (Marker3D — where player spawns exiting store)
  |    +- StoreFront_RetroGames (Node3D) — same structure
  |    +- StoreFront_Rentals (Node3D) — same structure
  |    +- StoreFront_PocketCreatures (Node3D) — same structure
  |    +- StoreFront_Electronics (Node3D) — same structure
  |    +- StoreFront_ExpansionA (Node3D)
  |    |    +- ForLeaseMesh (MeshInstance3D — shuttered storefront)
  |    |    +- ForLeaseSign (Label3D — "FOR LEASE" sign)
  |    +- StoreFront_ExpansionB (Node3D) — same as ExpansionA
  |    +- StoreFront_ExpansionC (Node3D) — same as ExpansionA
  +- Hallways (Node3D)
  |    +- HallA (Node3D — south-west corridor)
  |    |    +- HallGeometry (MeshInstance3D)
  |    |    +- Bench (MeshInstance3D)
  |    |    +- VendingMachine (MeshInstance3D)
  |    +- HallB (Node3D — west corridor)
  |    +- HallC (Node3D — east corridor)
  |    +- HallD (Node3D — south-east corridor)
  +- MainEntrance (Node3D)
  |    +- EntranceDoors (MeshInstance3D — automatic glass doors)
  |    +- ExitTrigger (Area3D — edge of playable area, not functional in M3)
  +- Atmosphere (Node3D)
  |    +- MallAmbientSound (AudioStreamPlayer3D — mall ambiance loop)
  |    +- FountainSound (AudioStreamPlayer3D — water sounds near food court)
  +- NavigationRegion3D
  |    +- NavMesh covering all walkable hallway and atrium floor
  +- NPCSpawnPoints (Node3D)
       +- SpawnEntrance (Marker3D — main entrance, primary NPC spawn)
       +- SpawnFoodCourt (Marker3D — secondary NPC source)
```

### Dimensions (from MALL_LAYOUT.md)

- Hallways: 4m wide, ~15-20m long per segment
- Central atrium: ~12m x 12m open area
- Store fronts: 8-10m wide facade per store
- Total walkable area: ~800 sq meters
- Max walk time between any two stores: ~15 seconds at player speed

### Store Transition System

When the player enters a store door trigger:

1. Player enters DoorTrigger Area3D -> interaction prompt: "Press E to enter {store_name}"
2. Player presses E -> transition begins
3. Fade to black (0.3s) via scene transition manager (issue-060)
4. Load store interior scene as child of GameWorld (or swap active scene)
5. Place player at store's door spawn position
6. Fade in (0.3s)
7. Mall environment stays loaded but hidden (or unloaded if memory is tight)

Exiting a store reverses the process:
1. Player walks to store's DoorTrigger -> "Press E to Exit to Mall"
2. Fade, unload store scene, show mall, place player at StoreFront's DoorPosition

### Storefront State Management

Each storefront needs to reflect its state:
- **Unlocked + Open**: Lit signage, visible interior through window, door trigger active
- **Unlocked + Closed**: Dim signage, gate/shutter down, door trigger says "Closed"
- **Locked**: "FOR LEASE" sign, shuttered, no door trigger
- **Locked + Affordable**: "FOR LEASE" sign + subtle highlight (player can afford to unlock)

Storefront state is driven by the store unlock system (issue-046). This issue provides the visual framework; issue-046 provides the logic.

### Storefront Script

`game/scripts/world/store_front.gd`:
```gdscript
class_name StoreFront extends Node3D

@export var store_id: String  # matches store_definitions.json ID
@export var store_scene_path: String  # res://game/scenes/stores/...

enum State { LOCKED, UNLOCKED_CLOSED, UNLOCKED_OPEN }
var current_state: State = State.LOCKED

func set_state(new_state: State) -> void:
    # Update visuals: signage, lighting, shutter, door trigger

func _on_door_trigger_entered() -> void:
    # Show interaction prompt if unlocked and open

func enter_store() -> void:
    # Trigger scene transition to store interior
```

### Navigation

- NavMesh covers all hallway floor and atrium
- Store interiors have their own NavMesh (separate NavigationRegion3D per store scene)
- NPC customers spawn at MainEntrance, navigate to a store front, enter (disappear from mall, appear in store scene)
- Mall NPCs (non-customer, atmosphere only in M3) wander hallways on NavMesh

### Placeholder Atmosphere Details

- 2-3 benches in atrium and hallways (MeshInstance3D, non-interactive)
- Mall directory kiosk in atrium center (non-interactive in M3)
- Vending machine in Hall A (non-interactive in M3)
- Potted plants / planters in hallways
- Floor material: terrazzo tile with brass inlay strips
- Ceiling: drop ceiling tiles with inset fluorescent panels
- Walls: painted drywall with columns at hallway intersections

## Deliverables

- `game/scenes/world/mall_environment.tscn` — full mall layout
- 8 storefront nodes (5 stores + 3 expansion zones)
- `game/scripts/world/store_front.gd` — storefront state management
- Door triggers with interaction prompts on all unlocked stores
- Scene transition integration (calls issue-060's transition manager)
- NavigationRegion3D with baked navmesh for all walkable areas
- Basic atmosphere: benches, directory, planters, lighting
- NPC spawn points at entrance and food court
- Mall ambient audio source

## Acceptance Criteria

- Player can walk the full mall layout (all 4 hallways + atrium)
- Can enter any unlocked store via door trigger + E key
- Store transition is smooth (fade to black, load store, fade in)
- Exiting store returns player to correct hallway position
- Locked stores show "FOR LEASE" signage, no interaction
- NavMesh covers all walkable floor (test with NavigationAgent3D)
- Lighting feels like indoor mall (fluorescent overhead, warm storefront accents)
- Walk time between any two stores is under 15 seconds
- Mall ambient audio plays throughout
- No collision issues at hallway-atrium intersections
- Performance: mall scene renders at 60fps on target hardware