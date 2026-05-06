## Left-dock inventory panel with stock tabs, search/filter, and context menu.
##
## Inherits the `_focus_pushed` / `_push_modal_focus` / `_pop_modal_focus` /
## `_exit_tree` auto-pop / `_reset_for_tests` contract from `ModalPanel`.
## The custom `open(source)` / `close(immediate)` shapes wrap the inherited
## helpers rather than calling `super.open()` / `super.close()` directly.
class_name InventoryPanel
extends ModalPanel

enum Tab { BACKROOM, SHELVES, ALL }

# Localization marker for static validation: tr("INVENTORY_CONDITION")

const PANEL_NAME: String = "inventory"
const SOURCE_BACKROOM: String = "backroom"
const SOURCE_SHELVES: String = "shelves"
const SOURCE_ALL: String = "all"

var inventory_system: InventorySystem
var store_id: String = ""
var refurbishment_dialog: RefurbishmentDialog = null
var refurbishment_system: RefurbishmentSystem = null
var testing_system: TestingSystem = null
var rental_controller: VideoRentalStoreController = null
var pack_controller: PocketCreaturesStoreController = null
var pack_opening_panel: PackOpeningPanel = null
var electronics_controller: ElectronicsStoreController = null
var pricing_panel: PricingPanel = null
var order_panel: OrderPanel = null

var _selected_item: ItemInstance = null
var _is_open: bool = false
var _backdrop: ColorRect
var _cell_map: Dictionary = {}
var _store_inventory: Array[Dictionary] = []
var _quantity_map: Dictionary = {}
var _active_tab: Tab = Tab.BACKROOM
var _anim_tween: Tween
var _rest_x: float = 0.0
var _shelf_actions := InventoryShelfActions.new()

@onready var _panel: PanelContainer = $PanelRoot
@onready var _backroom_tab: Button = (
	$PanelRoot/Margin/VBox/TabBar/BackroomTab
)
@onready var _shelves_tab: Button = (
	$PanelRoot/Margin/VBox/TabBar/ShelvesTab
)
@onready var _all_tab: Button = (
	$PanelRoot/Margin/VBox/TabBar/AllTab
)
@onready var _search_field: LineEdit = (
	$PanelRoot/Margin/VBox/SearchField
)
@onready var _filter_row: HBoxContainer = (
	$PanelRoot/Margin/VBox/FilterRow
)
@onready var _condition_filter: OptionButton = (
	$PanelRoot/Margin/VBox/FilterRow/ConditionFilter
)
@onready var _rarity_filter: OptionButton = (
	$PanelRoot/Margin/VBox/FilterRow/RarityFilter
)
@onready var _scroll: ScrollContainer = (
	$PanelRoot/Margin/VBox/ItemList/Scroll
)
@onready var _grid: VBoxContainer = (
	$PanelRoot/Margin/VBox/ItemList/Scroll/ItemGrid
)
@onready var _empty_label: Label = (
	$PanelRoot/Margin/VBox/ItemList/EmptyLabel
)
@onready var _context_menu: PopupMenu = $ContextMenu
@onready var _footer_count: Label = (
	$PanelRoot/Margin/VBox/Footer/CountLabel
)
@onready var _footer_value: Label = (
	$PanelRoot/Margin/VBox/Footer/ValueLabel
)
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/Header/CloseButton
)


