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
## Tracks whether this panel pushed CTX_MODAL on InputFocus so the cursor is
## released for FP play; mirrors InventoryPanel's contract so the StorePlayerBody
## context_changed listener flips MOUSE_MODE_CAPTURED → MOUSE_MODE_VISIBLE while
## a sale is being rung up. Push/pop must stay balanced.
var _focus_pushed: bool = false

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
	SceneRouter.scene_ready.connect(_on_scene_ready)


## §F-82 — Defensive cleanup so a modal removed mid-display (scene swap, run
## reset, panel queue_free) does not strand a CTX_MODAL frame on InputFocus.
## `_pop_modal_focus` itself escalates with `push_error` if the topmost frame
## is not CTX_MODAL (§F-74 contract), so a corrupted stack is still surfaced
## loudly — the silent skip here is only the well-behaved no-op path.
func _exit_tree() -> void:
	if _focus_pushed:
		_pop_modal_focus()


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
	# Emit FIRST so any sibling panels' mutual-exclusion handlers run their
	# hide and pop their own frames, THEN claim modal focus on top of whatever
	# world context was current. Mirrors InventoryPanel.open().
	EventBus.panel_opened.emit(PANEL_NAME)
	_push_modal_focus()


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
	# Pop FIRST while CTX_MODAL is still on top, THEN broadcast close. Mirrors
	# InventoryPanel.close().
	_pop_modal_focus()
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
	# §F-66 — `checkout_started` is emitted by `CheckoutSystem._show_checkout_panel`
	# with `Array[Dictionary]` cast to `Array` for the variadic signal; any
	# non-Dictionary entry reaching this loop is a caller bug that would
	# silently drop items from the player's checkout (data integrity:
	# missing line-item revenue). `push_warning` surfaces the offending type
	# while keeping the well-formed remainder of the cart intact so the sale
	# isn't blocked outright.
	var item_dicts: Array[Dictionary] = []
	for item: Variant in items:
		if item is Dictionary:
			item_dicts.append(item as Dictionary)
		else:
			push_warning(
				"CheckoutPanel: dropping non-Dictionary item in checkout_started — got %s"
				% type_string(typeof(item))
			)
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
	# the pop so we don't corrupt someone else's frame.
	if InputFocus.current() != InputFocus.CTX_MODAL:
		push_error(
			(
				"CheckoutPanel.hide_checkout: expected CTX_MODAL on top, "
				+ "got %s — leaving stack untouched to avoid corrupting "
				+ "sibling frame"
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
	if _is_open:
		hide_checkout(true)
		return
	if _focus_pushed:
		_pop_modal_focus()


## Test seam — clears _focus_pushed without calling pop_context. Pair with
## InputFocus._reset_for_tests() so test harnesses that wipe the focus stack
## don't leave the panel believing it still owns a frame.
func _reset_for_tests() -> void:
	_focus_pushed = false
