## UI panel for PocketCreatures card trade offers.
class_name TradePanel
extends PanelContainer

signal trade_accepted
signal trade_declined

var _is_open: bool = false
var _anim_tween: Tween
var _feedback_tween: Tween

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
	_wanted_condition_label.text = tr("TRADE_CONDITION") % wanted_condition
	_wanted_value_label.text = tr("TRADE_VALUE") % wanted_value
	_offered_name_label.text = offered_name
	_offered_condition_label.text = tr("TRADE_CONDITION") % offered_condition
	_offered_value_label.text = tr("TRADE_VALUE") % offered_value
	_is_open = true
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_open(self)


## Closes the trade panel.
func hide_trade() -> void:
	_is_open = false
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_close(self)


## Returns whether the panel is currently visible.
func is_open() -> bool:
	return _is_open


func _on_accept_pressed() -> void:
	_flash_result(UIThemeConstants.get_positive_color())
	trade_accepted.emit()


func _on_decline_pressed() -> void:
	_flash_result(UIThemeConstants.get_negative_color())
	PanelAnimator.shake(self)
	trade_declined.emit()


func _flash_result(color: Color) -> void:
	PanelAnimator.kill_tween(_feedback_tween)
	_feedback_tween = PanelAnimator.flash_color(
		self, color, PanelAnimator.FEEDBACK_SHAKE_DURATION
	)


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != "trade" and _is_open:
		hide_trade()
		trade_declined.emit()