func _ready() -> void:
	_panel.visible = false
	_rest_x = _panel.position.x
	_close_button.pressed.connect(close)
	_backroom_tab.pressed.connect(_on_tab_pressed.bind(Tab.BACKROOM))
	_shelves_tab.pressed.connect(_on_tab_pressed.bind(Tab.SHELVES))
	_all_tab.pressed.connect(_on_tab_pressed.bind(Tab.ALL))
	_search_field.text_changed.connect(_on_search_changed)
	_condition_filter.item_selected.connect(_on_filter_changed)
	_rarity_filter.item_selected.connect(_on_filter_changed)
	_context_menu.id_pressed.connect(_on_context_action)
	InventoryFilter.populate_condition_options(_condition_filter)
	InventoryFilter.populate_rarity_options(_rarity_filter)
	_update_tab_visuals()
	EventBus.interactable_interacted.connect(
		_on_interactable_interacted
	)
	EventBus.interactable_right_clicked.connect(
		_on_interactable_right_clicked
	)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.price_set.connect(_on_price_set)
	EventBus.active_store_changed.connect(_on_active_store_changed)
	EventBus.placement_mode_exited.connect(_on_placement_mode_exited)
	SceneRouter.scene_ready.connect(_on_scene_ready)
	_sync_active_store()
	_setup_modal_backdrop()


func _exit_tree() -> void:
	# Exit placement mode first so the cursor reverts and the
	# placement_mode_exited signal fires; that handler also pops the frame.
	if _shelf_actions.is_placement_mode:
		_shelf_actions.exit_placement_mode()
	# Defer to ModalPanel's auto-pop guard for the dangling-frame case.
	super._exit_tree()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _shelf_actions.is_placement_mode:
				_shelf_actions.exit_placement_mode()
				get_viewport().set_input_as_handled()
				return
		if (
			mb.button_index == MOUSE_BUTTON_LEFT
			and mb.pressed
			and _is_open
			and not _panel.get_global_rect().has_point(mb.position)
			and not _context_menu.visible
		):
			close()
			get_viewport().set_input_as_handled()
			return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.is_action_pressed("toggle_inventory"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif key_event.is_action_pressed("quick_stock") and _is_open:
		_quick_stock_first_backroom_item()
		get_viewport().set_input_as_handled()
	elif key_event.is_action_pressed("ui_cancel"):
		if _shelf_actions.is_placement_mode:
			_shelf_actions.exit_placement_mode()
			get_viewport().set_input_as_handled()
		elif _is_open:
			close(true)
			get_viewport().set_input_as_handled()


func open(source: String = SOURCE_BACKROOM) -> void:
	if _is_open:
		return
	if not inventory_system:
		push_warning("InventoryPanel: no inventory_system assigned")
		return
	PanelAnimator.kill_tween(_anim_tween)
	_sync_active_store()
	_shelf_actions.inventory_system = inventory_system
	match source:
		SOURCE_SHELVES:
			_active_tab = Tab.SHELVES
		SOURCE_ALL:
			_active_tab = Tab.ALL
		_:
			_active_tab = Tab.BACKROOM
	_is_open = true
	_selected_item = null
	_search_field.text = ""
	_update_tab_visuals()
	_refresh_grid()
	_anim_tween = PanelAnimator.slide_open(
		_panel, _rest_x, true
	)
	# Emit FIRST so any sibling panels' mutual-exclusion handlers run their
	# close(true) and pop their own frames, THEN claim modal focus on top of
	# whatever world context was current. See research §4.1.
	EventBus.panel_opened.emit(PANEL_NAME)
	_push_modal_focus()
	_backdrop.visible = true


func close(immediate: bool = false) -> void:
	if not _is_open:
		return
	PanelAnimator.kill_tween(_anim_tween)
	_shelf_actions.exit_placement_mode()
	_is_open = false
	_selected_item = null
	if immediate:
		_panel.visible = false
		_panel.position.x = _rest_x
	else:
		_anim_tween = PanelAnimator.slide_close(
			_panel, _rest_x, true
		)
	# Pop FIRST while CTX_MODAL is still on top, THEN broadcast close. See
	# research §4.1.
	_backdrop.visible = false
	_pop_modal_focus()
	EventBus.item_tooltip_hidden.emit()
	EventBus.panel_closed.emit(PANEL_NAME)


## Hides the panel like close() but keeps the CTX_MODAL frame on the stack so
## downstream overlays (InteractionPrompt, ObjectiveRail) remain suppressed
## during the placement-mode shelf-slot selection phase. The frame is released
## by _on_placement_mode_exited when placement ends.
func _close_keeping_modal_focus() -> void:
	if not _is_open:
		return
	PanelAnimator.kill_tween(_anim_tween)
	_is_open = false
	_selected_item = null
	_anim_tween = PanelAnimator.slide_close(
		_panel, _rest_x, true
	)
	_backdrop.visible = false
	EventBus.item_tooltip_hidden.emit()
	EventBus.panel_closed.emit(PANEL_NAME)


## Releases the retained CTX_MODAL frame when placement mode ends. Only pops
## when the panel itself is hidden (placement-only state); if the panel is
## currently open, the close() path will pop the frame instead.
func _on_placement_mode_exited() -> void:
	if _focus_pushed and not _is_open:
		_pop_modal_focus()


func _on_scene_ready(_target: StringName, _payload: Dictionary) -> void:
	# Modals never survive a scene change. Force-close (popping our frame)
	# before the new scene's gameplay context becomes the audited top of stack.
	# Placement mode also retains a CTX_MODAL frame between the panel-hide
	# and the shelf-slot click; tear that down as well.
	if _is_open:
		close(true)
		return
	if _shelf_actions.is_placement_mode:
		_shelf_actions.exit_placement_mode()
	if _focus_pushed:
		_pop_modal_focus()


func _setup_modal_backdrop() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.5)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.visible = false
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)
	move_child(_backdrop, 0)


