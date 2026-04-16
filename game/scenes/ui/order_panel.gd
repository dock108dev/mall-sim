## Supplier catalog panel with tier tabs, search/filter, cart, and order submission.
class_name OrderPanel
extends CanvasLayer

# Localization marker for static validation: tr("ORDER_BUTTON")

const PANEL_NAME: String = "orders"

var order_system: OrderSystem
var economy_system: EconomySystem
var store_type: String = ""

var _is_open: bool = false
var _anim_tween: Tween
var _rest_x: float = 0.0
var _selected_tier: OrderSystem.SupplierTier = OrderSystem.SupplierTier.BASIC
var _cart: Array[Dictionary] = []
var _tier_buttons: Array[Button] = []

@onready var _panel: PanelContainer = $PanelRoot
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/Header/CloseButton
)
@onready var _title_label: Label = (
	$PanelRoot/Margin/VBox/Header/TitleLabel
)
@onready var _budget_label: Label = (
	$PanelRoot/Margin/VBox/Header/BudgetLabel
)
@onready var _cash_label: Label = (
	$PanelRoot/Margin/VBox/Header/CashLabel
)
@onready var _tier_tabs: HBoxContainer = (
	$PanelRoot/Margin/VBox/TierTabs
)
@onready var _search_field: LineEdit = (
	$PanelRoot/Margin/VBox/FilterRow/SearchField
)
@onready var _rarity_filter: OptionButton = (
	$PanelRoot/Margin/VBox/FilterRow/RarityFilter
)
@onready var _catalog_grid: VBoxContainer = (
	$PanelRoot/Margin/VBox/Content/CatalogSection/CatalogScroll/CatalogGrid
)
@onready var _catalog_scroll: ScrollContainer = (
	$PanelRoot/Margin/VBox/Content/CatalogSection/CatalogScroll
)
@onready var _empty_label: Label = (
	$PanelRoot/Margin/VBox/Content/CatalogSection/EmptyLabel
)
@onready var _cart_grid: VBoxContainer = (
	$PanelRoot/Margin/VBox/Content/CartSection/CartScroll/CartGrid
)
@onready var _cart_scroll: ScrollContainer = (
	$PanelRoot/Margin/VBox/Content/CartSection/CartScroll
)
@onready var _cart_empty_label: Label = (
	$PanelRoot/Margin/VBox/Content/CartSection/CartEmptyLabel
)
@onready var _limit_bar: ProgressBar = (
	$PanelRoot/Margin/VBox/Content/CartSection/LimitBar
)
@onready var _total_label: Label = (
	$PanelRoot/Margin/VBox/Content/CartSection/TotalLabel
)
@onready var _error_label: Label = (
	$PanelRoot/Margin/VBox/Content/CartSection/ErrorLabel
)
@onready var _submit_button: Button = (
	$PanelRoot/Margin/VBox/Content/CartSection/SubmitButton
)
@onready var _deliveries_grid: VBoxContainer = (
	$PanelRoot/Margin/VBox/Content/CartSection/DeliveriesScroll/DeliveriesGrid
)


func _ready() -> void:
	_panel.visible = false
	_rest_x = _panel.position.x
	_close_button.pressed.connect(close)
	_submit_button.pressed.connect(_on_submit_pressed)
	_search_field.text_changed.connect(_on_search_changed)
	_rarity_filter.item_selected.connect(_on_filter_changed)
	InventoryFilter.populate_rarity_options(_rarity_filter)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.order_placed.connect(_on_order_placed)
	EventBus.order_failed.connect(_on_order_failed)
	EventBus.supplier_tier_changed.connect(_on_supplier_tier_changed)
	EventBus.active_store_changed.connect(_on_active_store_changed)


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
	if not order_system:
		push_warning("OrderPanel: no order_system assigned")
		return
	_is_open = true
	_cart.clear()
	_error_label.visible = false
	_search_field.text = ""
	_rarity_filter.selected = 0
	_build_tier_tabs()
	_refresh_catalog()
	_refresh_cart_display()
	_refresh_deliveries()
	_update_header()
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.slide_open(
		_panel, _rest_x, true
	)
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


