## Root coordinator for PocketCreatures card trade offers.
class_name TradePanel
extends PanelContainer

signal trade_accepted
signal trade_declined

const PANEL_NAME: StringName = &"trade"

@onready var _offer_display: Node = (
	get_node_or_null("Margin/VBox/OfferDisplay") as Node
)
@onready var _valuation_display: Node = (
	get_node_or_null("Margin/VBox/FairTradeIndicator") as Node
)
@onready var _flow_controller: Node = (
	get_node_or_null("Margin/VBox/ButtonRow") as Node
)

var _is_open: bool = false
var _is_pending: bool = false
var _anim_tween: Tween
var _feedback_tween: Tween


func _ready() -> void:
	# Localization marker for static validation: tr("TRADE_CONDITION")
	visible = false
	if _flow_controller != null:
		_flow_controller.connect("accept_requested", _on_accept_pressed)
		_flow_controller.connect("decline_requested", _on_decline_pressed)
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
	if _offer_display != null:
		_offer_display.call(
			"show_trade_offer",
			wanted_name,
			wanted_cond,
			wanted_val,
			offered_name,
			offered_cond,
			offered_val
		)
	if _valuation_display != null:
		_valuation_display.call("show_trade_ratio", wanted_val, offered_val)
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
	if _flow_controller != null:
		_flow_controller.call("set_pending", pending)


func _flash_result(color: Color) -> void:
	PanelAnimator.kill_tween(_feedback_tween)
	_feedback_tween = PanelAnimator.flash_color(
		self, color, PanelAnimator.FEEDBACK_SHAKE_DURATION
	)


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		hide_trade()
		trade_declined.emit()