func _on_backdrop_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		if _context_menu.visible:
			return
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _is_open


func _toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _on_tab_pressed(tab: Tab) -> void:
	if _active_tab == tab:
		return
	_active_tab = tab
	_selected_item = null
	_update_tab_visuals()
	_refresh_grid()


func _update_tab_visuals() -> void:
	var active := Color(0.7, 1.0, 0.7)
	_backroom_tab.button_pressed = _active_tab == Tab.BACKROOM
	_shelves_tab.button_pressed = _active_tab == Tab.SHELVES
	_all_tab.button_pressed = _active_tab == Tab.ALL
	_backroom_tab.modulate = (
		active if _active_tab == Tab.BACKROOM else Color.WHITE
	)
	_shelves_tab.modulate = (
		active if _active_tab == Tab.SHELVES else Color.WHITE
	)
	_all_tab.modulate = (
		active if _active_tab == Tab.ALL else Color.WHITE
	)


func _on_search_changed(_new_text: String) -> void:
	_refresh_grid()


func _on_filter_changed(_index: int) -> void:
	_refresh_grid()


func _get_filtered_items() -> Array[ItemInstance]:
	if not inventory_system:
		return []
	var items: Array[ItemInstance] = []
	_store_inventory = inventory_system.get_store_inventory(
		StringName(store_id)
	)
	for entry: Dictionary in _store_inventory:
		var item: ItemInstance = entry.get("item", null) as ItemInstance
		if not item:
			continue
		var location: String = str(entry.get("location", ""))
		if _active_tab == Tab.BACKROOM and location != "backroom":
			continue
		if _active_tab == Tab.SHELVES and not location.begins_with("shelf:"):
			continue
		items.append(item)
	return InventoryFilter.apply(
		items,
		_search_field.text,
		InventoryFilter.condition_at_index(
			_condition_filter.selected
		),
		InventoryFilter.rarity_at_index(_rarity_filter.selected),
	)


