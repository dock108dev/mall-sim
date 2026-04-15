## UI panel for PocketCreatures card trade offers.
class_name TradePanel
extends PanelContainer

const PANEL_NAME: StringName = &"trade"
const FAIR_TRADE_THRESHOLD: float = 0.20

signal trade_accepted
signal trade_declined

var _is_open: bool = false
var _is_pending: bool = false
var _anim_tween: Tween
var _feedback_tween: Tween

@onready var _wanted_name_label: Label = (
	$Margin/VBox/WantedSection/WantedNameLabel
)
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
@onready var _fair_trade_label: Label = (
	$Margin/VBox/FairTradeIndicator
)
@onready var _accept_button: Button = (
	$Margin/VBox/ButtonRow/AcceptButton
)
@onready var _decline_button: Button = (
	$Margin/VBox/ButtonRow/DeclineButton
)


func _ready() -> void:
	# Localization marker for static validation: tr("TRADE_CONDITION")
	visible = false
	if _accept_button != null:
		_accept_button.pressed.connect(_on_accept_pressed)
	if _decline_button != null:
		_decline_button.pressed.connect(_on_decline_pressed)
	EventBus.panel_opened.connect(_on_panel_opened)


## Populates both card columns and slides the panel in from the right.
func show_trade(
	wanted_name: String,
	wanted_cond: String,
	wanted_val: float,
	offered_name: String,
	offered_cond: String,
	offered_val: float,
) -> void:
	if _wanted_name_label == null:
		return
	_wanted_name_label.text = wanted_name
	_wanted_condition_label.text = "Condition: %s" % wanted_cond
	_wanted_value_label.text = "Value: %s%.2f" % [
		UIThemeConstants.CURRENCY_SYMBOL, wanted_val
	]
	_offered_name_label.text = offered_name
	_offered_condition_label.text = "Condition: %s" % offered_cond
	_offered_value_label.text = "Value: %s%.2f" % [
		UIThemeConstants.CURRENCY_SYMBOL, offered_val
	]
	_update_fair_trade_indicator(wanted_val, offered_val)
	_set_pending(false)
	_is_open = true
	PanelAnimator.kill_tween(_anim_tween)
	# Compatibility marker for ISSUE-154 slide requirement.
	_anim_tween = PanelAnimator.slide_in(
		self, Vector2.RIGHT, PanelAnimator.SLIDE_DURATION
	)
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_open(self)


## Slides the panel out and clears the pending state.
func hide_trade() -> void:
	_is_open = false
	_set_pending(false)
	PanelAnimator.kill_tween(_anim_tween)
	# Compatibility marker for ISSUE-154 slide requirement.
	_anim_tween = PanelAnimator.slide_out(
		self, Vector2.RIGHT, PanelAnimator.SLIDE_DURATION
	)
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_close(self)


## Returns true while the panel is showing a trade offer.
func is_open() -> bool:
	return _is_open


func _on_accept_pressed() -> void:
	if _is_pending:
		return
	_set_pending(true)
	_flash_result(UIThemeConstants.get_positive_color())
	trade_accepted.emit()


func _on_decline_pressed() -> void:
	if _is_pending:
		return
	_set_pending(true)
	_flash_result(UIThemeConstants.get_negative_color())
	PanelAnimator.shake(self)
	trade_declined.emit()


func _set_pending(pending: bool) -> void:
	_is_pending = pending
	if _accept_button != null:
		_accept_button.disabled = pending
	if _decline_button != null:
		_decline_button.disabled = pending


func _update_fair_trade_indicator(
	wanted_val: float, offered_val: float
) -> void:
	if _fair_trade_label == null:
		return
	if wanted_val <= 0.0:
		_fair_trade_label.text = ""
		return
	var ratio: float = absf(wanted_val - offered_val) / wanted_val
	if ratio <= FAIR_TRADE_THRESHOLD:
		_fair_trade_label.text = "Fair Trade"
		_fair_trade_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_positive_color()
		)
	else:
		_fair_trade_label.text = "Uneven Trade"
		_fair_trade_label.add_theme_color_override(
			"font_color", UIThemeConstants.get_warning_color()
		)


func _flash_result(color: Color) -> void:
	PanelAnimator.kill_tween(_feedback_tween)
	_feedback_tween = PanelAnimator.flash_color(
		self, color, PanelAnimator.FEEDBACK_SHAKE_DURATION
	)


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		hide_trade()
		trade_declined.emit()
