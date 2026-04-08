# Issue 007: Implement basic inventory UI panel

**Wave**: wave-1
**Milestone**: M1 Foundation + First Playable
**Labels**: `ui`, `phase:m1`, `priority:high`
**Dependencies**: issue-005

## Why This Matters

Players need to see what they own before they can stock shelves or set prices. The inventory panel is the primary interface between the player and the InventorySystem. It opens standalone (I key) for browsing, and contextually when interacting with shelf slots (issue-006) for item placement.

## Design

### Two Opening Modes

1. **Browse mode** (press I key): Shows ALL items — backroom and shelved. Items on shelves are dimmed/tagged with their fixture location. No selection action in this mode (view-only, or future: drag to reorder).

2. **Placement mode** (triggered by shelf interaction, issue-006): Shows only BACKROOM items, filtered by `allowed_categories` from the activated shelf slot. Clicking an item emits `EventBus.inventory_item_selected(instance_id)` and closes the panel.

The panel tracks which mode it's in via an enum:
```gdscript
enum Mode { BROWSE, PLACEMENT }
var current_mode: Mode = Mode.BROWSE
var _filter_categories: PackedStringArray = []
```

### Panel Layout

Slides in from the left side of the screen, covering ~30% of screen width:

```
InventoryPanel (PanelContainer, anchored left, 30% width, full height)
  +- VBoxContainer
       +- Header (HBoxContainer)
       |    +- TitleLabel (Label) — "Backroom Inventory" or "Select Item to Stock"
       |    +- CloseButton (TextureButton) — X to close
       +- FilterBar (HBoxContainer)
       |    +- SortDropdown (OptionButton) — Sort by: Name, Price, Rarity, Condition
       |    +- CategoryFilter (OptionButton) — Filter by category (only in browse mode)
       +- ItemScroll (ScrollContainer, fills remaining space)
       |    +- ItemGrid (GridContainer, 2-3 columns)
       |         +- ItemCell (repeated)
       +- Footer (HBoxContainer)
            +- ItemCountLabel (Label) — "23 items" or "5 items match"
```

### Item Cell Design

Each cell is a `PanelContainer` showing one `ItemInstance`:

```
ItemCell (PanelContainer, ~150x100px, clickable)
  +- VBoxContainer
       +- ItemName (Label) — "Griffey Jr. Rookie" (truncated if long)
       +- HBoxContainer
       |    +- ConditionBadge (Label, colored) — "NM" (abbreviated)
       |    +- RarityDot (ColorRect, 8x8, rarity color)
       +- PriceLabel (Label) — "$37.50" (market value)
       +- LocationTag (Label, small, dim) — "Shelf: Card Case 1" (browse mode only)
```

**Cell colors**:
- Backroom items: normal background
- Shelved items (browse mode): dimmed background, italic name
- Hovered item: highlight border
- In placement mode, clicking a cell selects it

**Condition abbreviations**: Poor → P, Fair → F, Good → G, Near Mint → NM, Mint → M

### Sorting

Default sort: by name (alphabetical). Available sorts:
- **Name**: A-Z alphabetical on `item_name`
- **Price**: High to low by `base_price * condition_multiplier`
- **Rarity**: Legendary first, then very_rare, rare, uncommon, common
- **Condition**: Mint first, then descending

### Filtering

**Browse mode**: CategoryFilter dropdown populated from item categories present in inventory. "All" is default.

