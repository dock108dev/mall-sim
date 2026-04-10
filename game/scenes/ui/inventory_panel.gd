## Inventory management panel displaying backroom or returns bin items.
class_name InventoryPanel
extends CanvasLayer

const PANEL_NAME: String = "inventory"
const SOURCE_BACKROOM: String = "backroom"
const SOURCE_RETURNS_BIN: String = "returns_bin"

var inventory_system: InventorySystem
var store_id: String = ""
var refurbishment_dialog: RefurbishmentDialog = null
var refurbishment_system: RefurbishmentSystem = null
var rental_controller: VideoRentalStoreController = null
var pack_controller: PocketCreaturesStoreController = null
var pack_opening_panel: PackOpeningPanel = null

var _selected_item: ItemInstance = null
var _is_open: bool = false
var _cell_map: Dictionary = {}
var _placement_mode: bool = false
var _source_location: String = SOURCE_BACKROOM
var _anim_tween: Tween
var _rest_x: float = 0.0

@onready var _panel: PanelContainer = $PanelRoot
@onready var _grid: GridContainer = (
	$PanelRoot/Margin/VBox/Content/LeftSide/Scroll/Grid
)
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/Header/CloseButton
)
@onready var _capacity_label: Label = (
	$PanelRoot/Margin/VBox/Header/CapacityLabel
)
@onready var _empty_label: Label = (
	$PanelRoot/Margin/VBox/Content/LeftSide/EmptyLabel
)
@onready var _scroll: ScrollContainer = (
	$PanelRoot/Margin/VBox/Content/LeftSide/Scroll
)
@onready var _detail_panel: PanelContainer = (
	$PanelRoot/Margin/VBox/Content/DetailPanel
)
@onready var _detail_name: Label = (
	$PanelRoot/Margin/VBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailName
)
@onready var _detail_condition: Label = (
	$PanelRoot/Margin/VBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailCondition
)
@onready var _detail_rarity: Label = (
	$PanelRoot/Margin/VBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailRarity
)
@onready var _detail_base_price: Label = (
	$PanelRoot/Margin/VBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailBasePrice
)
@onready var _detail_value: Label = (
	$PanelRoot/Margin/VBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailValue
)
@onready var _detail_description: Label = (
	$PanelRoot/Margin/VBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailDescription
)
@onready var _detail_placeholder: Label = (
	$PanelRoot/Margin/VBox/Content/DetailPanel/DetailMargin/DetailVBox/DetailPlaceholder
)
@onready var _refurbish_button: Button = (
	$PanelRoot/Margin/VBox/Content/DetailPanel/DetailMargin/DetailVBox/RefurbishButton
)
@onready var _open_pack_button: Button = (
	$PanelRoot/Margin/VBox/Content/DetailPanel/DetailMargin/DetailVBox/OpenPackButton
)


func _ready() -> void:
	_panel.visible = false
	_rest_x = _panel.position.x
	_detail_panel.visible = true
	_refurbish_button.visible = false
	_refurbish_button.pressed.connect(_on_refurbish_pressed)
	_open_pack_button.visible = false
	_open_pack_button.pressed.connect(_on_open_pack_pressed)
	_show_detail_placeholder()
	_close_button.pressed.connect(close)
	EventBus.interactable_interacted.connect(
		_on_interactable_interacted
	)
	EventBus.interactable_right_clicked.connect(
		_on_interactable_right_clicked
	)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.inventory_changed.connect(_on_inventory_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _placement_mode:
				_exit_placement_mode()
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
		if _placement_mode:
			_exit_placement_mode()
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
	_source_location = source
	_is_open = true
	_selected_item = null
	_show_detail_placeholder()
	_refresh_grid()
	_update_capacity_label()
	_anim_tween = PanelAnimator.slide_open(
		_panel, _rest_x, true
	)
	EventBus.panel_opened.emit(PANEL_NAME)


func close(immediate: bool = false) -> void:
	if not _is_open:
		return
	PanelAnimator.kill_tween(_anim_tween)
	if _placement_mode:
		_exit_placement_mode()
	_is_open = false
	_selected_item = null
	if immediate:
		_panel.visible = false
		_panel.position.x = _rest_x
	else:
		_anim_tween = PanelAnimator.slide_close(
			_panel, _rest_x, true
		)
	EventBus.item_tooltip_hidden.emit()
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func _toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _refresh_grid() -> void:
	_clear_grid()
	if not inventory_system:
		return
	var items: Array[ItemInstance] = (
		inventory_system.get_items_at_location(_source_location)
	)
	var has_items: bool = items.size() > 0
	_empty_label.visible = not has_items
	_scroll.visible = has_items
	for item: ItemInstance in items:
		_create_item_cell(item)


func _clear_grid() -> void:
	_cell_map.clear()
	for child: Node in _grid.get_children():
		child.queue_free()


func _create_item_cell(item: ItemInstance) -> void:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(170, 60)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var rarity_rect := ColorRect.new()
	rarity_rect.custom_minimum_size = Vector2(6, 0)
	rarity_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rarity_key: String = ""
	if item.definition:
		rarity_key = item.definition.rarity
	rarity_rect.color = UIThemeConstants.get_rarity_color(rarity_key)
	hbox.add_child(rarity_rect)

	var label := Label.new()
	var condition_text: String = item.condition.capitalize()
	if _is_unrentable_item(item):
		condition_text += " - Unrentable"
	var shape: String = UIThemeConstants.get_rarity_shape(rarity_key)
	label.text = "%s %s\n[%s]" % [
		shape,
		_truncate_name(item.definition.name, 16),
		condition_text,
	]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)

	cell.add_child(hbox)

	var btn := Button.new()
	btn.flat = true
	btn.anchors_preset = Control.PRESET_FULL_RECT
	btn.pressed.connect(_on_item_clicked.bind(item, cell))
	btn.mouse_entered.connect(
		_on_cell_mouse_entered.bind(item)
	)
	btn.mouse_exited.connect(_on_cell_mouse_exited)
	cell.add_child(btn)

	_grid.add_child(cell)
	_cell_map[cell] = item