func _refresh_grid() -> void:
	_clear_grid()
	if store_id.is_empty():
		# Day-1 contract: ISSUE-001 wires `active_store_changed` so that by the
		# time the panel can be opened, GameManager has an active store. Hitting
		# this path is a regression of that wiring — surfaced as push_warning
		# (not push_error) because `test_inventory_panel.gd
		# ::test_refresh_with_empty_store_id_falls_back_safely` exercises the
		# graceful-degradation contract on purpose; escalating would fail
		# CI's stderr `^ERROR:` scan
		# (.github/workflows/validate.yml). The fallback UI ("No active store")
		# below is the asserted behavior. See
		# docs/audits/error-handling-report.md §EH-10.
		push_warning(
			"InventoryPanel: refresh requested with no active store; "
			+ "expected active_store_changed to have fired before open()."
		)
		_empty_label.text = "No active store selected"
		_empty_label.visible = true
		_scroll.visible = false
		_footer_count.text = "No active store"
		_footer_value.text = "Value: $0.00"
		return
	var items: Array[ItemInstance] = _get_filtered_items()
	_quantity_map = _build_quantity_map(_store_inventory)
	_refresh_filter_visibility()
	_empty_label.text = "No items found"
	_empty_label.visible = items.is_empty()
	_scroll.visible = not items.is_empty()
	for item: ItemInstance in items:
		_add_item_row(item)
	_footer_count.text = _build_count_label(items.size())
	_footer_value.text = (
		"Value: $%.2f" % InventoryFilter.total_value(items)
	)


## Hides condition / rarity dropdowns when the underlying store inventory has
## only a single distinct value for that axis — a filter that can only select
## "All" reads as a dead control. Day 1 starter inventories collapse to a
## single condition + rarity, so the filter row hides entirely until a later
## day brings in items that actually vary. The whole row hides when both
## individual filters are hidden.
func _refresh_filter_visibility() -> void:
	# §F-104 — `@onready var _filter_row` only resolves once the panel is
	# in-tree; bare-Control unit-test fixtures hit this guard. The
	# `_get_active_store_shelf_slots` SceneTree-null guard below shares the
	# same Tier-5 onready/test-seam contract.
	if _filter_row == null:
		return
	var conditions: Dictionary = {}
	var rarities: Dictionary = {}
	for entry: Dictionary in _store_inventory:
		var item: ItemInstance = entry.get("item", null) as ItemInstance
		if item == null or item.definition == null:
			continue
		conditions[item.condition] = true
		rarities[item.definition.rarity] = true
	var show_condition: bool = conditions.size() > 1
	var show_rarity: bool = rarities.size() > 1
	_condition_filter.visible = show_condition
	_rarity_filter.visible = show_rarity
	# Reset a hidden filter to "All" so a stale selection cannot suppress
	# items the user can no longer see in the dropdown.
	if not show_condition:
		_condition_filter.selected = 0
	if not show_rarity:
		_rarity_filter.selected = 0
	_filter_row.visible = show_condition or show_rarity


## Aggregates per-definition counts of backroom and on-shelf instances over
## the active store's inventory rows. Returns a Dictionary keyed by
## definition_id (String) -> { "backroom": int, "on_shelf": int }.
static func _build_quantity_map(
	store_inventory: Array[Dictionary]
) -> Dictionary:
	var map: Dictionary = {}
	for entry: Dictionary in store_inventory:
		var item: ItemInstance = entry.get("item", null) as ItemInstance
		if item == null or item.definition == null:
			continue
		var def_id: String = item.definition.id
		if not map.has(def_id):
			map[def_id] = {"backroom": 0, "on_shelf": 0}
		var loc: String = str(entry.get("location", ""))
		if loc == "backroom":
			map[def_id]["backroom"] = int(map[def_id]["backroom"]) + 1
		elif loc.begins_with("shelf:"):
			map[def_id]["on_shelf"] = int(map[def_id]["on_shelf"]) + 1
	return map


func _clear_grid() -> void:
	_cell_map.clear()
	for child: Node in _grid.get_children():
		child.queue_free()


func _add_item_row(item: ItemInstance) -> void:
	var row: PanelContainer = InventoryRowBuilder.build(
		item, rental_controller, _quantity_map
	)
	var overlay: Button = InventoryRowBuilder.add_overlay_button(
		row,
		_on_item_clicked.bind(item, row),
		_on_cell_mouse_entered.bind(item),
		_on_cell_mouse_exited,
	)
	# One-click stocking on backroom items, one-click unstocking on shelf items.
	# The placement-mode (aim-and-click in the world) flow remains accessible
	# via the context-menu "Move to Shelf" action.
	if item.current_location == "backroom":
		InventoryRowBuilder.add_stock_buttons(
			overlay,
			_on_stock_one.bind(item, row),
			_on_stock_max.bind(item, row),
		)
	elif item.current_location.begins_with("shelf:"):
		InventoryRowBuilder.add_remove_button(
			overlay,
			_on_remove_from_shelf.bind(item, row),
		)
	_grid.add_child(row)
	_cell_map[row] = item


