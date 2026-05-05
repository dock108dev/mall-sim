## Bottom slide-up panel for haggling negotiations.
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
const RESULT_DISPLAY_DURATION: float = 3.0

var _is_open: bool = false
var _anim_tween: Tween
var _feedback_tween: Tween
var _close_tween: Tween
var _timer_active: bool = false
var _showing_result: bool = false
var _time_remaining: float = 0.0
var _time_per_turn: float = 10.0
var _sticker_price: float = 0.0
var _item_cost: float = 0.0
var _current_customer_offer: float = 0.0
var _haggle_system: HaggleSystem = null
var _relay_actions_to_system: bool = false
var _result_timer: Timer = null
var _card_populated: bool = false

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
@onready var _archetype_badge: PanelContainer = (
	$Margin/VBox/TopRow/ArchetypeBadge
)
@onready var _archetype_label: Label = (
	$Margin/VBox/TopRow/ArchetypeBadge/ArchetypeLabel
)
@onready var _context_label: Label = (
	$Margin/VBox/ContextLabel
)
@onready var _reasoning_label: RichTextLabel = (
	$Margin/VBox/ReasoningLabel
)
@onready var _result_label: Label = (
	$Margin/VBox/ResultLabel
)


func _ready() -> void:
	visible = false
	DecisionCardStyle.apply_reasoning_style(_reasoning_label)
	_accept_button.pressed.connect(_on_accept_pressed)
	_counter_button.pressed.connect(_on_counter_pressed)
	_reject_button.pressed.connect(_on_reject_pressed)
	_price_slider.value_changed.connect(_on_slider_value_changed)
	_result_timer = Timer.new()
	_result_timer.one_shot = true
	_result_timer.wait_time = RESULT_DISPLAY_DURATION
	_result_timer.timeout.connect(_on_result_timer_timeout)
	add_child(_result_timer)
	EventBus.haggle_requested.connect(_on_haggle_requested)
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


## Binds the panel to a HaggleSystem for reactive state updates.
func bind_haggle_system(
	system: HaggleSystem, relay_actions_to_system: bool = true
) -> void:
	_haggle_system = system
	_relay_actions_to_system = relay_actions_to_system
	if _haggle_system == null:
		return
	if not _haggle_system.negotiation_started.is_connected(
		_on_negotiation_started
	):
		_haggle_system.negotiation_started.connect(_on_negotiation_started)
	if not _haggle_system.customer_countered.is_connected(
		_on_customer_countered
	):
		_haggle_system.customer_countered.connect(_on_customer_countered)
	if not _haggle_system.negotiation_accepted.is_connected(
		_on_negotiation_accepted
	):
		_haggle_system.negotiation_accepted.connect(_on_negotiation_accepted)
	if not _haggle_system.negotiation_failed.is_connected(
		_on_negotiation_failed
	):
		_haggle_system.negotiation_failed.connect(_on_negotiation_failed)
	if _haggle_system.has_signal("session_state_changed"):
		var changed_signal: Signal = _haggle_system.session_state_changed
		if not changed_signal.is_connected(_on_session_state_changed):
			changed_signal.connect(_on_session_state_changed)


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
	item_cost: float = -1.0,
) -> void:
	_sticker_price = maxf(sticker_price, 0.0)
	_item_cost = _resolve_item_cost(item_cost, customer_offer)
	_current_customer_offer = maxf(customer_offer, 0.0)
	_time_per_turn = maxf(time_per_turn, 0.01)

	_customer_name_label.text = customer_name
	_set_customer_portrait(customer_portrait)
	_item_name_label.text = item_name
	_condition_label.text = item_condition
	_asking_price_label.text = "$%.2f" % _sticker_price
	_round_label.text = "Round 1 / %d" % maxi(max_rounds, 1)
	_customer_offer_label.text = "$%.2f" % _current_customer_offer

	_setup_slider(_item_cost, _sticker_price)
	_start_timer()
	_set_buttons_disabled(false)
	_slide_in()


## Updates UI fields from the canonical HaggleSession state.
func update_from_session(
	session: HaggleSession,
	item_name: String = "",
	item_condition: String = "",
	item_cost: float = -1.0,
) -> void:
	if session == null:
		return
	var customer_name: String = _get_customer_name(session.customer_ref)
	var portrait: Texture2D = _get_customer_portrait(session.customer_ref)
	if not item_name.is_empty():
		_item_name_label.text = item_name
	if not item_condition.is_empty():
		_condition_label.text = item_condition
	_customer_name_label.text = customer_name
	_set_customer_portrait(portrait)
	_sticker_price = maxf(session.sticker_price, 0.0)
	_item_cost = _resolve_item_cost(item_cost, session.perceived_value)
	_current_customer_offer = maxf(session.current_offer, 0.0)
	_time_per_turn = maxf(session.time_per_turn, 0.01)
	_asking_price_label.text = "$%.2f" % _sticker_price
	_customer_offer_label.text = "$%.2f" % _current_customer_offer
	_round_label.text = "Round %d / %d" % [
		maxi(session.round_number, 1), maxi(session.max_rounds, 1)
	]
	_setup_slider(_item_cost, _sticker_price)
	_apply_session_state(session.state)


