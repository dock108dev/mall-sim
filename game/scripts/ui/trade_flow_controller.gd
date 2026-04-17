## Manages pending state and button intent signals for the trade panel.
class_name TradeFlowController
extends HBoxContainer

signal accept_requested
signal decline_requested

@onready var _decline_button: Button = (
	get_node_or_null("DeclineButton") as Button
)
@onready var _accept_button: Button = (
	get_node_or_null("AcceptButton") as Button
)

var _is_pending: bool = false


func _ready() -> void:
	if _accept_button != null:
		_accept_button.pressed.connect(_on_accept_button_pressed)
	if _decline_button != null:
		_decline_button.pressed.connect(_on_decline_button_pressed)


## Updates button interactivity while a trade action is in flight.
func set_pending(pending: bool) -> void:
	_is_pending = pending
	if _accept_button != null:
		_accept_button.disabled = pending
	if _decline_button != null:
		_decline_button.disabled = pending


func _on_accept_button_pressed() -> void:
	if _is_pending:
		return
	set_pending(true)
	accept_requested.emit()


func _on_decline_button_pressed() -> void:
	if _is_pending:
		return
	set_pending(true)
	decline_requested.emit()
