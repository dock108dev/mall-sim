## Right-dock slide-in panel for completing sales with item list and receipt.
class_name CheckoutPanel
extends CanvasLayer

# Localization marker for static validation: tr("CHECKOUT_CONDITION")

signal sale_accepted
signal sale_declined

const PANEL_NAME: String = "checkout"
const RECEIPT_DISPLAY_DURATION: float = 2.0

var _is_open: bool = false
var _is_pending: bool = false
var _showing_receipt: bool = false
var _items: Array[Dictionary] = []
var _haggle_discount: float = 0.0
var _subtotal: float = 0.0
var _total: float = 0.0
var _anim_tween: Tween
var _rest_x: float = 0.0
var _receipt_timer: Timer

@onready var _panel: PanelContainer = $PanelRoot
@onready var _item_list: VBoxContainer = (
	$PanelRoot/Margin/VBox/ItemScroll/ItemList
)
@onready var _subtotal_value: Label = (
	$PanelRoot/Margin/VBox/TotalsSection/SubtotalRow/SubtotalValue
)
@onready var _discount_row: HBoxContainer = (
	$PanelRoot/Margin/VBox/TotalsSection/DiscountRow
)
@onready var _discount_value: Label = (
	$PanelRoot/Margin/VBox/TotalsSection/DiscountRow/DiscountValue
)
@onready var _total_value: Label = (
	$PanelRoot/Margin/VBox/TotalsSection/TotalRow/TotalValue
)
@onready var _error_label: Label = (
	$PanelRoot/Margin/VBox/ErrorLabel
)
@onready var _confirm_button: Button = (
	$PanelRoot/Margin/VBox/ButtonRow/ConfirmButton
)
@onready var _cancel_button: Button = (
	$PanelRoot/Margin/VBox/ButtonRow/CancelButton
)
@onready var _receipt_section: VBoxContainer = (
	$PanelRoot/Margin/VBox/ReceiptSection
)
@onready var _receipt_item_list: VBoxContainer = (
	$PanelRoot/Margin/VBox/ReceiptSection/ReceiptItemList
)
@onready var _receipt_total_label: Label = (
	$PanelRoot/Margin/VBox/ReceiptSection/ReceiptTotalLabel
)
@onready var _receipt_timestamp_label: Label = (
	$PanelRoot/Margin/VBox/ReceiptSection/ReceiptTimestampLabel
)


func _ready() -> void:
	_panel.visible = false
	_rest_x = _panel.position.x
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_receipt_timer = Timer.new()
	_receipt_timer.one_shot = true
	_receipt_timer.wait_time = RECEIPT_DISPLAY_DURATION
	_receipt_timer.timeout.connect(_on_receipt_timer_timeout)
	add_child(_receipt_timer)
	EventBus.checkout_started.connect(_on_checkout_started)
	EventBus.transaction_completed.connect(
		_on_transaction_completed
	)
	EventBus.panel_opened.connect(_on_panel_opened)


## Opens the panel with a list of items for sale.
func show_checkout(
	items: Array[Dictionary],
	haggle_discount: float = 0.0,
) -> void:
	_items = items
	_haggle_discount = haggle_discount
	_is_pending = false
	_showing_receipt = false
	_error_label.visible = false
	_receipt_section.visible = false
	_confirm_button.visible = true
	_cancel_button.visible = true
	_confirm_button.disabled = false
	_cancel_button.disabled = false
	_populate_item_list()
	_update_totals()
	PanelAnimator.kill_tween(_anim_tween)
	_is_open = true
	_anim_tween = PanelAnimator.slide_open(
		_panel, _rest_x, false
	)
	EventBus.panel_opened.emit(PANEL_NAME)


## Closes the checkout panel with optional immediate hide.
func hide_checkout(immediate: bool = false) -> void:
	if not _is_open:
		return
	_is_open = false
	_is_pending = false
	_showing_receipt = false
	_receipt_timer.stop()
	PanelAnimator.kill_tween(_anim_tween)
	if immediate:
		_panel.visible = false
		_panel.position.x = _rest_x
	else:
		_anim_tween = PanelAnimator.slide_close(
			_panel, _rest_x, false
		)
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func is_showing_receipt() -> bool:
	return _showing_receipt


