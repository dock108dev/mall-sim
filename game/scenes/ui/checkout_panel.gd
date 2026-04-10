## UI panel for the checkout flow showing item details and accept/decline buttons.
class_name CheckoutPanel
extends PanelContainer

signal sale_accepted
signal sale_declined

var _is_open: bool = false
var _warranty_offered: bool = false
var _warranty_percent: float = 0.20
var _current_offer: float = 0.0
var _anim_tween: Tween

@onready var _item_name_label: Label = $Margin/VBox/ItemNameLabel
@onready var _condition_label: Label = $Margin/VBox/ConditionLabel
@onready var _offer_label: Label = $Margin/VBox/OfferLabel
@onready var _accept_button: Button = $Margin/VBox/ButtonRow/AcceptButton
@onready var _decline_button: Button = (
	$Margin/VBox/ButtonRow/DeclineButton
)
@onready var _warranty_section: VBoxContainer = (
	$Margin/VBox/WarrantySection
)
@onready var _warranty_toggle: CheckButton = (
	$Margin/VBox/WarrantySection/WarrantyToggle
)
@onready var _warranty_slider: HSlider = (
	$Margin/VBox/WarrantySection/SliderRow/WarrantySlider
)
@onready var _slider_label: Label = (
	$Margin/VBox/WarrantySection/SliderRow/SliderLabel
)
@onready var _warranty_fee_label: Label = (
	$Margin/VBox/WarrantySection/WarrantyFeeLabel
)


func _ready() -> void:
	visible = false
	_accept_button.pressed.connect(_on_accept_pressed)
	_decline_button.pressed.connect(_on_decline_pressed)
	_warranty_toggle.toggled.connect(_on_warranty_toggled)
	_warranty_slider.value_changed.connect(_on_slider_changed)
	EventBus.panel_opened.connect(_on_panel_opened)


## Opens the panel with item details and the customer's offer price.
func show_checkout(
	item_name: String,
	item_condition: String,
	offer_price: float,
	show_warranty: bool = false,
) -> void:
	_item_name_label.text = item_name
	_condition_label.text = "Condition: %s" % item_condition
	_offer_label.text = "Offer: $%.2f" % offer_price
	_current_offer = offer_price
	_warranty_offered = false
	_warranty_toggle.button_pressed = false
	_warranty_slider.value = 20.0
	_warranty_section.visible = show_warranty
	_warranty_slider.visible = false
	_warranty_fee_label.visible = false
	_update_warranty_fee_display()
	PanelAnimator.kill_tween(_anim_tween)
	_is_open = true
	_anim_tween = PanelAnimator.modal_open(self)


## Closes the checkout panel.
func hide_checkout(immediate: bool = false) -> void:
	PanelAnimator.kill_tween(_anim_tween)
	_is_open = false
	if immediate:
		visible = false
		modulate = Color.WHITE
		scale = Vector2.ONE
	else:
		_anim_tween = PanelAnimator.modal_close(self)


## Returns whether the panel is currently visible.
func is_open() -> bool:
	return _is_open


## Returns true if the player toggled the warranty offer on.
func is_warranty_offered() -> bool:
	return _warranty_offered and _warranty_section.visible


## Returns the selected warranty percentage as a decimal (0.15-0.25).
func get_warranty_percent() -> float:
	return _warranty_percent


## Returns the calculated warranty fee based on current settings.
func get_warranty_fee() -> float:
	return WarrantyManager.calculate_fee(
		_current_offer, _warranty_percent
	)


func _on_accept_pressed() -> void:
	sale_accepted.emit()


func _on_decline_pressed() -> void:
	sale_declined.emit()


func _on_warranty_toggled(pressed: bool) -> void:
	_warranty_offered = pressed
	_warranty_slider.visible = pressed
	_warranty_fee_label.visible = pressed
	_update_warranty_fee_display()


func _on_slider_changed(value: float) -> void:
	_warranty_percent = value / 100.0
	_slider_label.text = "%d%%" % int(value)
	_update_warranty_fee_display()


func _update_warranty_fee_display() -> void:
	var fee: float = WarrantyManager.calculate_fee(
		_current_offer, _warranty_percent
	)
	_warranty_fee_label.text = "Warranty Fee: $%.2f" % fee


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != "checkout" and _is_open:
		hide_checkout(true)
		sale_declined.emit()