## Updates the panel when the customer makes a counter-offer.
func show_customer_counter(
	new_offer: float, round_number: int, max_rounds: int
) -> void:
	_current_customer_offer = maxf(new_offer, 0.0)
	_customer_offer_label.text = "$%.2f" % _current_customer_offer
	_round_label.text = (
		"Round %d / %d" % [maxi(round_number, 1), maxi(max_rounds, 1)]
	)
	_setup_slider(_item_cost, _sticker_price)
	_set_buttons_disabled(false)
	_start_timer()


## Closes the haggle panel with a bottom-edge slide-out animation.
func hide_negotiation() -> void:
	_timer_active = false
	_is_open = false
	_showing_result = false
	_card_populated = false
	if _result_timer:
		_result_timer.stop()
	if _result_label:
		_result_label.visible = false
	if _archetype_badge:
		_archetype_badge.visible = false
	if _context_label:
		_context_label.visible = false
	if _reasoning_label:
		_reasoning_label.visible = false
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.slide_out(self, Vector2.DOWN)
	EventBus.panel_closed.emit(PANEL_NAME)


## Augments the haggle panel with archetype label, context, reasoning, and a
## consequence-preview hint on the action buttons. All keys are optional —
## omit a key to skip that surface.
##
## Expected keys:
##   archetype_id    : StringName — color tier
##   archetype_label : String     — text shown in the badge
##   context         : String     — 1-sentence mood / situation
##   reasoning       : String     — 1-sentence italic hint
##   accept_consequence : String  — secondary line on Accept button
##   counter_consequence: String  — secondary line on Counter button
##   reject_consequence : String  — secondary line on Reject button
func populate_customer_card(customer_data: Dictionary) -> void:
	_card_populated = true
	var archetype_id: StringName = StringName(
		str(customer_data.get("archetype_id", ""))
	)
	var archetype_label: String = str(
		customer_data.get("archetype_label", "")
	)
	var context_text: String = str(customer_data.get("context", ""))
	var reasoning_text: String = str(customer_data.get("reasoning", ""))

	if not archetype_label.is_empty():
		_archetype_label.text = archetype_label.to_upper()
		_archetype_badge.visible = true
		DecisionCardStyle.apply_archetype_badge_style(
			_archetype_badge, _archetype_label, archetype_id
		)
	else:
		_archetype_badge.visible = false

	if context_text.is_empty():
		_context_label.visible = false
	else:
		_context_label.text = context_text
		_context_label.visible = true

	if reasoning_text.is_empty():
		_reasoning_label.visible = false
	else:
		# §F-129 — `_reasoning_label` has `bbcode_enabled = true`. Escape
		# `[` → `[lb]` so a future caller that wires save-derived or
		# runtime-typed text through `customer_data["reasoning"]` cannot
		# inject BBCode tags ([url=...], [color], …) into the label. Mirrors
		# the same defense-in-depth on `CheckoutPanel._set_reasoning_text`.
		_reasoning_label.text = "[i]%s[/i]" % reasoning_text.replace(
			"[", "[lb]"
		)
		_reasoning_label.visible = true

	var accept_consequence: String = str(
		customer_data.get("accept_consequence", "")
	)
	var counter_consequence: String = str(
		customer_data.get("counter_consequence", "")
	)
	var reject_consequence: String = str(
		customer_data.get("reject_consequence", "")
	)
	_accept_button.tooltip_text = accept_consequence
	_counter_button.tooltip_text = counter_consequence
	_reject_button.tooltip_text = reject_consequence


## Transitions the haggle panel into a brief Result state. Auto-dismisses after
## RESULT_DISPLAY_DURATION or on any subsequent interaction.
func show_result(resolution_text: String) -> void:
	if resolution_text.is_empty():
		return
	_showing_result = true
	_set_buttons_disabled(true)
	_result_label.text = resolution_text
	_result_label.visible = true
	if _result_timer:
		_result_timer.stop()
		_result_timer.start()


func is_card_populated() -> bool:
	return _card_populated


func is_showing_result() -> bool:
	return _showing_result


## Shows outcome flash then closes: green for sale, red for walkaway.
func show_outcome(is_sale: bool) -> void:
	_timer_active = false
	_set_buttons_disabled(true)
	var color: Color = UIThemeConstants.get_positive_color()
	if not is_sale:
		color = UIThemeConstants.get_negative_color()
		PanelAnimator.shake(
			self, 6.0, PanelAnimator.FEEDBACK_SHAKE_DURATION
		)
	PanelAnimator.kill_tween(_feedback_tween)
	PanelAnimator.kill_tween(_close_tween)
	_feedback_tween = PanelAnimator.flash_color(
		self, color, OUTCOME_FLASH_DURATION
	)
	_close_tween = create_tween()
	_close_tween.tween_interval(
		OUTCOME_FLASH_DURATION + OUTCOME_HOLD_DURATION
	)
	_close_tween.tween_callback(hide_negotiation)


## Returns whether the panel is currently visible for negotiation.
func is_open() -> bool:
	return _is_open


