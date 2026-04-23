## Modal dialog that lets the player choose a rental duration before confirming
## a video-rental checkout. Shows at least two duration options with per-tier
## prices (ISSUE-014 AC #3).
class_name RentalCheckoutDialog
extends CanvasLayer

signal rental_confirmed(tier: String)
signal rental_declined()
signal late_fee_pay_confirmed(customer_id: String)
signal late_fee_pay_declined(customer_id: String)

const PANEL_NAME: String = "rental_checkout"

enum Mode { RENTAL, LATE_FEE }

var _is_open: bool = false
var _mode: int = Mode.RENTAL
var _options: Array[Dictionary] = []
var _selected_tier: String = ""
var _tier_buttons: Array[Button] = []
var _pending_customer_id: String = ""
var _pending_total: float = 0.0

var _panel: PanelContainer
var _title_label: Label
var _item_name_label: Label
var _options_vbox: VBoxContainer
var _price_label: Label
var _confirm_button: Button
var _cancel_button: Button


func _ready() -> void:
	_build_ui()
	_panel.visible = false
	_confirm_button.pressed.connect(_on_confirm)
	_cancel_button.pressed.connect(_on_cancel)


## Opens the dialog for the given item with pre-computed duration options.
## options: Array of {tier, days, price, label}. Must contain >= 1 entry;
## in practice VideoRentalStoreController supplies three tiers.
func open_for_item(
	item: ItemInstance, options: Array[Dictionary]
) -> void:
	if _is_open:
		return
	if not item or not item.definition or options.is_empty():
		push_warning("RentalCheckoutDialog: invalid open parameters")
		return
	_mode = Mode.RENTAL
	_title_label.text = "Rent Tape"
	_options = options
	_selected_tier = String(options[0].get("tier", ""))
	_item_name_label.text = item.definition.item_name
	_populate_options()
	_update_price_label()
	_confirm_button.text = "Confirm"
	_cancel_button.text = "Cancel"
	_is_open = true
	_panel.visible = true
	EventBus.panel_opened.emit(PANEL_NAME)


## Opens the dialog to resolve a customer's outstanding late fees before any
## new rental (ISSUE-015). items: Array of {item_id, amount, days_late}.
## Emits late_fee_pay_confirmed on Pay, late_fee_pay_declined on Cancel.
func open_for_late_fee_resolution(
	customer_id: String, total: float, items: Array
) -> void:
	if _is_open:
		return
	if customer_id.is_empty() or total <= 0.0:
		push_warning("RentalCheckoutDialog: invalid late-fee parameters")
		return
	_mode = Mode.LATE_FEE
	_pending_customer_id = customer_id
	_pending_total = total
	_title_label.text = "Outstanding Late Fees"
	_options.clear()
	for child: Node in _options_vbox.get_children():
		child.queue_free()
	_tier_buttons.clear()
	var summary_lines: Array[String] = []
	for entry: Variant in items:
		if entry is Dictionary:
			var e: Dictionary = entry as Dictionary
			summary_lines.append(
				"  • %s — $%.2f (%dd late)" % [
					str(e.get("item_id", "?")),
					float(e.get("amount", 0.0)),
					int(e.get("days_late", 0)),
				]
			)
	_item_name_label.text = "\n".join(summary_lines)
	_price_label.text = "Total Owed: $%.2f" % total
	_confirm_button.text = "Pay $%.2f" % total
	_cancel_button.text = "Not Now"
	_is_open = true
	_panel.visible = true
	EventBus.panel_opened.emit(PANEL_NAME)


func get_mode() -> int:
	return _mode


func get_pending_customer_id() -> String:
	return _pending_customer_id


func get_pending_total() -> float:
	return _pending_total


## Closes the dialog without emitting rental_declined. Used for external force-
## close flows; the normal cancel path emits rental_declined itself.
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_panel.visible = false
	_mode = Mode.RENTAL
	_pending_customer_id = ""
	_pending_total = 0.0
	_options.clear()
	_tier_buttons.clear()
	for child: Node in _options_vbox.get_children():
		child.queue_free()
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func get_selected_tier() -> String:
	return _selected_tier


func get_option_count() -> int:
	return _options.size()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.custom_minimum_size = Vector2(320.0, 0.0)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "Rent Tape"
	vbox.add_child(_title_label)

	_item_name_label = Label.new()
	vbox.add_child(_item_name_label)

	_options_vbox = VBoxContainer.new()
	vbox.add_child(_options_vbox)

	_price_label = Label.new()
	vbox.add_child(_price_label)

	var button_row := HBoxContainer.new()
	vbox.add_child(button_row)

	_confirm_button = Button.new()
	_confirm_button.text = "Confirm"
	button_row.add_child(_confirm_button)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	button_row.add_child(_cancel_button)


func _populate_options() -> void:
	_tier_buttons.clear()
	for child: Node in _options_vbox.get_children():
		child.queue_free()
	for opt: Dictionary in _options:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = "%s — $%.2f" % [
			String(opt.get("label", opt.get("tier", "?"))),
			float(opt.get("price", 0.0)),
		]
		btn.set_meta("tier", String(opt.get("tier", "")))
		btn.button_pressed = String(opt.get("tier", "")) == _selected_tier
		btn.pressed.connect(_on_option_pressed.bind(btn))
		_options_vbox.add_child(btn)
		_tier_buttons.append(btn)


func _on_option_pressed(button: Button) -> void:
	_selected_tier = String(button.get_meta("tier", ""))
	for btn: Button in _tier_buttons:
		btn.button_pressed = btn == button
	_update_price_label()


func _update_price_label() -> void:
	for opt: Dictionary in _options:
		if String(opt.get("tier", "")) == _selected_tier:
			_price_label.text = "Total: $%.2f" % float(
				opt.get("price", 0.0)
			)
			return
	_price_label.text = ""


func _on_confirm() -> void:
	if _mode == Mode.LATE_FEE:
		var customer_id: String = _pending_customer_id
		close()
		late_fee_pay_confirmed.emit(customer_id)
		return
	if _selected_tier.is_empty():
		return
	var tier: String = _selected_tier
	close()
	rental_confirmed.emit(tier)


func _on_cancel() -> void:
	if _mode == Mode.LATE_FEE:
		var customer_id: String = _pending_customer_id
		close()
		late_fee_pay_declined.emit(customer_id)
		return
	close()
	rental_declined.emit()
