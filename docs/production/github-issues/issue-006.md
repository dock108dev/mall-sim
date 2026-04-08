# Issue 006: Implement shelf interaction and item placement flow

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `gameplay`, `ui`, `phase:m1`, `priority:high`
**Dependencies**: issue-003, issue-004, issue-005

## Why This Matters

Stocking shelves is the primary player action in the daily loop. Every day begins with the player moving items from backroom to shelves, and this flow must feel satisfying and responsive. This is where Player-Driven Business (Pillar 2) and Nostalgic Retail Fantasy (Pillar 1) converge — the act of filling display cases with cards and memorabilia IS the game.

## Current State

- `Interactable` base class exists at `game/scripts/core/interactable.gd` (Area3D with `interact()` virtual)
- Issue-003 provides the raycast + prompt system that detects Interactables
- Issue-004 creates ShelfSlot Area3D nodes as children of each fixture
- Issue-005 provides `InventorySystem` with `move_to_shelf()`, `move_to_backroom()`, `is_slot_occupied()`, `get_shelf_item_at()`
- Issue-007 provides the InventoryPanel UI that displays backroom items

## Design

### Two Interaction Modes

Shelf slots behave differently based on state:

1. **Empty slot**: Prompt says "Press E to Stock Item". Pressing E opens InventoryPanel filtered to backroom items eligible for this fixture type. Player selects an item → item moves to this slot.

2. **Occupied slot**: Prompt says "Press E to Manage [Item Name]". Pressing E opens a small context popup with options:
   - **Remove** — returns item to backroom
   - **Set Price** — opens price panel (issue-008)
   - **Inspect** — shows item detail tooltip (future, not M1-critical)

### ShelfSlot Script

Create `game/scripts/core/shelf_slot.gd` extending `Interactable`:

```gdscript
class_name ShelfSlot
extends Interactable

@export var fixture_id: String          # e.g., "card_case_1"
@export var slot_index: int             # 0-based index within fixture
@export var allowed_categories: PackedStringArray  # from store definition

var current_instance_id: String = ""    # empty string = unoccupied
var _item_visual: MeshInstance3D = null  # placeholder visual for placed item

func _ready() -> void:
    _update_prompt()

func is_occupied() -> bool:
    return current_instance_id != ""

func interact() -> void:
    if is_occupied():
        _show_manage_popup()
    else:
        _open_placement_panel()

func _update_prompt() -> void:
    if is_occupied():
        var instance = InventorySystem.get_instance(current_instance_id)
        if instance:
            display_name = instance.definition.item_name
            interaction_prompt = "Manage %s" % instance.definition.item_name
    else:
        display_name = "Empty Slot"
        interaction_prompt = "Stock Item"
```

### Placement Flow (State Sequence)

```
1. Player aims at empty ShelfSlot → HUD shows "Press E to Stock Item"
2. Player presses E → ShelfSlot.interact() called
3. ShelfSlot emits EventBus.shelf_slot_activated(fixture_id, slot_index, allowed_categories)
4. InventoryPanel opens, filtered to:
   a. Items in backroom (current_location == "backroom")
   b. Items whose category is in the slot's allowed_categories
5. Player clicks an item in the panel
6. InventoryPanel emits EventBus.inventory_item_selected(instance_id)
7. ShelfSlot receives the signal, calls InventorySystem.move_to_shelf(instance_id, fixture_id, slot_index)
8. If move succeeds:
   a. ShelfSlot.current_instance_id = instance_id
   b. Spawn placeholder visual (colored BoxMesh matching rarity color)
   c. InventoryPanel closes
   d. Play placement SFX (shelf snap sound)
   e. Update prompt text to show item name
9. If move fails (slot occupied race condition): show brief error, keep panel open
```

### Removal Flow

```
1. Player aims at occupied ShelfSlot → HUD shows "Press E to Manage [Item Name]"
2. Player presses E → context popup appears with Remove / Set Price options
3. Player clicks Remove:
   a. InventorySystem.move_to_backroom(current_instance_id)
   b. Remove placeholder visual
   c. ShelfSlot.current_instance_id = ""
   d. Close popup
   e. Play removal SFX
   f. Update prompt text to "Stock Item"
4. Player clicks Set Price:
   a. Emit EventBus.price_panel_requested(current_instance_id)
   b. Price panel opens (issue-008 handles this)
   c. Close context popup
```