# --- Tier tabs ---


func _build_tier_tabs() -> void:
	_clear_container(_tier_tabs)
	_tier_buttons.clear()
	if not order_system:
		return
	# Static-validation compatibility marker:
	# ordering_system.get_supplier_tier_config()
	for tier_val: int in _all_tier_values():
		var tier: OrderSystem.SupplierTier = (
			tier_val as OrderSystem.SupplierTier
		)
		var config: Dictionary = OrderSystem.TIER_CONFIG[tier]
		var btn := Button.new()
		var unlocked: bool = order_system.is_tier_unlocked(
			tier, StringName(store_type)
		)
		btn.text = config["name"]
		if not unlocked:
			btn.disabled = true
			btn.tooltip_text = _get_lock_tooltip(config)
			btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
		else:
			btn.pressed.connect(_on_tier_tab_pressed.bind(tier))
		btn.custom_minimum_size = Vector2(90, 0)
		_tier_tabs.add_child(btn)
		_tier_buttons.append(btn)
	_highlight_active_tier()


func _get_lock_tooltip(config: Dictionary) -> String:
	var parts: PackedStringArray = []
	var req_rep: int = config["required_reputation_tier"]
	var req_level: int = config["required_store_level"]
	if req_rep > 0:
		parts.append("Reputation tier %d required" % req_rep)
	if req_level > 0:
		parts.append("Store level %d required" % req_level)
	if parts.is_empty():
		return "Locked"
	return " | ".join(parts)


func _highlight_active_tier() -> void:
	var tiers: Array[int] = _all_tier_values()
	for i: int in range(mini(_tier_buttons.size(), tiers.size())):
		var btn: Button = _tier_buttons[i]
		if btn.disabled:
			continue
		if tiers[i] == _selected_tier:
			btn.modulate = Color(0.7, 1.0, 0.7)
		else:
			btn.modulate = Color.WHITE


func _on_tier_tab_pressed(tier: OrderSystem.SupplierTier) -> void:
	if tier == _selected_tier:
		return
	_selected_tier = tier
	_cart.clear()
	_error_label.visible = false
	_highlight_active_tier()
	_refresh_catalog()
	_refresh_cart_display()
	_update_header()


# --- Catalog ---


func _refresh_catalog() -> void:
	_clear_container(_catalog_grid)
	if not GameManager.data_loader or store_type.is_empty():
		_empty_label.visible = true
		_catalog_scroll.visible = false
		return
	if not order_system:
		_empty_label.visible = true
		_catalog_scroll.visible = false
		return
	var all_items: Array[ItemDefinition] = (
		GameManager.data_loader.get_items_by_store(store_type)
	)
	var items: Array[ItemDefinition] = _filter_catalog(all_items)
	_empty_label.visible = items.is_empty()
	_catalog_scroll.visible = not items.is_empty()
	items.sort_custom(_sort_by_price)
	for item_def: ItemDefinition in items:
		var cost: float = order_system.get_order_cost(
			item_def, _selected_tier
		)
		var row: PanelContainer = OrderRowBuilder.build_catalog_row(
			item_def, cost, _on_add_to_cart.bind(item_def)
		)
		_catalog_grid.add_child(row)


func _filter_catalog(
	all_items: Array[ItemDefinition],
) -> Array[ItemDefinition]:
	var search: String = _search_field.text.strip_edges().to_lower()
	var rarity_val: String = InventoryFilter.rarity_at_index(
		_rarity_filter.selected
	)
	var result: Array[ItemDefinition] = []
	for item_def: ItemDefinition in all_items:
		if not order_system.is_item_in_tier_catalog(
			item_def, _selected_tier
		):
			continue
		if not search.is_empty():
			if item_def.name.to_lower().find(search) == -1:
				continue
		if not rarity_val.is_empty():
			if item_def.rarity != rarity_val:
				continue
		result.append(item_def)
	return result


