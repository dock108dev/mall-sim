## Modal dialog offering extended warranty add-on after a qualifying electronics sale.
## When warranty_tiers are provided, shows a button per tier plus a "None" option.
## Without tiers, falls back to the single Add/Decline layout.
class_name WarrantyDialog
extends CanvasLayer

const PANEL_NAME: String = "warranty"
const DEFAULT_WARRANTY_PERCENT: float = 0.20

signal warranty_accepted(item_id: String, warranty_fee: float)
signal warranty_declined

var _is_open: bool = false
var _item_id: String = ""
var _sale_price: float = 0.0
var _warranty_fee: float = 0.0
var _wholesale_cost: float = 0.0
var _selected_tier_id: String = ""
var _tier_buttons: Array[Button] = []
var _anim_tween: Tween

@onready var _panel: PanelContainer = $PanelRoot
@onready var _title_label: Label = (
	$PanelRoot/Margin/VBox/TitleLabel
)
@onready var _item_name_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/ItemNameLabel
)
@onready var _sale_price_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/SalePriceLabel
)
@onready var _warranty_cost_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/WarrantyCostLabel
)
@onready var _duration_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/DurationLabel
)
@onready var _add_button: Button = (
	$PanelRoot/Margin/VBox/ButtonHBox/AddButton
)
@onready var _decline_button: Button = (
	$PanelRoot/Margin/VBox/ButtonHBox/DeclineButton
)


func _ready() -> void:
	_panel.visible = false
	_add_button.pressed.connect(_on_add_pressed)
	_decline_button.pressed.connect(_on_decline_pressed)


## Opens the warranty offer dialog for a sold item.
## When warranty_tiers is non-empty, shows one button per tier plus a None option.
func open(
	item_id: String,
	item_name: String,
	sale_price: float,
	wholesale_cost: float,
	warranty_percent: float = DEFAULT_WARRANTY_PERCENT,
	warranty_tiers: Array = [],
) -> void:
	if _is_open:
		return
	_item_id = item_id
	_sale_price = sale_price
	_wholesale_cost = wholesale_cost
	_selected_tier_id = ""
	_warranty_fee = WarrantyManager.calculate_fee(
		sale_price, warranty_percent
	)
	_populate(item_name, sale_price)
	_rebuild_tier_buttons(warranty_tiers, sale_price)
	_is_open = true
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_open(_panel)
	EventBus.panel_opened.emit(PANEL_NAME)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_item_id = ""
	_sale_price = 0.0
	_warranty_fee = 0.0
	_wholesale_cost = 0.0
	_selected_tier_id = ""
	_clear_tier_buttons()
	_add_button.visible = true
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_close(_panel)
	_anim_tween.finished.connect(
		func() -> void: EventBus.panel_closed.emit(PANEL_NAME),
		CONNECT_ONE_SHOT,
	)


func is_open() -> bool:
	return _is_open


## Returns the tier_id selected by the player, or "" for the default add path.
func get_selected_tier_id() -> String:
	return _selected_tier_id


func _populate(item_name: String, sale_price: float) -> void:
	_title_label.text = "Extended Warranty"
	_item_name_label.text = item_name
	_sale_price_label.text = "Sale Price: $%.2f" % sale_price
	_warranty_cost_label.text = (
		"Warranty Cost: $%.2f" % _warranty_fee
	)
	_duration_label.text = "Duration: %d days" % (
		WarrantyManager.WARRANTY_DURATION_DAYS
	)
	_add_button.text = "Add Warranty ($%.2f)" % _warranty_fee


func _rebuild_tier_buttons(tiers: Array, sale_price: float) -> void:
	_clear_tier_buttons()
	if tiers.is_empty():
		_add_button.visible = true
		return
	_add_button.visible = false
	_warranty_cost_label.visible = false
	_duration_label.visible = false
	var button_hbox: HBoxContainer = (
		_add_button.get_parent() as HBoxContainer
	)
	var none_btn := Button.new()
	none_btn.text = "No Warranty"
	none_btn.custom_minimum_size = Vector2(100, 36)
	none_btn.pressed.connect(_on_decline_pressed)
	button_hbox.add_child(none_btn)
	button_hbox.move_child(none_btn, _decline_button.get_index())
	_tier_buttons.append(none_btn)
	for tier_entry: Variant in tiers:
		if tier_entry is not Dictionary:
			continue
		var tier_data: Dictionary = tier_entry as Dictionary
		var tier_id: String = str(tier_data.get("id", ""))
		var fee: float = WarrantyManager.calculate_tier_fee(sale_price, tier_data)
		var tier_label: String = str(
			tier_data.get("label", tier_id.capitalize())
		)
		var tier_btn := Button.new()
		tier_btn.text = "%s ($%.2f)" % [tier_label, fee]
		tier_btn.custom_minimum_size = Vector2(130, 36)
		tier_btn.pressed.connect(_on_tier_selected.bind(tier_id, fee))
		button_hbox.add_child(tier_btn)
		button_hbox.move_child(tier_btn, _decline_button.get_index())
		_tier_buttons.append(tier_btn)


func _clear_tier_buttons() -> void:
	for btn: Button in _tier_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_tier_buttons.clear()
	_warranty_cost_label.visible = true
	_duration_label.visible = true


func _on_add_pressed() -> void:
	if not _is_open:
		return
	var item_id: String = _item_id
	var fee: float = _warranty_fee
	_selected_tier_id = ""
	close()
	warranty_accepted.emit(item_id, fee)


func _on_tier_selected(tier_id: String, fee: float) -> void:
	if not _is_open:
		return
	var item_id: String = _item_id
	# Set before close() so get_selected_tier_id() returns the right value
	# when the warranty_accepted signal is handled by CheckoutSystem.
	_selected_tier_id = tier_id
	_is_open = false
	_item_id = ""
	_sale_price = 0.0
	_warranty_fee = 0.0
	_wholesale_cost = 0.0
	_clear_tier_buttons()
	_add_button.visible = true
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_close(_panel)
	_anim_tween.finished.connect(
		func() -> void: EventBus.panel_closed.emit(PANEL_NAME),
		CONNECT_ONE_SHOT,
	)
	warranty_accepted.emit(item_id, fee)


func _on_decline_pressed() -> void:
	if not _is_open:
		return
	close()
	warranty_declined.emit()