**Placement mode**: CategoryFilter is hidden. Items are pre-filtered to:
1. `current_location == "backroom"` (only backroom items)
2. `definition.category in _filter_categories` (from shelf slot's allowed_categories)

### Signal Integration

**Listens to**:
- `EventBus.shelf_slot_activated(fixture_id, slot_index, allowed_categories)` → open in placement mode with category filter
- `EventBus.item_added_to_inventory(instance_id)` → refresh grid if open
- `EventBus.item_stocked(instance_id, fixture_id, slot_index)` → refresh grid / close panel
- `EventBus.item_removed_from_shelf(instance_id)` → refresh grid if open

**Emits**:
- `EventBus.inventory_item_selected(instance_id)` → when item clicked in placement mode

### Input Handling

- `I` key toggles panel (browse mode) — add `"toggle_inventory"` to input map
- `Escape` closes panel in either mode
- Panel opening pauses the interaction raycast (player can't interact with world while panel is open)
- In placement mode, clicking outside the panel or pressing Escape cancels placement and closes panel

### Script: `game/scripts/ui/inventory_panel.gd`

```gdscript
extends PanelContainer

enum Mode { BROWSE, PLACEMENT }

var current_mode: Mode = Mode.BROWSE
var _filter_categories: PackedStringArray = []
var _current_sort: String = "name"
var _items: Array[ItemInstance] = []

func _ready() -> void:
    visible = false
    add_to_group("inventory_panel")
    EventBus.shelf_slot_activated.connect(_on_shelf_slot_activated)
    EventBus.item_stocked.connect(_on_item_stocked)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_inventory"):
        if visible:
            close()
        else:
            open_browse()

func open_browse() -> void:
    current_mode = Mode.BROWSE
    _filter_categories = []
    _refresh_items()
    visible = true

func open_placement(categories: PackedStringArray) -> void:
    current_mode = Mode.PLACEMENT
    _filter_categories = categories
    _refresh_items()
    visible = true

func close() -> void:
    visible = false
    current_mode = Mode.BROWSE

func _on_shelf_slot_activated(_fixture_id: String, _slot_index: int, categories: PackedStringArray) -> void:
    open_placement(categories)

func _on_item_stocked(_instance_id: String, _fixture_id: String, _slot_index: int) -> void:
    if current_mode == Mode.PLACEMENT:
        close()
    elif visible:
        _refresh_items()

func _refresh_items() -> void:
    # Query InventorySystem based on mode
    if current_mode == Mode.PLACEMENT:
        _items = InventorySystem.get_backroom_items()
        if _filter_categories.size() > 0:
            _items = _items.filter(func(item): return item.definition.category in _filter_categories)
    else:
        var backroom = InventorySystem.get_backroom_items()
        var shelved = InventorySystem.get_all_shelf_items()
        _items = backroom + shelved
    _apply_sort()
    _rebuild_grid()

func _on_cell_clicked(instance_id: String) -> void:
    if current_mode == Mode.PLACEMENT:
        EventBus.inventory_item_selected.emit(instance_id)
```

### Performance

For M1, the sports store has at most ~100 items (backroom_capacity). A simple rebuild of the grid on each refresh is fine. No virtualized scrolling needed yet.

## Deliverables

- `game/scenes/ui/inventory_panel.tscn` — Panel scene with grid, header, filter bar
- `game/scripts/ui/inventory_panel.gd` — Panel script with browse/placement modes
- `game/scripts/ui/item_cell.gd` — Individual item cell component
- Item cell scene (PanelContainer with name, condition, rarity, price)
- Sort dropdown (name, price, rarity, condition)
- Category filter dropdown (browse mode only)
- Input map entry for `toggle_inventory` (I key)
- Signal connections to EventBus for shelf interaction integration

## Acceptance Criteria

- Press I: panel slides in showing all inventory items (backroom + shelved)
- Shelved items appear dimmed with location tag
- Press I again or Escape: panel closes
- Shelf interaction (issue-006) opens panel in placement mode: only backroom items shown, filtered by category
- Click item in placement mode: `inventory_item_selected` signal emits with instance_id
- Sort by name/price/rarity/condition works correctly
- Scroll works when items exceed visible area
- Item cells show: name, condition badge, rarity color, market price
- Panel covers ~30% of screen width, doesn't obscure center
- Item count footer updates with current filter results
- Empty state shows "No items" or "No matching items" message