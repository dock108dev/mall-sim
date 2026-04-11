## Stock ordering panel for browsing and purchasing wholesale items.
class_name OrderPanel
extends CanvasLayer

const PANEL_NAME: String = "orders"

var ordering_system: OrderingSystem
var economy_system: EconomySystem
var store_type: String = ""

var _is_open: bool = false
var _anim_tween: Tween
var _rest_x: float = 0.0

@onready var _panel: PanelContainer = $PanelRoot
@onready var _grid: GridContainer = (
	$PanelRoot/Margin/VBox/Content/Scroll/Grid
)
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/Header/CloseButton
)
@onready var _budget_label: Label = (
	$PanelRoot/Margin/VBox/Header/BudgetLabel
)
@onready var _cash_label: Label = (
	$PanelRoot/Margin/VBox/Header/CashLabel
)
@onready var _tier_label: Label = (
	$PanelRoot/Margin/VBox/TierInfo/TierLabel
)
@onready var _next_tier_label: Label = (
	$PanelRoot/Margin/VBox/TierInfo/NextTierLabel
)
@onready var _pending_label: Label = (
	$PanelRoot/Margin/VBox/Footer/PendingLabel
)
@onready var _empty_label: Label = (
	$PanelRoot/Margin/VBox/Content/EmptyLabel
)
@onready var _scroll: ScrollContainer = (
	$PanelRoot/Margin/VBox/Content/Scroll
)


func _ready() -> void:
	_panel.visible = false
	_rest_x = _panel.position.x
	_close_button.pressed.connect(close)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.order_placed.connect(_on_order_placed)
	EventBus.supplier_tier_changed.connect(_on_supplier_tier_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.is_action_pressed("toggle_orders"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif key_event.is_action_pressed("ui_cancel") and _is_open:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if _is_open:
		return
	if not ordering_system:
		push_warning("OrderPanel: no ordering_system assigned")
		return
	_is_open = true
	_refresh_grid()
	_update_header_labels()
	_update_tier_labels()
	_update_pending_label()
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.slide_open(_panel, _rest_x, true)
	EventBus.panel_opened.emit(PANEL_NAME)


func close(immediate: bool = false) -> void:
	if not _is_open:
		return
	_is_open = false
	PanelAnimator.kill_tween(_anim_tween)
	if immediate:
		_panel.visible = false
		_panel.position.x = _rest_x
	else:
		_anim_tween = PanelAnimator.slide_close(
			_panel, _rest_x, true
		)
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
	if not GameManager.data_loader or store_type.is_empty():
		_empty_label.visible = true
		_scroll.visible = false
		return
	if not ordering_system:
		_empty_label.visible = true
		_scroll.visible = false
		return
	var all_items: Array[ItemDefinition] = (
		GameManager.data_loader.get_items_by_store(store_type)
	)
	var items: Array[ItemDefinition] = []
	for item_def: ItemDefinition in all_items:
		if ordering_system.is_item_available_at_tier(item_def):
			items.append(item_def)
	var has_items: bool = items.size() > 0
	_empty_label.visible = not has_items
	_scroll.visible = has_items
	items.sort_custom(_sort_by_price)
	for item_def: ItemDefinition in items:
		_create_item_row(item_def)


func _clear_grid() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()


func _create_item_row(item_def: ItemDefinition) -> void:
	if not ordering_system:
		return
	var wholesale: float = ordering_system.get_wholesale_price(
		item_def
	)

	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(0, 50)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var rarity_rect := ColorRect.new()
	rarity_rect.custom_minimum_size = Vector2(6, 0)
	rarity_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rarity_rect.color = UIThemeConstants.get_rarity_color(
		item_def.rarity
	)
	hbox.add_child(rarity_rect)

	var name_label := Label.new()
	name_label.text = item_def.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	hbox.add_child(name_label)

	var rarity_label := Label.new()
	var rarity_display: String = UIThemeConstants.get_rarity_display(
		item_def.rarity
	)
	rarity_label.text = rarity_display
	rarity_label.custom_minimum_size = Vector2(100, 0)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_color_override(
		"font_color",
		UIThemeConstants.get_rarity_color(item_def.rarity),
	)
	hbox.add_child(rarity_label)

	var price_label := Label.new()
	price_label.text = "$%.2f" % wholesale
	price_label.custom_minimum_size = Vector2(70, 0)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(price_label)

	var order_btn := Button.new()
	order_btn.text = tr("ORDER_BUTTON")
	order_btn.custom_minimum_size = Vector2(70, 0)
	order_btn.pressed.connect(_on_order_pressed.bind(item_def))
	hbox.add_child(order_btn)

	cell.add_child(hbox)
	_grid.add_child(cell)


func _on_order_pressed(item_def: ItemDefinition) -> void:
	if not ordering_system:
		return
	ordering_system.place_order(item_def)


func _update_header_labels() -> void:
	if not ordering_system:
		return
	var budget: float = ordering_system.get_remaining_order_budget()
	_budget_label.text = tr("ORDER_BUDGET") % budget
	if economy_system:
		_cash_label.text = tr("ORDER_CASH") % economy_system.get_cash()


func _update_pending_label() -> void:
	if not ordering_system:
		return
	var count: int = ordering_system.get_pending_order_count()
	if count <= 0:
		_pending_label.text = tr("ORDER_NO_PENDING")
		return
	var config: Dictionary = ordering_system.get_supplier_tier_config()
	var days: int = config["delivery_days"]
	var day_text: String = tr("ORDER_TOMORROW")
	if days > 1:
		day_text = tr("ORDER_IN_DAYS") % days
	_pending_label.text = (
		tr("ORDER_PENDING") % [count, day_text]
	)


func _update_tier_labels() -> void:
	if not ordering_system:
		return
	var config: Dictionary = ordering_system.get_supplier_tier_config()
	_tier_label.text = tr("ORDER_SUPPLIER") % config["name"]
	var next_info: Dictionary = ordering_system.get_next_tier_info()
	if next_info.is_empty():
		_next_tier_label.text = tr("ORDER_MAX_TIER")
	else:
		_next_tier_label.text = (
			tr("ORDER_NEXT_TIER")
			% [next_info["name"], next_info["rep_required"]]
		)


func _on_supplier_tier_changed(
	_old_tier: int, _new_tier: int
) -> void:
	if not _is_open:
		return
	_refresh_grid()
	_update_header_labels()
	_update_tier_labels()


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _on_money_changed(
	_old_amount: float, _new_amount: float
) -> void:
	if not _is_open:
		return
	_update_header_labels()


func _on_order_placed(_order_data: Dictionary) -> void:
	if not _is_open:
		return
	_update_header_labels()
	_update_pending_label()


static func _sort_by_price(
	a: ItemDefinition, b: ItemDefinition
) -> bool:
	return a.base_price < b.base_price