## Quick-stock shortcut bound to the `quick_stock` action (Q). Routes the first
## backroom item in the active store to the first compatible empty shelf slot,
## skipping the per-row Stock 1 click. Falls back to a notification when the
## backroom is empty or no compatible slot exists. Goes through the same
## `stock_one` path as the row button so item_stocked / inventory_changed fire
## normally and downstream listeners (PricingPanel, ObjectiveDirector) react
## without needing a separate signal contract.
func _quick_stock_first_backroom_item() -> void:
	if not inventory_system:
		# §F-143 — The panel is open (gated by `_is_open` in
		# `_unhandled_input`) and the player pressed Q expecting an action.
		# A null `inventory_system` here means the Tier-3 wiring
		# (`set_inventory_system` from the store controller) never ran for
		# the active store — a production regression, not a normal state.
		# Surface it so the silent shortcut failure has a paper trail.
		push_warning(
			"InventoryPanel: quick_stock pressed with no inventory_system wired"
		)
		return
	var first: ItemInstance = _first_backroom_item()
	if first == null:
		EventBus.notification_requested.emit(tr("INVENTORY_NO_AVAILABLE_SLOT"))
		return
	_shelf_actions.inventory_system = inventory_system
	if not _shelf_actions.stock_one(first, _get_active_store_shelf_slots()):
		EventBus.notification_requested.emit(tr("INVENTORY_NO_AVAILABLE_SLOT"))


## Returns the first backroom item for the active store. Bypasses the UI filter
## (search/condition/rarity dropdowns) on purpose: the quick-stock shortcut is a
## skip-the-list affordance, so it always targets the next available unit
## regardless of what the player has typed into the search box. Returns null
## when the backroom view is empty.
func _first_backroom_item() -> ItemInstance:
	if inventory_system == null or store_id.is_empty():
		return null
	var items: Array[ItemInstance] = (
		inventory_system.get_backroom_items_for_store(store_id)
	)
	if items.is_empty():
		return null
	return items[0]


func _on_stock_one(item: ItemInstance, row: PanelContainer) -> void:
	_prep_row_action(item, row)
	if not _shelf_actions.stock_one(item, _get_active_store_shelf_slots()):
		EventBus.notification_requested.emit(tr("INVENTORY_NO_AVAILABLE_SLOT"))


func _on_stock_max(item: ItemInstance, row: PanelContainer) -> void:
	_prep_row_action(item, row)
	var placed: int = _shelf_actions.stock_max(
		item, _get_active_store_shelf_slots()
	)
	if placed <= 0:
		EventBus.notification_requested.emit(tr("INVENTORY_NO_AVAILABLE_SLOT"))


func _on_remove_from_shelf(
	item: ItemInstance, row: PanelContainer
) -> void:
	_prep_row_action(item, row)
	if not item.current_location.begins_with("shelf:"):
		# §F-97 / error-handling-report.md §3 — UI invariant: the per-row
		# Remove button is only built when `item.current_location` starts with
		# `shelf:` (see `inventory_row_builder.add_remove_button` gating in
		# `_populate_grid`). Reaching this branch means a button was offered
		# for a non-shelf item — a row-builder regression, not a legitimate
		# state. Escalated to push_error so CI's stderr scan fails on the
		# regression instead of silently skipping the click.
		push_error(
			(
				"InventoryPanel._on_remove_from_shelf: row built for non-shelf "
				+ "item (instance_id=%s, location=%s); ignoring."
			)
			% [item.instance_id, item.current_location]
		)
		return
	var slot_id: String = item.current_location.substr(6)
	var slot: ShelfSlot = _find_shelf_slot_by_id(slot_id)
	if slot != null:
		_shelf_actions.remove_item_from_shelf(slot)
		return
	# No matching world slot (e.g. headless test, hub-mode reconciliation):
	# fall back to the inventory-side move so backroom qty still updates.
	_shelf_actions.move_to_backroom(item)