func _slide_in() -> void:
	_is_open = true
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.slide_in(self, Vector2.DOWN)
	EventBus.panel_opened.emit(PANEL_NAME)


func _setup_slider(floor_price: float, sticker: float) -> void:
	var slider_max: float = sticker * STICKER_MAX_MULTIPLIER
	_price_slider.min_value = maxf(floor_price, 0.0)
	_price_slider.max_value = maxf(slider_max, _price_slider.min_value)
	_price_slider.step = SLIDER_STEP
	_price_slider.value = snappedf(
		clampf(
			maxf(_current_customer_offer, _price_slider.min_value),
			_price_slider.min_value,
			_price_slider.max_value
		),
		SLIDER_STEP
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
	if _relay_actions_to_system and _haggle_system and _haggle_system.is_active():
		_haggle_system.player_counter(price)


func _set_buttons_disabled(disabled: bool) -> void:
	_accept_button.disabled = disabled
	_counter_button.disabled = disabled
	_reject_button.disabled = disabled
	_price_slider.editable = not disabled


func _set_customer_portrait(texture: Texture2D) -> void:
	_customer_portrait.texture = texture
	_customer_portrait.visible = texture != null


func _resolve_item_cost(item_cost: float, fallback: float) -> float:
	if item_cost >= 0.0:
		return item_cost
	return maxf(fallback, 0.0)


func _apply_session_state(state: HaggleSession.HaggleState) -> void:
	match state:
		HaggleSession.HaggleState.CUSTOMER_TURN, HaggleSession.HaggleState.EVALUATE:
			_timer_active = false
			_set_buttons_disabled(true)
		HaggleSession.HaggleState.PLAYER_TURN:
			_set_buttons_disabled(false)
			_start_timer()
			if not _is_open:
				_slide_in()
		HaggleSession.HaggleState.SALE_COMPLETE:
			show_outcome(true)
		HaggleSession.HaggleState.WALKAWAY:
			show_outcome(false)
		_:
			_timer_active = false


func _get_customer_name(customer: Object) -> String:
	if customer == null:
		return "Customer"
	var profile: Object = customer.get("profile") as Object
	if profile != null:
		var profile_name: String = str(profile.get("customer_name"))
		if not profile_name.is_empty():
			return profile_name
	var display_name: String = str(customer.get("display_name"))
	if not display_name.is_empty() and display_name != "<null>":
		return display_name
	var customer_id: String = str(customer.get("customer_id"))
	if not customer_id.is_empty() and customer_id != "<null>":
		return customer_id
	if customer is Node and not (customer as Node).name.is_empty():
		return (customer as Node).name
	return "Customer"


func _get_customer_portrait(customer: Object) -> Texture2D:
	if customer == null:
		return null
	var portrait: Texture2D = customer.get("portrait_texture") as Texture2D
	if portrait != null:
		return portrait
	var profile: Object = customer.get("profile") as Object
	if profile != null:
		return profile.get("portrait_texture") as Texture2D
	return null


func _on_accept_pressed() -> void:
	_timer_active = false
	_set_buttons_disabled(true)
	offer_accepted.emit()
	if _relay_actions_to_system and _haggle_system and _haggle_system.is_active():
		_haggle_system.accept_offer()


func _on_counter_pressed() -> void:
	_timer_active = false
	_set_buttons_disabled(true)
	var price: float = _price_slider.value
	counter_submitted.emit(price)
	if _relay_actions_to_system and _haggle_system and _haggle_system.is_active():
		_haggle_system.player_counter(price)


func _on_reject_pressed() -> void:
	_timer_active = false
	_set_buttons_disabled(true)
	offer_declined.emit()
	if _relay_actions_to_system and _haggle_system and _haggle_system.is_active():
		_haggle_system.decline_offer()


func _on_slider_value_changed(value: float) -> void:
	_slider_value_label.text = "$%.2f" % value


func _on_haggle_requested(_item_id: String, _customer_id: int) -> void:
	if not _is_open:
		_slide_in()
	_set_buttons_disabled(true)
	_timer_active = false


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		hide_negotiation()
		offer_declined.emit()


func _on_negotiation_started(
	item_name: String,
	item_condition: String,
	sticker_price: float,
	customer_offer: float,
	max_rounds: int,
) -> void:
	var turn_time: float = 10.0
	if _haggle_system != null:
		turn_time = _haggle_system.time_per_turn
	show_negotiation(
		item_name, item_condition, sticker_price, customer_offer,
		max_rounds, turn_time
	)


func _on_customer_countered(new_offer: float, round_number: int) -> void:
	var max_rounds: int = 1
	if _haggle_system != null:
		max_rounds = _haggle_system._max_rounds_for_customer
	show_customer_counter(new_offer, round_number, max_rounds)


func _on_negotiation_accepted(_final_price: float) -> void:
	if _is_open:
		show_outcome(true)


func _on_negotiation_failed() -> void:
	if _is_open:
		show_outcome(false)


func _on_session_state_changed(session: HaggleSession) -> void:
	update_from_session(session)


func _on_result_timer_timeout() -> void:
	if _is_open:
		hide_negotiation()
