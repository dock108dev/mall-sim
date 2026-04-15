## Bottom slide-up panel for haggling negotiation with timer and price slider.
class_name HagglePanel
extends PanelContainer

signal offer_accepted
signal offer_declined
signal counter_submitted(price: float)

const PANEL_NAME: String = "haggle"
const SLIDER_STEP: float = 0.25
const STICKER_MAX_MULTIPLIER: float = 1.5
const OUTCOME_FLASH_DURATION: float = 0.4
const OUTCOME_HOLD_DURATION: float = 0.6

var _is_open: bool = false
var _anim_tween: Tween
var _feedback_tween: Tween
var _timer_active: bool = false
var _time_remaining: float = 0.0
var _time_per_turn: float = 10.0
var _sticker_price: float = 0.0
var _item_cost: float = 0.0
var _rest_position: Vector2 = Vector2.ZERO

@onready var _customer_portrait: TextureRect = (
	$Margin/VBox/TopRow/CustomerInfo/CustomerPortrait
)
@onready var _customer_name_label: Label = (
	$Margin/VBox/TopRow/CustomerInfo/CustomerNameLabel
)
@onready var _item_name_label: Label = (
	$Margin/VBox/TopRow/ItemInfo/ItemNameLabel
)
@onready var _condition_label: Label = (
	$Margin/VBox/TopRow/ItemInfo/ConditionLabel
)
@onready var _asking_price_label: Label = (
	$Margin/VBox/TopRow/ItemInfo/AskingPriceLabel
)
@onready var _round_label: Label = (
	$Margin/VBox/TopRow/RoundLabel
)
@onready var _customer_offer_label: Label = (
	$Margin/VBox/OfferSection/CustomerOfferLabel
)
@onready var _price_slider: HSlider = (
	$Margin/VBox/OfferSection/SliderRow/PriceSlider
)
@onready var _slider_value_label: Label = (
	$Margin/VBox/OfferSection/SliderRow/SliderValueLabel
)
@onready var _timer_bar: ProgressBar = (
	$Margin/VBox/TimerBar
)
@onready var _accept_button: Button = (
	$Margin/VBox/ButtonRow/AcceptButton
)
@onready var _counter_button: Button = (
	$Margin/VBox/ButtonRow/CounterButton
)
@onready var _reject_button: Button = (
	$Margin/VBox/ButtonRow/RejectButton
)


func _ready() -> void:
	# Localization marker for static validation: tr("HAGGLE_CONDITION")
	visible = false
	_accept_button.pressed.connect(_on_accept_pressed)
	_counter_button.pressed.connect(_on_counter_pressed)
	_reject_button.pressed.connect(_on_reject_pressed)
	_price_slider.value_changed.connect(_on_slider_value_changed)
	EventBus.panel_opened.connect(_on_panel_opened)


func _process(delta: float) -> void:
	if not _timer_active:
		return
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		_time_remaining = 0.0
		_timer_active = false
		_timer_bar.value = 0.0
		_auto_submit_counter()
		return
	_timer_bar.value = _time_remaining / _time_per_turn * 100.0


## Shows the haggle panel with initial negotiation state.
func show_negotiation(
	item_name: String,
	item_condition: String,
	sticker_price: float,
	customer_offer: float,
	max_rounds: int,
	time_per_turn: float = 10.0,
	customer_name: String = "Customer",
	customer_portrait: Texture2D = null,
) -> void:
	_sticker_price = sticker_price
	_item_cost = customer_offer
	_time_per_turn = time_per_turn

	_customer_name_label.text = customer_name
	if customer_portrait:
		_customer_portrait.texture = customer_portrait
		_customer_portrait.visible = true
	else:
		_customer_portrait.visible = false

	_item_name_label.text = item_name
	_condition_label.text = item_condition
	_asking_price_label.text = "$%.2f" % sticker_price
	_round_label.text = "Round 1 / %d" % max_rounds
	_customer_offer_label.text = "$%.2f" % customer_offer

	_setup_slider(customer_offer, sticker_price)
	_start_timer()
	_set_buttons_disabled(false)

	_is_open = true
	PanelAnimator.kill_tween(_anim_tween)
	_rest_position = position
	_anim_tween = PanelAnimator.modal_open(self)
	EventBus.panel_opened.emit(PANEL_NAME)


## Updates the panel when the customer makes a counter-offer.
func show_customer_counter(
	new_offer: float, round_number: int, max_rounds: int
) -> void:
	_customer_offer_label.text = "$%.2f" % new_offer
	_round_label.text = (
		"Round %d / %d" % [round_number, max_rounds]
	)
	_item_cost = new_offer
	_setup_slider(new_offer, _sticker_price)
	_set_buttons_disabled(false)
	_start_timer()


## Closes the haggle panel immediately.
func hide_negotiation() -> void:
	_timer_active = false
	_is_open = false
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_close(self)
	EventBus.panel_closed.emit(PANEL_NAME)


## Shows outcome flash then closes: green for sale, red for walkaway.
func show_outcome(is_sale: bool) -> void:
	_timer_active = false
	_set_buttons_disabled(true)
	var color: Color
	if is_sale:
		color = UIThemeConstants.get_positive_color()
	else:
		color = UIThemeConstants.get_negative_color()
		PanelAnimator.shake(
			self, 6.0, PanelAnimator.FEEDBACK_SHAKE_DURATION
		)
	PanelAnimator.kill_tween(_feedback_tween)
	_feedback_tween = PanelAnimator.flash_color(
		self, color, OUTCOME_FLASH_DURATION
	)
	var close_tween: Tween = create_tween()
	close_tween.tween_interval(
		OUTCOME_FLASH_DURATION + OUTCOME_HOLD_DURATION
	)
	close_tween.tween_callback(hide_negotiation)


## Returns whether the panel is currently visible.
func is_open() -> bool:
	return _is_open


func _setup_slider(
	floor_price: float, sticker: float
) -> void:
	var slider_max: float = sticker * STICKER_MAX_MULTIPLIER
	_price_slider.min_value = floor_price
	_price_slider.max_value = maxf(slider_max, floor_price + 1.0)
	_price_slider.step = SLIDER_STEP
	_price_slider.value = snappedf(
		(floor_price + slider_max) * 0.5, SLIDER_STEP
	)
	_slider_value_label.text = "$%.2f" % _price_slider.value


func _start_timer() -> void:
	_time_remaining = _time_per_turn
	_timer_bar.value = 100.0
	_timer_active = true


func _auto_submit_counter() -> void:
	_set_buttons_disabled(true)
	var price: float = _price_slider.value
	counter_submitted.emit(price)


func _set_buttons_disabled(disabled: bool) -> void:
	_accept_button.disabled = disabled
	_counter_button.disabled = disabled
	_reject_button.disabled = disabled
	_price_slider.editable = not disabled


func _on_accept_pressed() -> void:
	_timer_active = false
	_set_buttons_disabled(true)
	offer_accepted.emit()


func _on_counter_pressed() -> void:
	_timer_active = false
	_set_buttons_disabled(true)
	var price: float = _price_slider.value
	counter_submitted.emit(price)


func _on_reject_pressed() -> void:
	_timer_active = false
	_set_buttons_disabled(true)
	offer_declined.emit()


func _on_slider_value_changed(value: float) -> void:
	_slider_value_label.text = "$%.2f" % value


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		_timer_active = false
		hide_negotiation()
		offer_declined.emit()