## Shared preamble for the row-button handlers (`_on_stock_one`,
## `_on_stock_max`, `_on_remove_from_shelf`): highlight the row, latch the
## selection, and mirror `inventory_system` onto `_shelf_actions`. `open()`
## also wires the helper, so the explicit sync covers paths where the row
## button fires without a prior `open()` (unit tests, state-restored panels).
func _prep_row_action(item: ItemInstance, row: PanelContainer) -> void:
	_highlight_selected(row)
	_selected_item = item
	if inventory_system != null:
		_shelf_actions.inventory_system = inventory_system


func _get_active_store_shelf_slots() -> Array:
	# §F-104 — Same Tier-5 SceneTree-null test-seam as the filter-row guard
	# above. Helper callers (`_on_stock_one`, `_on_stock_max`) surface failure
	# via `EventBus.notification_requested`, so the empty array is the
	# documented "no slots available" path that the UX layer handles.
	var tree: SceneTree = get_tree()
	if tree == null:
		return []
	return tree.get_nodes_in_group(&"shelf_slot")


## §F-96 — Empty `slot_id` is rejected. `slot.slot_id` defaults to `""` on
## `ShelfSlot` (see `shelf_slot.gd:81`); the `&"shelf_slot"` group walks every
## slot in the tree (potentially across multiple stores or test fixtures), so
## a hand-edited save with `current_location = "shelf:"` would otherwise match
## the first empty-id slot and trigger a wrong-slot remove. Caller-side fall-
## through to `move_to_backroom(item)` covers the rejection.
func _find_shelf_slot_by_id(slot_id: String) -> ShelfSlot:
	if slot_id.is_empty():
		return null
	for node: Node in _get_active_store_shelf_slots():
		if not (node is ShelfSlot):
			continue
		var slot := node as ShelfSlot
		if slot.slot_id == slot_id:
			return slot
	return null


## Hides the panel visually but RETAINS the CTX_MODAL frame so the
## InteractionPrompt and ObjectiveRail stay suppressed during the shelf-slot
## selection phase. The frame is released when placement mode ends (place /
## cancel / panel close), via _on_placement_mode_exited.
##
## `_close_keeping_modal_focus` clears `_selected_item`; the field is
## re-assigned afterwards so consumers reading panel state during placement
## see the in-flight selection.
func _begin_placement_mode(item: ItemInstance) -> void:
	_close_keeping_modal_focus()
	_selected_item = item
	_shelf_actions.enter_placement_mode(item)


func _on_item_clicked(
	item: ItemInstance, row: PanelContainer
) -> void:
	_selected_item = item
	_highlight_selected(row)
	_show_context_menu(item)


func _highlight_selected(active: PanelContainer) -> void:
	for child: Node in _grid.get_children():
		if child is PanelContainer:
			(child as PanelContainer).modulate = Color.WHITE
	active.modulate = Color(0.7, 1.0, 0.7)


func _show_context_menu(item: ItemInstance) -> void:
	_context_menu.clear()
	_context_menu.add_item("Set Price", 0)
	if item.current_location == "backroom":
		_context_menu.add_item("Move to Shelf", 1)
	elif item.current_location.begins_with("shelf:"):
		_context_menu.add_item("Move to Backroom", 2)
	_context_menu.add_item("Order More", 3)
	if testing_system and testing_system.can_test(item):
		_context_menu.add_item("Test Item", 4)
	if refurbishment_system and refurbishment_system.can_refurbish(item):
		_context_menu.add_item("Refurbish", 5)
	if _can_open_pack(item):
		_context_menu.add_item("Open Pack", 6)
	if _can_set_as_demo(item):
		_context_menu.add_item("Set as Demo", 7)
	if _can_remove_from_demo(item):
		_context_menu.add_item("Remove from Demo", 8)
	if _can_try_demo(item):
		_context_menu.add_item("Try Demo", 11)
	if _can_retire_tape(item):
		_context_menu.add_item("Retire (Sell)", 9)
		_context_menu.add_item("Write Off", 10)
	_context_menu.reset_size()
	var pos: Vector2 = _panel.get_global_mouse_position()
	_context_menu.position = Vector2i(int(pos.x), int(pos.y))
	_context_menu.popup()