## Returns false — warranty is handled by WarrantyDialog.
func is_warranty_offered() -> bool:
	return false


## Returns 0 — warranty is handled by WarrantyDialog.
func get_warranty_fee() -> float:
	return 0.0


func _on_checkout_started(
	items: Array, customer_node: Node
) -> void:
	if items.is_empty():
		push_error(
			"CheckoutPanel: checkout_started with empty items"
		)
		return
	if not customer_node:
		push_error(
			"CheckoutPanel: checkout_started with null customer"
		)
		return
	var item_dicts: Array[Dictionary] = []
	for item: Variant in items:
		if item is Dictionary:
			item_dicts.append(item as Dictionary)
	show_checkout(item_dicts)


func _on_confirm_pressed() -> void:
	if _is_pending:
		return
	_set_pending(true)
	sale_accepted.emit()


func _on_cancel_pressed() -> void:
	if _is_pending:
		return
	sale_declined.emit()


func _on_transaction_completed(
	amount: float, success: bool, message: String
) -> void:
	if not _is_open or not _is_pending:
		return
	_set_pending(false)
	if success:
		_show_receipt(amount)
	else:
		_show_error(message)


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		hide_checkout(true)
		if _is_pending:
			sale_declined.emit()


func _on_receipt_timer_timeout() -> void:
	hide_checkout()


func _set_pending(pending: bool) -> void:
	_is_pending = pending
	_confirm_button.disabled = pending
	_cancel_button.disabled = pending


func _populate_item_list() -> void:
	_clear_container(_item_list)
	for item: Dictionary in _items:
		var row: HBoxContainer = _create_item_row(item)
		_item_list.add_child(row)


func _create_item_row(item: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = item.get("item_name", "Unknown")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)

	var condition_label := Label.new()
	condition_label.text = str(item.get("condition", ""))
	condition_label.custom_minimum_size = Vector2(80, 0)
	condition_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	row.add_child(condition_label)

	var price_label := Label.new()
	var price: float = item.get("price", 0.0)
	price_label.text = _format_price(price)
	price_label.custom_minimum_size = Vector2(70, 0)
	price_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	row.add_child(price_label)
	return row


func _update_totals() -> void:
	_subtotal = 0.0
	for item: Dictionary in _items:
		_subtotal += item.get("price", 0.0)

	_total = _subtotal - _haggle_discount
	if _total < 0.0:
		_total = 0.0

	_subtotal_value.text = _format_price(_subtotal)

	if _haggle_discount > 0.0:
		_discount_row.visible = true
		_discount_value.text = (
			"-%s" % _format_price(_haggle_discount)
		)
		_discount_value.add_theme_color_override(
			"font_color",
			UIThemeConstants.get_positive_color(),
		)
	else:
		_discount_row.visible = false

	_total_value.text = _format_price(_total)


func _show_receipt(amount: float) -> void:
	_showing_receipt = true
	_confirm_button.visible = false
	_cancel_button.visible = false
	_receipt_section.visible = true
	_clear_container(_receipt_item_list)
	for item: Dictionary in _items:
		var lbl := Label.new()
		lbl.text = "%s — %s" % [
			item.get("item_name", "Unknown"),
			_format_price(item.get("price", 0.0)),
		]
		_receipt_item_list.add_child(lbl)
	_receipt_total_label.text = "Total: %s" % _format_price(
		amount
	)
	var time_dict: Dictionary = (
		Time.get_datetime_dict_from_system()
	)
	_receipt_timestamp_label.text = "%04d-%02d-%02d %02d:%02d" % [
		time_dict.get("year", 0),
		time_dict.get("month", 0),
		time_dict.get("day", 0),
		time_dict.get("hour", 0),
		time_dict.get("minute", 0),
	]
	_receipt_timer.start()


func _show_error(message: String) -> void:
	_error_label.text = (
		message if not message.is_empty() else "Sale failed"
	)
	_error_label.visible = true
	_error_label.add_theme_color_override(
		"font_color", UIThemeConstants.get_negative_color()
	)
	_cancel_button.disabled = false


func _clear_container(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		child.queue_free()


static func _format_price(amount: float) -> String:
	return "%s%.2f" % [
		UIThemeConstants.CURRENCY_SYMBOL, amount,
	]