func _truncate_name(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max_len - 1) + "..."


func _on_item_clicked(
	item: ItemInstance, cell: PanelContainer
) -> void:
	_selected_item = item
	_highlight_selected_cell(cell)
	_show_item_detail(item)
	_enter_placement_mode()


func _highlight_selected_cell(
	active_cell: PanelContainer
) -> void:
	for child: Node in _grid.get_children():
		if child is PanelContainer:
			(child as PanelContainer).modulate = Color.WHITE
	active_cell.modulate = Color(0.7, 1.0, 0.7)


func _show_item_detail(item: ItemInstance) -> void:
	_detail_placeholder.visible = false
	_detail_name.visible = true
	_detail_condition.visible = true
	_detail_rarity.visible = true
	_detail_base_price.visible = true
	_detail_value.visible = true
	_detail_description.visible = true

	_detail_name.text = item.definition.name
	var detail_cond_text: String = item.condition.capitalize()
	if _is_unrentable_item(item):
		detail_cond_text += "  [Unrentable]"
		_detail_condition.add_theme_color_override(
			"font_color", UIThemeConstants.get_negative_color()
		)
	else:
		_detail_condition.remove_theme_color_override("font_color")
	_detail_condition.text = "Condition: %s" % detail_cond_text
	var rarity_display: String = UIThemeConstants.get_rarity_display(
		item.definition.rarity
	)
	_detail_rarity.text = "Rarity: %s" % rarity_display
	var rarity_color: Color = UIThemeConstants.get_rarity_color(
		item.definition.rarity
	)
	_detail_rarity.add_theme_color_override(
		"font_color", rarity_color
	)
	_detail_base_price.text = (
		"Base Price: $%.2f" % item.definition.base_price
	)
	_detail_value.text = (
		"Est. Value: $%.2f" % item.get_current_value()
	)
	var desc: String = item.definition.description
	if desc.is_empty():
		desc = "No description available."
	_detail_description.text = desc
	_update_refurbish_button(item)
	_update_open_pack_button(item)


func _show_detail_placeholder() -> void:
	_detail_placeholder.visible = true
	_detail_name.visible = false
	_detail_condition.visible = false
	_detail_rarity.visible = false
	_detail_base_price.visible = false
	_detail_value.visible = false
	_detail_description.visible = false
	_refurbish_button.visible = false
	_open_pack_button.visible = false


func _update_capacity_label() -> void:
	if not inventory_system:
		_capacity_label.text = ""
		return
	var items: Array[ItemInstance] = (
		inventory_system.get_items_at_location(_source_location)
	)
	var count: int = items.size()
	if _source_location == SOURCE_RETURNS_BIN:
		_capacity_label.text = "Returns Bin: %d items" % count
		return
	var capacity: int = _get_backroom_capacity()
	if capacity > 0:
		_capacity_label.text = "%d / %d items" % [count, capacity]
	else:
		_capacity_label.text = "%d items" % count


func _get_backroom_capacity() -> int:
	if not inventory_system or store_id.is_empty():
		return 0
	if not GameManager.data_loader:
		return 0
	var stores: Array[StoreDefinition] = (
		GameManager.data_loader.get_all_stores()
	)
	for store: StoreDefinition in stores:
		if store.store_type == store_id or store.id == store_id:
			return store.backroom_capacity
	return 0


func _on_interactable_interacted(
	target: Interactable, type: int
) -> void:
	if type == Interactable.InteractionType.BACKROOM:
		if not _is_open:
			open(SOURCE_BACKROOM)
		return

	if type == Interactable.InteractionType.RETURNS_BIN:
		if not _is_open:
			open(SOURCE_RETURNS_BIN)
		return

	if type == Interactable.InteractionType.SHELF_SLOT:
		if _placement_mode and _selected_item and target is ShelfSlot:
			_place_selected_item(target as ShelfSlot)
		elif not _is_open and target is ShelfSlot:
			var slot := target as ShelfSlot
			if not slot.is_occupied():
				open()