func _on_context_action(id: int) -> void:
	if not _selected_item:
		return
	match id:
		0:
			_open_pricing_for_selected_item()
		1:
			_begin_placement_mode(_selected_item)
		2:
			_shelf_actions.move_to_backroom(_selected_item)
			_selected_item = null
		3:
			_open_orders_for_selected_item()
		4:
			if testing_system:
				testing_system.start_test(_selected_item.instance_id)
		5:
			if refurbishment_dialog and _selected_item:
				refurbishment_dialog.open(_selected_item)
		6:
			_open_selected_pack()
		7:
			_set_selected_as_demo()
		8:
			_remove_selected_from_demo()
		9:
			_retire_selected_tape(true)
		10:
			_retire_selected_tape(false)
		11:
			if electronics_controller and _selected_item:
				electronics_controller.try_demo_interaction(
					_selected_item.instance_id
				)


func _on_interactable_interacted(
	target: Interactable, type: int
) -> void:
	if type == Interactable.InteractionType.BACKROOM:
		if not _is_open:
			open(SOURCE_BACKROOM)
		return
	if type == Interactable.InteractionType.RETURNS_BIN:
		if not _is_open:
			open(SOURCE_BACKROOM)
		return
	if type == Interactable.InteractionType.SHELF_SLOT:
		if (
			_shelf_actions.is_placement_mode
			and _selected_item
			and target is ShelfSlot
		):
			if _shelf_actions.place_item(
				_selected_item, target as ShelfSlot
			):
				_selected_item = null
		elif not _is_open and target is ShelfSlot:
			var slot := target as ShelfSlot
			if not slot.is_occupied():
				open()


func _on_interactable_right_clicked(
	target: Interactable, type: int
) -> void:
	if type != Interactable.InteractionType.SHELF_SLOT:
		return
	if _shelf_actions.is_placement_mode:
		_shelf_actions.exit_placement_mode()
		return
	if not target is ShelfSlot:
		return
	var slot := target as ShelfSlot
	if slot.is_occupied():
		_shelf_actions.remove_item_from_shelf(slot)


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _on_inventory_changed() -> void:
	if not _is_open:
		return
	if _selected_item:
		if not inventory_system.get_item(
			_selected_item.instance_id
		):
			_selected_item = null
	_refresh_grid()


## PricingPanel writes player_set_price directly on the ItemInstance and emits
## price_set without going through inventory_system.move_item, so the
## inventory_changed handler above does not fire. Refresh the grid here so the
## per-row price column reflects the new value with no stale display.
func _on_price_set(_item_id: String, _price: float) -> void:
	if not _is_open:
		return
	_refresh_grid()


func _on_active_store_changed(new_store_id: StringName) -> void:
	store_id = String(new_store_id)
	_apply_store_accent(new_store_id)
	if _is_open:
		_selected_item = null
		EventBus.item_tooltip_hidden.emit()
		call_deferred("_refresh_grid")


func _apply_store_accent(store_id_sn: StringName) -> void:
	var accent: Color = UIThemeConstants.get_store_accent(store_id_sn)
	var style := StyleBoxFlat.new()
	style.bg_color = UIThemeConstants.DARK_PANEL_FILL
	style.border_color = accent
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override(&"panel", style)


func _on_cell_mouse_entered(item: ItemInstance) -> void:
	EventBus.item_tooltip_requested.emit(item)


