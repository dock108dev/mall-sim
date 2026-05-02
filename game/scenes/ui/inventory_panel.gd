## Left-dock inventory panel with stock tabs, search/filter, and context menu.
class_name InventoryPanel
extends CanvasLayer

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
var _focus_pushed: bool = false
var _backdrop: ColorRect
var _cell_map: Dictionary = {}
var _store_inventory: Array[Dictionary] = []
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
	if _focus_pushed:
		_pop_modal_focus()


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


func _push_modal_focus() -> void:
	if _focus_pushed:
		return
	InputFocus.push_context(InputFocus.CTX_MODAL)
	_focus_pushed = true


func _pop_modal_focus() -> void:
	if not _focus_pushed:
		return
	# Defensive: if the topmost frame is no longer CTX_MODAL, a sibling pushed
	# without going through this contract. Surface it via push_error AND skip
	# the pop so we don't corrupt someone else's frame. assert() alone would
	# be stripped from release builds and silently double-pop the wrong frame.
	if InputFocus.current() != InputFocus.CTX_MODAL:
		push_error(
			(
				"InventoryPanel.close: expected CTX_MODAL on top, got %s — "
				+ "leaving stack untouched to avoid corrupting sibling frame"
			)
			% String(InputFocus.current())
		)
		_focus_pushed = false
		return
	InputFocus.pop_context()
	_focus_pushed = false


func _on_scene_ready(_target: StringName, _payload: Dictionary) -> void:
	# Modals never survive a scene change. Force-close (popping our frame)
	# before the new scene's gameplay context becomes the audited top of stack.
	# Research §4.2. Placement mode also retains a CTX_MODAL frame between the
	# panel-hide and the shelf-slot click; tear that down as well.
	if _is_open:
		close(true)
		return
	if _shelf_actions.is_placement_mode:
		_shelf_actions.exit_placement_mode()
	if _focus_pushed:
		_pop_modal_focus()


## Test seam — clears _focus_pushed without calling pop_context. Pair with
## InputFocus._reset_for_tests() so test harnesses that wipe the focus stack
## don't leave the panel believing it still owns a frame.
func _reset_for_tests() -> void:
	_focus_pushed = false


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
		_empty_label.text = "No active store selected"
		_empty_label.visible = true
		_scroll.visible = false
		_footer_count.text = "No active store"
		_footer_value.text = "Value: $0.00"
		return
	var items: Array[ItemInstance] = _get_filtered_items()
	_empty_label.text = "No items found"
	_empty_label.visible = items.is_empty()
	_scroll.visible = not items.is_empty()
	for item: ItemInstance in items:
		_add_item_row(item)
	_footer_count.text = _build_count_label(items.size())
	_footer_value.text = (
		"Value: $%.2f" % InventoryFilter.total_value(items)
	)


func _clear_grid() -> void:
	_cell_map.clear()
	for child: Node in _grid.get_children():
		child.queue_free()


func _add_item_row(item: ItemInstance) -> void:
	var row: PanelContainer = InventoryRowBuilder.build(
		item, rental_controller
	)
	InventoryRowBuilder.add_overlay_button(
		row,
		_on_item_clicked.bind(item, row),
		_on_cell_mouse_entered.bind(item),
		_on_cell_mouse_exited,
	)
	_grid.add_child(row)
	_cell_map[row] = item


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
			var item_for_placement := _selected_item
			# Hide the panel visually but RETAIN the CTX_MODAL frame so the
			# interaction prompt and objective rail stay suppressed during the
			# shelf-slot selection phase. The frame is released when placement
			# mode ends (place / cancel / panel close), via
			# _on_placement_mode_exited.
			_close_keeping_modal_focus()
			_selected_item = item_for_placement
			_shelf_actions.enter_placement_mode(item_for_placement)
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
