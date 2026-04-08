# Issue 004: Create sports store interior scene with placeholder geometry

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `art`, `store:sports`, `phase:m1`, `priority:high`
**Dependencies**: None

## Why This Matters

The store is where the entire game happens. M1 needs one playable store interior.

## Store Definition Reference

The sports store is defined in `game/content/stores/store_definitions.json` with ID `"sports"`. The scene must match this data:

| Fixture ID | Type | Slots | Label | Scene Representation |
|---|---|---|---|---|
| `card_case_1` | glass_case | 8 | Card Display Case | Glass-topped counter with 8 item positions |
| `card_case_2` | glass_case | 8 | Card Display Case | Second glass counter, opposite wall |
| `sealed_shelf` | shelf | 6 | Sealed Product Shelf | Wall-mounted shelving unit |
| `memorabilia_shelf` | shelf | 4 | Memorabilia Shelf | Wider shelf for larger items |
| `wall_display` | wall_mount | 3 | Wall Display | Framed positions on wall (jerseys, signed items) |
| `checkout_counter` | counter | 2 | Checkout Counter | Front counter near door with register |

**Total shelf capacity**: 31 slots (must match `shelf_capacity: 31` in store definition)

## Scope

One store interior scene with placeholder geometry (BoxMesh, CSG, colored materials). All geometry is temporary — it just needs to be spatially correct so gameplay systems can be tested.

### Layout

```
+--[ DOOR ]------------------------------------------+
|                                                     |
|  [checkout_counter]     (open floor)                |
|                                                     |
|  [card_case_1]                [card_case_2]         |
|  (glass counter)              (glass counter)       |
|                                                     |
|           (browsing area / open floor)              |
|                                                     |
|  [sealed_shelf]          [memorabilia_shelf]        |
|  (wall-mounted)          (wall-mounted)             |
|                                                     |
|               [wall_display]                        |
|               (back wall)                           |
+-----------------------------------------------------+
```

Approximate dimensions: 8m wide x 10m deep x 3m tall (matches MALL_LAYOUT.md small store footprint).

## Scene Structure

```
SportsStore (Node3D) — scene root
  +- Environment (Node3D)
  |    +- Floor (MeshInstance3D — PlaneMesh, linoleum material)
  |    +- Walls (CSGBox3D or MeshInstance3D, 4 walls)
  |    +- Ceiling (MeshInstance3D — PlaneMesh)
  +- Lighting (Node3D)
  |    +- OverheadLight1 (OmniLight3D — warm fluorescent, ~3800K)
  |    +- OverheadLight2 (OmniLight3D)
  |    +- CaseLight1 (SpotLight3D — accent on card_case_1)
  |    +- CaseLight2 (SpotLight3D — accent on card_case_2)
  +- Fixtures (Node3D)
  |    +- CardCase1 (Node3D) — name must match fixture ID
  |    |    +- CaseMesh (MeshInstance3D — BoxMesh, glass material)
  |    |    +- Slot0 (Interactable/Area3D) ... Slot7
  |    +- CardCase2 (Node3D)
  |    |    +- CaseMesh ... Slot0-Slot7
  |    +- SealedShelf (Node3D)
  |    |    +- ShelfMesh ... Slot0-Slot5
  |    +- MemorabiliaShelf (Node3D)
  |    |    +- ShelfMesh ... Slot0-Slot3
  |    +- WallDisplay (Node3D)
  |    |    +- MountMesh ... Slot0-Slot2
  |    +- CheckoutCounter (Node3D)
  |         +- CounterMesh
  |         +- Slot0, Slot1
  |         +- RegisterPosition (Marker3D — where customer stands to pay)
  +- DoorTrigger (Area3D) — entrance/exit detection
  +- CustomerZones (Node3D)
  |    +- BrowseZone1 (Marker3D — near card cases)
  |    +- BrowseZone2 (Marker3D — near shelves)
  |    +- WaitPosition (Marker3D — queue position at register)
  +- NavigationRegion3D
       +- NavMesh covering walkable floor
```

### Fixture-to-Node Naming Convention

Each fixture node must be identifiable by its `fixture_id` from store_definitions.json. Use a script or metadata approach:
- Node name maps to fixture_id via snake_case -> PascalCase (e.g., `card_case_1` -> `CardCase1`)
- Or: each fixture Node3D has `@export var fixture_id: String` set in the editor

Slot children are `Interactable` (Area3D) instances from `game/scripts/core/interactable.gd` with:
- `display_name` = fixture label + slot number (e.g., "Card Display Case Slot 3")
- `interaction_prompt` = "Stock Item" (when empty) or "Remove Item" / "Inspect" (when occupied)

### Item Slot Dimensions

Each slot Area3D should be approximately 20cm x 20cm x 20cm for cards/small items, 30cm x 30cm x 40cm for memorabilia. These are collision volumes for raycast detection, not visual size.

## Deliverables

- `game/scenes/stores/sports_memorabilia.tscn`
- 6 fixture nodes with correct slot counts (31 total slots)
- Fixture nodes named/tagged to match store_definitions.json fixture IDs
- Slot positions as Interactable Area3D children
- RegisterPosition Marker3D for customer purchase flow
- DoorTrigger Area3D for entrance detection
- CustomerZone Marker3Ds for AI pathfinding targets
- NavigationRegion3D with baked navmesh covering walkable floor
- Basic warm fluorescent lighting (2-3 overhead lights + accent spots)

## Acceptance Criteria

- Scene loads without errors
- Player can walk around the interior without clipping through fixtures
- All 31 slot positions are visible and spatially logical
- Shelf/case slots are Interactable Area3Ds detectable by issue-003's raycast
- Navmesh covers walkable floor area (test with NavigationAgent3D)
- Fixture node names or metadata can be mapped to store_definitions.json fixture IDs
- Lighting feels like a small retail space (warm, not too dark, not washed out)
- Door area clearly indicates entrance/exit