func _on_cell_mouse_exited() -> void:
	EventBus.item_tooltip_hidden.emit()


func _build_count_label(visible_count: int) -> String:
	if store_id.is_empty():
		return "No active store"
	if not rental_controller:
		return "%d items" % visible_count
	var available: int = rental_controller.get_available_count()
	var rented: int = rental_controller.get_rented_count()
	return "%d available / %d rented" % [available, rented]


func _can_open_pack(item: ItemInstance) -> bool:
	if not pack_controller or not pack_opening_panel:
		return false
	return pack_controller.is_openable_pack(item)


func _open_selected_pack() -> void:
	if not _selected_item or not pack_controller:
		return
	if not pack_controller.is_openable_pack(_selected_item):
		return
	if not pack_controller.can_afford_pack(_selected_item):
		EventBus.transaction_completed.emit(
			0.0, false, "Insufficient funds to open pack."
		)
		return
	var instance_id: String = _selected_item.instance_id
	_selected_item = null
	var cards: Array[ItemInstance] = (
		pack_controller.open_pack_with_cards(
			StringName(instance_id)
		)
	)
	if cards.is_empty():
		return
	pack_opening_panel.pack_opening_system = (
		pack_controller.pack_opening_system
	)
	var card_dicts: Array[Dictionary] = []
	var preview_count: int = mini(
		cards.size(),
		PackOpeningPanel.CARDS_PER_PACK
	)
	for i: int in range(preview_count):
		var card: ItemInstance = cards[i]
		var entry: Dictionary = {
			"id": card.instance_id,
			"name": card.definition.item_name if card.definition else "Unknown",
			"rarity": (
				pack_controller.pack_opening_system.get_preview_rarity(card)
				if pack_controller.pack_opening_system
				else "common"
			),
			"value": card.get_current_value(),
		}
		card_dicts.append(entry)
	EventBus.pack_opening_started.emit(instance_id, card_dicts)


func _can_set_as_demo(item: ItemInstance) -> bool:
	if not electronics_controller:
		return false
	return electronics_controller.can_demo_item(item)


func _can_remove_from_demo(item: ItemInstance) -> bool:
	if not electronics_controller:
		return false
	return item.is_demo \
		and electronics_controller.is_demo_unit(item.instance_id)


func _can_try_demo(item: ItemInstance) -> bool:
	if not electronics_controller:
		return false
	return item.is_demo \
		and electronics_controller.is_demo_unit(item.instance_id)


func _set_selected_as_demo() -> void:
	if not _selected_item or not electronics_controller:
		return
	var success: bool = electronics_controller.place_demo_item(
		_selected_item.instance_id
	)
	if success:
		_selected_item = null
		_refresh_grid()


func _remove_selected_from_demo() -> void:
	if not _selected_item or not electronics_controller:
		return
	var success: bool = electronics_controller.remove_demo_item(
		_selected_item.instance_id
	)
	if success:
		_selected_item = null
		_refresh_grid()


func _can_retire_tape(item: ItemInstance) -> bool:
	if not rental_controller:
		return false
	return rental_controller.is_worn_out(item)


func _retire_selected_tape(sell: bool) -> void:
	if not _selected_item or not rental_controller:
		return
	var instance_id: String = _selected_item.instance_id
	var success: bool = rental_controller.retire_tape(
		instance_id, sell
	)
	if success:
		_selected_item = null
		_refresh_grid()


func _sync_active_store() -> void:
	store_id = String(GameManager.get_active_store_id())


func _open_pricing_for_selected_item() -> void:
	if not _selected_item:
		return
	if pricing_panel:
		pricing_panel.open_for_item(_selected_item)
		return
	EventBus.panel_opened.emit("pricing")


func _open_orders_for_selected_item() -> void:
	if not _selected_item:
		return
	if order_panel and _selected_item.definition:
		order_panel.open_for_item_type(StringName(_selected_item.definition.id))
		return
	EventBus.panel_opened.emit("orders")
