# Issue 052: Implement third store type: video rental

**Wave**: wave-3
**Milestone**: M3 Progression + Content Expansion
**Labels**: `gameplay`, `store:rentals`, `phase:m3`, `priority:medium`
**Dependencies**: issue-042, issue-006, issue-011, issue-045

## Why This Matters

Rental is the most mechanically distinct store type — it validates the framework's flexibility for business models beyond buy-and-sell. If the core systems can handle rental lifecycle without major rewrites, the architecture is genuinely modular.

## Prerequisites

- StoreController base class exists (established by issue-045)
- InventorySystem supports the `"rented"` location state (defined in issue-005)
- ItemInstance has `rental_due_day` field (added by issue-001)
- Content exists: `game/content/items/video_rental.json` (30 items), `game/content/customers/video_rental_customers.json` (4 types)
- Store definition exists in `store_definitions.json` with ID `"rentals"`

## Implementation Spec

### Step 1: VideoRentalStoreController

`game/scripts/stores/video_rental_store_controller.gd` extending StoreController:

```gdscript
class_name VideoRentalStoreController extends StoreController

var _active_rentals: Dictionary = {}  # instance_id -> {customer_type, due_day, rental_fee}
var _staff_picks: Array[String] = []  # up to 3 instance_ids
var _staff_picks_changed_today: bool = false

# Override: video rental uses rental fee instead of sale price
func process_transaction(instance_id: String, customer) -> void:
    var instance = InventorySystem.get_instance(instance_id)
    var rental_fee = instance.player_set_price  # repurposed as rental fee
    var rental_period = instance.definition.extra.get("rental_period_days", 3)
    var due_day = TimeSystem.current_day + rental_period
    
    # Charge rental fee (not sale price)
    EconomySystem.add_cash(rental_fee)
    
    # Move to rented state (not sold)
    instance.current_location = "rented"
    instance.rental_due_day = due_day
    _active_rentals[instance_id] = {
        "customer_type": customer.type_id,
        "due_day": due_day,
        "rental_fee": rental_fee
    }
    
    EventBus.item_rented.emit(instance_id, rental_fee)  # new signal

func _on_day_start() -> void:
    _staff_picks_changed_today = false
    _process_returns()

func _process_returns() -> void:
    var current_day = TimeSystem.current_day
    var returns_today: Array = []
    
    for instance_id in _active_rentals:
        var rental = _active_rentals[instance_id]
        var due_day = rental["due_day"]
        
        if current_day >= due_day:
            # Determine if returned today
            var late_chance = _get_late_chance(rental["customer_type"])
            var days_late = current_day - due_day
            
            if days_late == 0 or randf() > late_chance:
                returns_today.append(instance_id)
                _process_single_return(instance_id, days_late)
    
    for id in returns_today:
        _active_rentals.erase(id)

func _process_single_return(instance_id: String, days_late: int) -> void:
    var instance = InventorySystem.get_instance(instance_id)
    
    # Late fees
    if days_late > 0:
        var late_fee = days_late * 1.0  # $1/day
        EconomySystem.add_cash(late_fee)
        EventBus.late_fee_charged.emit(instance_id, late_fee)
        # Reputation impact: enforcing late fees costs -0.5 rep per occurrence
        ReputationSystem.adjust(-0.5)
    
    # Damage check
    var damage_chance = 0.02 if instance.definition.category.begins_with("vhs") else 0.005
    if randf() < damage_chance:
        _degrade_condition(instance)
    
    # Loss check (~1% chance)
    if randf() < 0.01:
        var replacement_fee = instance.definition.base_price
        EconomySystem.add_cash(replacement_fee)
        InventorySystem.remove_instance(instance_id)
        EventBus.rental_lost.emit(instance_id, replacement_fee)
        return
    
    # Return to backroom (player re-shelves manually)
    InventorySystem.move_to_backroom(instance_id)
    instance.rental_due_day = -1
    EventBus.item_returned.emit(instance_id)

func set_staff_picks(instance_ids: Array[String]) -> bool:
    if _staff_picks_changed_today:
        return false  # can only change once per day
    if instance_ids.size() > 3:
        return false
    _staff_picks = instance_ids
    _staff_picks_changed_today = true
    return true

func _apply_store_specific_modifiers(customer, item) -> Dictionary:
    var mods = {}
    if item.instance_id in _staff_picks:
        mods["rental_frequency_bonus"] = 0.40  # +40% rental chance
    return mods

func _get_late_chance(customer_type: String) -> float:
    match customer_type:
        "rental_friday_family": return 0.10
        "rental_movie_buff": return 0.05
        "rental_binge_renter": return 0.40
        "rental_new_release_chaser": return 0.15
        _: return 0.15
```