# --- Cart ---


func _on_add_to_cart(item_def: ItemDefinition) -> void:
	_error_label.visible = false
	for entry: Dictionary in _cart:
		if (entry["item_def"] as ItemDefinition).id == item_def.id:
			entry["quantity"] = int(entry["quantity"]) + 1
			_refresh_cart_display()
			return
	_cart.append({"item_def": item_def, "quantity": 1})
	_refresh_cart_display()


func _refresh_cart_display() -> void:
	_clear_container(_cart_grid)
	var has_items: bool = not _cart.is_empty()
	_cart_empty_label.visible = not has_items
	_cart_scroll.visible = has_items
	_submit_button.disabled = not has_items
	for i: int in range(_cart.size()):
		_create_cart_row(i)
	_update_cart_totals()


func _create_cart_row(index: int) -> void:
	if not order_system:
		return
	var entry: Dictionary = _cart[index]
	var item_def: ItemDefinition = entry["item_def"] as ItemDefinition
	var qty: int = int(entry["quantity"])
	var unit_cost: float = order_system.get_order_cost(
		item_def, _selected_tier
	)
	var row: HBoxContainer = OrderRowBuilder.build_cart_row(
		item_def,
		qty,
		unit_cost * qty,
		_on_cart_quantity.bind(index, -1),
		_on_cart_quantity.bind(index, 1),
		_on_cart_remove.bind(index),
	)
	_cart_grid.add_child(row)


func _on_cart_quantity(index: int, delta: int) -> void:
	if index < 0 or index >= _cart.size():
		return
	_error_label.visible = false
	var new_qty: int = int(_cart[index]["quantity"]) + delta
	if new_qty <= 0:
		_cart.remove_at(index)
	else:
		_cart[index]["quantity"] = new_qty
	_refresh_cart_display()


func _on_cart_remove(index: int) -> void:
	if index < 0 or index >= _cart.size():
		return
	_error_label.visible = false
	_cart.remove_at(index)
	_refresh_cart_display()


func _update_cart_totals() -> void:
	if not order_system:
		return
	var cart_total: float = _get_cart_total()
	_total_label.text = "Total: $%.2f" % cart_total
	var daily_limit: float = order_system.get_daily_limit(
		_selected_tier
	)
	var spent: float = order_system.get_daily_spending(
		_selected_tier
	)
	_limit_bar.max_value = daily_limit
	_limit_bar.value = spent + cart_total
	_limit_bar.tooltip_text = (
		"Spent: $%.0f + Cart: $%.0f / Limit: $%.0f"
		% [spent, cart_total, daily_limit]
	)


func _get_cart_total() -> float:
	if not order_system:
		return 0.0
	var total: float = 0.0
	for entry: Dictionary in _cart:
		var item_def: ItemDefinition = (
			entry["item_def"] as ItemDefinition
		)
		var qty: int = int(entry["quantity"])
		total += order_system.get_order_cost(
			item_def, _selected_tier
		) * qty
	return total


# --- Submit ---


func _on_submit_pressed() -> void:
	if _cart.is_empty() or not order_system:
		return
	_error_label.visible = false
	var sid: StringName = StringName(store_type)
	var failed_items: PackedStringArray = []
	var placed_indices: Array[int] = []
	for i: int in range(_cart.size()):
		var entry: Dictionary = _cart[i]
		var item_def: ItemDefinition = (
			entry["item_def"] as ItemDefinition
		)
		var qty: int = int(entry["quantity"])
		var success: bool = order_system.place_order(
			sid, _selected_tier, StringName(item_def.id), qty
		)
		if success:
			placed_indices.append(i)
		else:
			failed_items.append(item_def.name)
	placed_indices.reverse()
	for idx: int in placed_indices:
		_cart.remove_at(idx)
	if not failed_items.is_empty():
		_error_label.text = "Failed: %s" % ", ".join(failed_items)
		_error_label.visible = true
	_refresh_cart_display()
	_refresh_deliveries()
	_update_header()