func _on_interactable_right_clicked(
	target: Interactable, type: int
) -> void:
	if type != Interactable.InteractionType.SHELF_SLOT:
		return
	if _placement_mode:
		_exit_placement_mode()
		return
	if not target is ShelfSlot:
		return
	var slot := target as ShelfSlot
	if slot.is_occupied():
		_remove_item_from_shelf(slot)


func _place_selected_item(slot: ShelfSlot) -> void:
	if not _selected_item or not inventory_system:
		return
	if slot.is_occupied():
		EventBus.notification_requested.emit("Slot occupied")
		return
	if _selected_item.current_location != _source_location:
		EventBus.notification_requested.emit(
			"Item is not in %s" % _source_location.replace("_", " ")
		)
		return
	inventory_system.move_item(
		_selected_item.instance_id,
		"shelf:%s" % slot.slot_id
	)
	var category: String = ""
	if _selected_item.definition:
		category = _selected_item.definition.category
	slot.place_item(_selected_item.instance_id, category)
	_exit_placement_mode()
	_selected_item = null
	_show_detail_placeholder()


func _remove_item_from_shelf(slot: ShelfSlot) -> void:
	if not inventory_system:
		return
	var item_id: String = slot.get_item_instance_id()
	if item_id.is_empty():
		return
	slot.remove_item()
	inventory_system.move_item(item_id, "backroom")
	EventBus.item_removed_from_shelf.emit(item_id, slot.slot_id)
	EventBus.notification_requested.emit("Item returned to backroom")


func _enter_placement_mode() -> void:
	if _placement_mode:
		return
	_placement_mode = true
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	EventBus.placement_mode_entered.emit()


func _exit_placement_mode() -> void:
	if not _placement_mode:
		return
	_placement_mode = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	EventBus.placement_mode_exited.emit()


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _on_inventory_changed() -> void:
	if not _is_open:
		return
	if _selected_item:
		var still_exists: bool = inventory_system.get_item(
			_selected_item.instance_id
		) != null
		var still_in_source: bool = still_exists and (
			_selected_item.current_location == _source_location
		)
		if not still_in_source:
			_selected_item = null
			_show_detail_placeholder()
	_refresh_grid()
	_update_capacity_label()


func _update_refurbish_button(item: ItemInstance) -> void:
	if not refurbishment_system:
		_refurbish_button.visible = false
		return
	var can_refurb: bool = refurbishment_system.can_refurbish(item)
	var is_for_parts: bool = (
		item.definition
		and item.definition.subcategory
		== RefurbishmentSystem.ELIGIBLE_SUBCATEGORY
	)
	_refurbish_button.visible = is_for_parts
	_refurbish_button.disabled = not can_refurb
	if is_for_parts and not can_refurb:
		var active: int = refurbishment_system.get_active_count()
		if active >= RefurbishmentSystem.MAX_CONCURRENT:
			_refurbish_button.text = "Refurbish (queue full)"
		else:
			_refurbish_button.text = "Refurbish"
	else:
		_refurbish_button.text = "Refurbish"


## Returns true if the item is a rental category at poor condition.
func _is_unrentable_item(item: ItemInstance) -> bool:
	if not rental_controller or not item.definition:
		return false
	if not rental_controller.is_rental_item(item.definition.category):
		return false
	return not rental_controller.is_rentable(item)


func _on_refurbish_pressed() -> void:
	if not _selected_item or not refurbishment_dialog:
		return
	refurbishment_dialog.open(_selected_item)


func _update_open_pack_button(item: ItemInstance) -> void:
	if not pack_controller:
		_open_pack_button.visible = false
		return
	var is_pack: bool = pack_controller.is_openable_pack(item)
	_open_pack_button.visible = is_pack
	_open_pack_button.text = "Open Pack"


func _on_open_pack_pressed() -> void:
	if not _selected_item or not pack_controller:
		return
	if not pack_controller.is_openable_pack(_selected_item):
		return
	var pack_name: String = _selected_item.definition.name
	var pack_id: String = _selected_item.instance_id
	var cards: Array[ItemInstance] = pack_controller.open_pack(
		pack_id
	)
	if cards.is_empty():
		EventBus.notification_requested.emit(
			"Failed to open pack"
		)
		return
	_selected_item = null
	_show_detail_placeholder()
	if pack_opening_panel:
		pack_opening_panel.open(cards, pack_name)


func _on_cell_mouse_entered(item: ItemInstance) -> void:
	EventBus.item_tooltip_requested.emit(item)


func _on_cell_mouse_exited() -> void:
	EventBus.item_tooltip_hidden.emit()