### Step 2: New EventBus Signals

Add to `game/autoload/event_bus.gd`:
```gdscript
signal item_rented(instance_id: String, rental_fee: float)
signal item_returned(instance_id: String)
signal late_fee_charged(instance_id: String, fee: float)
signal rental_lost(instance_id: String, replacement_fee: float)
```

### Step 3: Store Interior Scene

`game/scenes/stores/video_rental.tscn` — medium store (10m x 12m x 3m)

```
VideoRentalStore (Node3D) — scene root
  +- Environment (Node3D)
  |    +- Floor (MeshInstance3D — blue carpet material)
  |    +- Walls (MeshInstance3D — light walls, cover art decals)
  |    +- Ceiling (MeshInstance3D — drop ceiling)
  +- Lighting (Node3D)
  |    +- FluorescentBank1-4 (OmniLight3D — bright white fluorescent, ~5000K)
  |    +- NewReleaseSpots (SpotLight3D — accent on new_releases_wall)
  +- Fixtures (Node3D)
  |    +- NewReleasesWall (Node3D) — fixture_id: "new_releases_wall", 8 slots
  |    +- ClassicShelf1 (Node3D) — fixture_id: "classic_shelf_1", 10 slots
  |    +- ClassicShelf2 (Node3D) — fixture_id: "classic_shelf_2", 10 slots
  |    +- CultCorner (Node3D) — fixture_id: "cult_corner", 6 slots
  |    +- DVDShelf (Node3D) — fixture_id: "dvd_shelf", 6 slots
  |    +- SnackRack (Node3D) — fixture_id: "snack_rack", 6 slots
  |    +- CheckoutCounter (Node3D) — fixture_id: "checkout_counter", 4 slots
  |         +- RegisterPosition (Marker3D)
  +- StaffPicksDisplay (Node3D) — 3 dedicated face-out positions near entrance
  +- DoorTrigger (Area3D)
  +- CustomerZones (Node3D)
  |    +- BrowseZone_NewReleases (Marker3D)
  |    +- BrowseZone_Classics (Marker3D)
  |    +- BrowseZone_Cult (Marker3D)
  |    +- WaitPosition (Marker3D)
  +- NavigationRegion3D
```

Layout:
```
+--[ DOOR ]--------------------------------------------------+
|                                                             |
|  [checkout_counter] [snack_rack]                            |
|  + Staff Picks                                              |
|                                                             |
|  [new_releases_wall]                                        |
|  (prominent wall facing entrance)                           |
|                                                             |
|  [classic_shelf_1]    (aisle)    [classic_shelf_2]          |
|  (left aisle)                    (right aisle)              |
|                                                             |
|  [cult_corner]                   [dvd_shelf]                |
|  (back left)                     (back right)               |
+-------------------------------------------------------------+
```

**Total shelf capacity**: 50 slots (matches `shelf_capacity: 50` in store definition).

### Step 4: Late Fee Player Choice UI

When a rental returns late, a brief notification appears:
- "{title} returned {N} days late — ${fee} late fee collected"
- Future enhancement (wave-4+): player choice to waive late fees for reputation

### Step 5: Rental UI Modifications

The pricing UI (issue-008) needs adaptation for rental stores:
- Label says "Rental Fee" instead of "Price"
- Shows rental period alongside fee
- Rented items show "Checked Out — Due Day {N}" in inventory
- Staff Picks section in inventory UI (3 slots, drag-to-assign)

## Deliverables

- `game/scenes/stores/video_rental.tscn` — 7 fixture nodes, 50 total slots
- `game/scripts/stores/video_rental_store_controller.gd` — extends StoreController
- Rental lifecycle: rent -> checked out -> return (with late/damage/loss chances)
- Late fee system ($1/day, reputation impact)
- Staff Picks mechanic (3 titles, +40% rental frequency, once-per-day change)
- 4 new EventBus signals for rental events
- Rental-specific UI labels ("Rental Fee", "Due Day", "Checked Out")
- VHS degradation tracking (condition drops after many rentals)

## Acceptance Criteria

- Store loads and is playable with rental model (not sale)
- All 7 fixtures from store_definitions.json are present with correct slot counts (50 total)
- Customer rents a title: fee charged, item moves to "rented" state
- Item returns after rental_period_days with correct probability
- Late returns generate late fee revenue
- ~2% VHS damage chance per rental, ~1% loss chance
- Lost items charge replacement fee and remove item from inventory
- Staff Picks boost rental frequency by 40%
- Staff Picks can only be changed once per day
- Snacks are sold (not rented) — sale flow works for snack/merchandise categories
- **Architecture validation**: Core systems (InventorySystem, EconomySystem) did not require changes beyond what issue-005 already provides
- Sports store and retro game store continue to work identically