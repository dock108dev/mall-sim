## UI panel for PocketCreatures card trade offers.
class_name TradePanel
extends PanelContainer

signal trade_accepted
signal trade_declined

var _is_open: bool = false

@onready var _wanted_name_label: Label = $Margin/VBox/WantedSection/WantedNameLabel
@onready var _wanted_condition_label: Label = (
	$Margin/VBox/WantedSection/WantedConditionLabel
)
@onready var _wanted_value_label: Label = (
	$Margin/VBox/WantedSection/WantedValueLabel
)
@onready var _offered_name_label: Label = (
	$Margin/VBox/OfferedSection/OfferedNameLabel
)
@onready var _offered_condition_label: Label = (
	$Margin/VBox/OfferedSection/OfferedConditionLabel
)
@onready var _offered_value_label: Label = (
	$Margin/VBox/OfferedSection/OfferedValueLabel
)
@onready var _accept_button: Button = (
	$Margin/VBox/ButtonRow/AcceptButton
)
@onready var _decline_button: Button = (
	$Margin/VBox/ButtonRow/DeclineButton
)


func _ready() -> void:
	visible = false
	_accept_button.pressed.connect(_on_accept_pressed)
	_decline_button.pressed.connect(_on_decline_pressed)
	EventBus.panel_opened.connect(_on_panel_opened)


## Shows the trade panel with details of both cards.
func show_trade(
	wanted_name: String,
	wanted_condition: String,
	wanted_value: float,
	offered_name: String,
	offered_condition: String,
	offered_value: float,
) -> void:
	_wanted_name_label.text = wanted_name
	_wanted_condition_label.text = "Condition: %s" % wanted_condition
	_wanted_value_label.text = "Value: $%.2f" % wanted_value
	_offered_name_label.text = offered_name
	_offered_condition_label.text = "Condition: %s" % offered_condition
	_offered_value_label.text = "Value: $%.2f" % offered_value
	_is_open = true
	visible = true


## Closes the trade panel.
func hide_trade() -> void:
	_is_open = false
	visible = false


## Returns whether the panel is currently visible.
func is_open() -> bool:
	return _is_open


func _on_accept_pressed() -> void:
	trade_accepted.emit()


func _on_decline_pressed() -> void:
	trade_declined.emit()


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != "trade" and _is_open:
		hide_trade()
		trade_declined.emit()