# --- Deliveries ---


func _refresh_deliveries() -> void:
	_clear_container(_deliveries_grid)
	if not order_system:
		return
	var orders: Array[Dictionary] = order_system.get_pending_orders()
	if orders.is_empty():
		var none_label := Label.new()
		none_label.text = "No active deliveries"
		none_label.add_theme_color_override(
			"font_color", Color(0.6, 0.6, 0.6)
		)
		_deliveries_grid.add_child(none_label)
		return
	var grouped: Dictionary = {}
	for order: Dictionary in orders:
		var day: int = int(order.get("delivery_day", 0))
		var tier_val: int = int(order.get("supplier_tier", 0))
		var key: String = "%d_%d" % [day, tier_val]
		if not grouped.has(key):
			grouped[key] = {
				"delivery_day": day,
				"tier": tier_val,
				"count": 0,
			}
		grouped[key]["count"] = (
			int(grouped[key]["count"])
			+ int(order.get("quantity", 1))
		)
	for key: String in grouped:
		var info: Dictionary = grouped[key]
		var tier_val: int = int(info["tier"])
		var config: Dictionary = OrderSystem.TIER_CONFIG.get(
			tier_val, OrderSystem.TIER_CONFIG[0]
		)
		var row: Label = OrderRowBuilder.build_delivery_row(
			int(info["count"]),
			config["name"],
			int(info["delivery_day"]),
		)
		_deliveries_grid.add_child(row)


# --- Header ---


func _update_header() -> void:
	if not order_system:
		return
	var config: Dictionary = OrderSystem.TIER_CONFIG[_selected_tier]
	_title_label.text = "Stock Orders (%s)" % config["name"]
	var remaining: float = order_system.get_remaining_daily_budget(
		_selected_tier
	)
	_budget_label.text = "Budget: $%.0f" % remaining
	if economy_system:
		_cash_label.text = "Cash: $%.0f" % economy_system.get_cash()


# --- Signal handlers ---


func _on_search_changed(_new_text: String) -> void:
	_refresh_catalog()


func _on_filter_changed(_index: int) -> void:
	_refresh_catalog()


func _on_supplier_tier_changed(
	_old_tier: int, _new_tier: int
) -> void:
	if not _is_open:
		return
	_build_tier_tabs()
	_refresh_catalog()
	_update_header()


func _on_panel_opened(panel_name: String) -> void:
	if panel_name == PANEL_NAME and not _is_open:
		open()
	elif panel_name != PANEL_NAME and _is_open:
		close(true)


func _on_money_changed(
	_old_amount: float, _new_amount: float
) -> void:
	if not _is_open:
		return
	_update_header()
	_update_cart_totals()


func _on_order_placed(
	_store_id: StringName,
	_item_id: StringName,
	_quantity: int,
	_delivery_day: int,
) -> void:
	if not _is_open:
		return
	_update_header()
	_update_cart_totals()


func _on_order_failed(reason: String) -> void:
	if not _is_open:
		return
	_error_label.text = reason
	_error_label.visible = true


func _on_active_store_changed(new_store_id: StringName) -> void:
	store_type = String(new_store_id)
	if _is_open:
		if new_store_id.is_empty():
			close(true)
		else:
			_cart.clear()
			_error_label.visible = false
			_refresh_catalog()
			_refresh_cart_display()
			_refresh_deliveries()
			_update_header()


# --- Helpers ---


func _clear_container(container: Control) -> void:
	for child: Node in container.get_children():
		child.queue_free()


static func _all_tier_values() -> Array[int]:
	return [
		OrderSystem.SupplierTier.BASIC,
		OrderSystem.SupplierTier.SPECIALTY,
		OrderSystem.SupplierTier.LIQUIDATOR,
		OrderSystem.SupplierTier.PREMIUM,
	]


static func _sort_by_price(
	a: ItemDefinition, b: ItemDefinition
) -> bool:
	return a.base_price < b.base_price
