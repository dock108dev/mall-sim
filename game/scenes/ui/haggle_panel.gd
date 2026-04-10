## UI panel for the haggling negotiation flow.
class_name HagglePanel
extends PanelContainer

signal offer_accepted
signal offer_declined
signal counter_submitted(price: float)

var _is_open: bool = false

@onready var _item_name_label: Label = (
	$Margin/VBox/ItemNameLabel
)
@onready var _condition_label: Label = (
	$Margin/VBox/ConditionLabel
)
@onready var _sticker_label: Label = (
	$Margin/VBox/StickerLabel
)
@onready var _offer_label: Label = (
	$Margin/VBox/OfferLabel
)
@onready var _round_label: Label = (
	$Margin/VBox/RoundLabel
)
@onready var _counter_input: SpinBox = (
	$Margin/VBox/CounterRow/CounterInput
)
@onready var _accept_button: Button = (
	$Margin/VBox/ButtonRow/AcceptButton
)
@onready var _counter_button: Button = (
	$Margin/VBox/ButtonRow/CounterButton
)
@onready var _decline_button: Button = (
	$Margin/VBox/ButtonRow/DeclineButton
)


func _ready() -> void:
	visible = false
	_accept_button.pressed.connect(_on_accept_pressed)
	_counter_button.pressed.connect(_on_counter_pressed)
	_decline_button.pressed.connect(_on_decline_pressed)
	EventBus.panel_opened.connect(_on_panel_opened)


## Shows the haggle panel with initial negotiation state.
func show_negotiation(
	item_name: String,
	item_condition: String,
	sticker_price: float,
	customer_offer: float,
	max_rounds: int,
) -> void:
	_item_name_label.text = item_name
	_condition_label.text = "Condition: %s" % item_condition
	_sticker_label.text = "Sticker: $%.2f" % sticker_price
	_offer_label.text = "Customer offers: $%.2f" % customer_offer
	_round_label.text = "Round 1 / %d" % max_rounds
	_counter_input.value = snappedf(customer_offer, 0.01)
	_counter_input.min_value = 0.01
	_counter_input.max_value = 99999.0
	_counter_input.step = 0.50
	_is_open = true
	visible = true


## Updates the panel when the customer makes a counter-offer.
func show_customer_counter(
	new_offer: float, round_number: int, max_rounds: int
) -> void:
	_offer_label.text = (
		"Customer offers: $%.2f" % new_offer
	)
	_round_label.text = (
		"Round %d / %d" % [round_number, max_rounds]
	)
	_counter_input.value = snappedf(new_offer, 0.01)


## Closes the haggle panel.
func hide_negotiation() -> void:
	_is_open = false
	visible = false


## Returns whether the panel is currently visible.
func is_open() -> bool:
	return _is_open


func _on_accept_pressed() -> void:
	offer_accepted.emit()


func _on_counter_pressed() -> void:
	var price: float = _counter_input.value
	counter_submitted.emit(price)


func _on_decline_pressed() -> void:
	offer_declined.emit()


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != "haggle" and _is_open:
		hide_negotiation()
		offer_declined.emit()