### Context Popup

Small `PanelContainer` with 2-3 buttons, positioned near screen center:

```
ShelfContextPopup (PanelContainer)
  +- VBoxContainer
       +- ItemNameLabel (Label) — "Griffey Jr. Rookie Card (Near Mint)"
       +- PriceLabel (Label) — "Listed at: $45.00 | Market: $37.50"
       +- Separator (HSeparator)
       +- RemoveButton (Button) — "Remove from Shelf"
       +- SetPriceButton (Button) — "Set Price"
       +- CloseButton (Button) — "Cancel"
```

The popup pauses time (or at least freezes the interaction raycast) while open. Pressing Escape or clicking Cancel closes it.

### Placeholder Item Visual

When an item is placed on a shelf, spawn a `MeshInstance3D` child on the ShelfSlot:
- **BoxMesh** sized to slot dimensions (roughly 15cm x 20cm x 5cm for cards, 25cm x 30cm x 15cm for memorabilia)
- **Color-coded by rarity**:
  - Common: light gray (#CCCCCC)
  - Uncommon: green (#4CAF50)
  - Rare: blue (#2196F3)
  - Very Rare: purple (#9C27B0)
  - Legendary: gold (#FFD700)
- A small `Label3D` above the item showing the player-set price (e.g., "$12.00")
- Future: replace BoxMesh with actual item icon textures on quads

### EventBus Signals Needed

Add to `game/autoload/event_bus.gd`:
```gdscript
signal shelf_slot_activated(fixture_id: String, slot_index: int, allowed_categories: PackedStringArray)
signal inventory_item_selected(instance_id: String)
signal price_panel_requested(instance_id: String)
```

Note: `item_stocked` and `item_removed_from_shelf` signals are already specified by issue-005.

### Category Filtering

Each ShelfSlot inherits `allowed_categories` from its parent fixture, which comes from the store definition. When the InventoryPanel opens for placement, it must filter items to only show those whose `ItemDefinition.category` is in the slot's `allowed_categories`.

For M1 (sports store), `allowed_categories` is `["trading_cards", "sealed_packs", "sealed_product", "memorabilia"]` — all fixtures accept all categories. Per-fixture category restrictions are a future enhancement.

### Shelf Fill Tracking

ShelfSlot state feeds into ReputationSystem (issue-018) via `shelf_fill_ratio`. The InventorySystem already tracks slot occupancy — ShelfSlots just need to stay in sync with it.

On `_ready()`, each ShelfSlot should check `InventorySystem.get_shelf_item_at(fixture_id, slot_index)` to restore visual state when the scene loads (for save/load support).

## Scene Structure

```
ShelfSlot (Area3D, extends Interactable)
  +- CollisionShape3D (BoxShape3D, ~20cm for raycast detection)
  +- SlotMarker (Marker3D — where the item visual spawns)
  +- ItemVisual (MeshInstance3D — created dynamically when item placed)
  +- PriceTag (Label3D — shows player-set price, created with item)
```

The `ShelfContextPopup` is a shared UI scene instantiated once on the HUD layer, shown/hidden and populated as needed (not per-slot).

## Deliverables

- `game/scripts/core/shelf_slot.gd` — ShelfSlot extending Interactable with placement/removal logic
- Shelf context popup scene (part of HUD layer or standalone)
- Placeholder item visual spawning (rarity-colored BoxMesh + price Label3D)
- EventBus signals: `shelf_slot_activated`, `inventory_item_selected`, `price_panel_requested`
- Category filtering integration with InventoryPanel
- Placement and removal SFX hooks (actual sounds are issue-028)

## Acceptance Criteria

- Interact with empty shelf slot: InventoryPanel opens filtered to eligible backroom items
- Select item from panel: item appears on shelf as colored box, removed from backroom
- Interact with stocked slot: context popup appears with item name, price, Remove/Set Price options
- Click Remove: item returns to backroom, visual removed, slot shows as empty
- Click Set Price: price panel opens for that item (delegates to issue-008)
- Full shelf slot rejects placement (InventorySystem.move_to_shelf returns false)
- Placeholder visual color matches item rarity
- Price tag Label3D shows current player-set price (or "No Price" if unset)
- Prompt text updates correctly when slot state changes
- Multiple slots on same fixture work independently
- Escape or Cancel closes context popup without changes