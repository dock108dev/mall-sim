## Unified in-store action drawer. Chrome layer renders per-store action buttons
## from EventBus.actions_registered; content layer switches between mechanic
## panels (HAGGLE, REFURB, AUTHENTICATE, WARRANTY, TRADE) driven by
## EventBus.action_requested. All player-interaction outcomes are emitted on
## EventBus — no direct cross-scene coupling.
class_name ActionDrawer
extends PanelContainer

## Mechanic modes the drawer content area can display.
enum Mode {
	IDLE = 0,
	HAGGLE = 1,
	REFURB = 2,
	AUTHENTICATE = 3,
	WARRANTY = 4,
	TRADE = 5,
}

## Maps action_id → Mode that should open when the button is pressed.
const ACTION_MODE_MAP: Dictionary = {
	&"haggle":           Mode.HAGGLE,
	&"refurbish":        Mode.REFURB,
	&"authenticate":     Mode.AUTHENTICATE,
	&"grade":            Mode.AUTHENTICATE,
	&"send_for_grading": Mode.AUTHENTICATE,
	&"grading_hint":     Mode.AUTHENTICATE,
	&"offer_warranty":   Mode.WARRANTY,
	&"open_pack":        Mode.TRADE,
}

const CONTENT_HEIGHT: float = 200.0
const ANIM_DURATION: float = 0.20
const ACTION_ID_KEY: String = "id"
const ACTION_LABEL_KEY: String = "label"
const ACTION_ICON_KEY: String = "icon"

## Currently active mechanic mode. IDLE means content is hidden.
var current_mode: Mode = Mode.IDLE

var _current_store_id: StringName = &""
var _action_ids: Array[StringName] = []
var _tween: Tween = null

# ── Haggle pane state ────────────────────────────────────────────────────────
var _haggle_sticker_price: float = 0.0
var _haggle_customer_offer: float = 0.0
var _haggle_max_rounds: int = 3
var _haggle_round: int = 1

# ── Warranty pane state ──────────────────────────────────────────────────────
var _warranty_item_id: String = ""
var _warranty_tier_id: String = ""

# ── Auth pane state ──────────────────────────────────────────────────────────
var _auth_item_id: String = ""

# ── Per-mode panes (built in _ready) ─────────────────────────────────────────
var _panes: Dictionary = {}

# Haggle pane node refs
var _haggle_offer_label: Label = null
var _haggle_round_label: Label = null
var _haggle_counter_input: SpinBox = null

# Warranty pane node refs
var _warranty_offer_label: Label = null

# Auth pane node refs
var _auth_item_label: Label = null

# Refurb pane node refs
var _refurb_status_label: Label = null

# Trade pane node refs
var _trade_offer_label: Label = null

# ── Scene refs ────────────────────────────────────────────────────────────────
@onready var _button_container: BoxContainer = $Layout/Chrome/Margin/Buttons
@onready var _separator: HSeparator = $Layout/Separator
@onready var _content: VBoxContainer = $Layout/Content


func _ready() -> void:
	_separator.hide()
	_content.hide()
	_build_mode_panes()
	_connect_signals()


# ── Public API ────────────────────────────────────────────────────────────────

## Returns the action ids currently rendered in the chrome bar.
func get_action_ids() -> Array[StringName]:
	return _action_ids.duplicate()


## Returns the store whose actions are currently displayed.
func get_current_store_id() -> StringName:
	return _current_store_id


## Returns the active mechanic mode.
func get_current_mode() -> Mode:
	return current_mode


## Slides the content panel open in the given mode. No-op for Mode.IDLE.
func open_mode(mode: Mode) -> void:
	if mode == Mode.IDLE:
		close_mode()
		return
	current_mode = mode
	_show_pane(mode)
	_separator.show()
	_content.show()
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(
		_content, "custom_minimum_size:y", CONTENT_HEIGHT, ANIM_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	EventBus.action_drawer_opened.emit(mode as int)


## Slides the content panel closed and returns to IDLE.
func close_mode() -> void:
	if current_mode == Mode.IDLE:
		return
	current_mode = Mode.IDLE
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(
		_content, "custom_minimum_size:y", 0.0, ANIM_DURATION
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_callback(_on_close_finished)
	EventBus.action_drawer_closed.emit()


# ── Signal wiring ─────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	EventBus.actions_registered.connect(_on_actions_registered)
	EventBus.store_exited.connect(_on_store_exited)
	EventBus.action_requested.connect(_on_action_requested)
	EventBus.haggle_negotiation_started.connect(_on_haggle_negotiation_started)
	EventBus.haggle_customer_countered.connect(_on_haggle_customer_countered)
	EventBus.haggle_completed.connect(_on_haggle_completed)
	EventBus.haggle_failed.connect(_on_haggle_failed)
	EventBus.warranty_offer_presented.connect(_on_warranty_offer_presented)
	EventBus.authentication_dialog_requested.connect(_on_auth_dialog_requested)
	EventBus.refurbishment_completed.connect(_on_refurbishment_completed)


# ── EventBus handlers ─────────────────────────────────────────────────────────

func _on_actions_registered(store_id: StringName, actions: Array) -> void:
	_current_store_id = store_id
	_rebuild(actions)


func _on_store_exited(_store_id: StringName) -> void:
	_current_store_id = &""
	close_mode()
	_rebuild([])


func _on_action_requested(action_id: StringName, store_id: StringName) -> void:
	if store_id != _current_store_id:
		return
	var mode: int = ACTION_MODE_MAP.get(action_id, -1)
	if mode >= 0:
		open_mode(mode as Mode)


func _on_haggle_negotiation_started(
	_item_name: String, _condition: String,
	sticker_price: float, customer_offer: float,
	max_rounds: int, _time_per_turn: float
) -> void:
	_haggle_sticker_price = sticker_price
	_haggle_customer_offer = customer_offer
	_haggle_max_rounds = max_rounds
	_haggle_round = 1
	_refresh_haggle_pane()
	open_mode(Mode.HAGGLE)


func _on_haggle_customer_countered(
	new_offer: float, round_number: int, max_rounds: int
) -> void:
	_haggle_customer_offer = new_offer
	_haggle_round = round_number
	_haggle_max_rounds = max_rounds
	_refresh_haggle_pane()


func _on_haggle_completed(
	_store_id: StringName, _item_id: StringName, _final_price: float,
	_asking: float, _accepted: bool, _rounds: int
) -> void:
	close_mode()


func _on_haggle_failed(_item_id: String, _customer_id: int) -> void:
	close_mode()


func _on_warranty_offer_presented(item_id: String) -> void:
	_warranty_item_id = item_id
	_refresh_warranty_pane()
	open_mode(Mode.WARRANTY)


func _on_auth_dialog_requested(item_id: Variant) -> void:
	_auth_item_id = String(item_id)
	_refresh_auth_pane()
	open_mode(Mode.AUTHENTICATE)


func _on_refurbishment_completed(
	_item_id: String, _success: bool, _condition: String
) -> void:
	close_mode()


# ── Chrome button bar ─────────────────────────────────────────────────────────

func _rebuild(actions: Array) -> void:
	_action_ids.clear()
	if _button_container == null:
		return
	for child: Node in _button_container.get_children():
		_button_container.remove_child(child)
		child.queue_free()
	for entry: Variant in actions:
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("ActionDrawer: non-dict action descriptor skipped")
			continue
		var descriptor: Dictionary = entry
		if not descriptor.has(ACTION_ID_KEY):
			push_warning("ActionDrawer: action descriptor missing 'id'")
			continue
		var action_id: StringName = StringName(descriptor[ACTION_ID_KEY])
		var label: String = String(
			descriptor.get(ACTION_LABEL_KEY, String(action_id))
		)
		var icon_path: String = String(descriptor.get(ACTION_ICON_KEY, ""))
		var button := Button.new()
		button.text = label
		button.name = "Action_%s" % String(action_id)
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var tex: Resource = load(icon_path)
			if tex is Texture2D:
				button.icon = tex
		button.pressed.connect(_on_action_pressed.bind(action_id))
		_button_container.add_child(button)
		_action_ids.append(action_id)


func _on_action_pressed(action_id: StringName) -> void:
	EventBus.action_requested.emit(action_id, _current_store_id)


# ── Mode pane construction ────────────────────────────────────────────────────

func _build_mode_panes() -> void:
	_panes[Mode.HAGGLE] = _build_haggle_pane()
	_panes[Mode.REFURB] = _build_refurb_pane()
	_panes[Mode.AUTHENTICATE] = _build_auth_pane()
	_panes[Mode.WARRANTY] = _build_warranty_pane()
	_panes[Mode.TRADE] = _build_trade_pane()
	for pane: Control in _panes.values():
		pane.hide()


func _show_pane(mode: Mode) -> void:
	for m: int in _panes:
		(_panes[m] as Control).visible = (m == mode)


func _build_haggle_pane() -> VBoxContainer:
	var pane := VBoxContainer.new()
	pane.name = "HagglePane"
	_content.add_child(pane)

	var title := Label.new()
	title.text = "NEGOTIATE"
	title.add_theme_font_size_override("font_size", 14)
	pane.add_child(title)

	_haggle_offer_label = Label.new()
	_haggle_offer_label.name = "OfferLabel"
	_haggle_offer_label.text = "Customer offers: $0.00"
	pane.add_child(_haggle_offer_label)

	_haggle_round_label = Label.new()
	_haggle_round_label.name = "RoundLabel"
	_haggle_round_label.text = "Round 1 / 3"
	pane.add_child(_haggle_round_label)

	_haggle_counter_input = SpinBox.new()
	_haggle_counter_input.name = "CounterInput"
	_haggle_counter_input.step = 0.25
	_haggle_counter_input.min_value = 0.01
	_haggle_counter_input.max_value = 9999.0
	_haggle_counter_input.value = 0.0
	pane.add_child(_haggle_counter_input)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	pane.add_child(btns)

	var accept_btn := Button.new()
	accept_btn.name = "AcceptBtn"
	accept_btn.text = "Accept Offer"
	accept_btn.pressed.connect(_on_haggle_accept)
	btns.add_child(accept_btn)

	var counter_btn := Button.new()
	counter_btn.name = "CounterBtn"
	counter_btn.text = "Counter"
	counter_btn.pressed.connect(_on_haggle_counter)
	btns.add_child(counter_btn)

	var decline_btn := Button.new()
	decline_btn.name = "DeclineBtn"
	decline_btn.text = "Decline"
	decline_btn.pressed.connect(_on_haggle_decline)
	btns.add_child(decline_btn)

	return pane


func _build_refurb_pane() -> VBoxContainer:
	var pane := VBoxContainer.new()
	pane.name = "RefurbPane"
	_content.add_child(pane)

	var title := Label.new()
	title.text = "REFURBISH"
	title.add_theme_font_size_override("font_size", 14)
	pane.add_child(title)

	_refurb_status_label = Label.new()
	_refurb_status_label.name = "StatusLabel"
	_refurb_status_label.text = "Queue item for refurbishment"
	pane.add_child(_refurb_status_label)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	pane.add_child(btns)

	var start_btn := Button.new()
	start_btn.name = "StartBtn"
	start_btn.text = "Start Refurb"
	start_btn.pressed.connect(_on_refurb_start)
	btns.add_child(start_btn)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelBtn"
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(close_mode)
	btns.add_child(cancel_btn)

	return pane


func _build_auth_pane() -> VBoxContainer:
	var pane := VBoxContainer.new()
	pane.name = "AuthPane"
	_content.add_child(pane)

	var title := Label.new()
	title.text = "AUTHENTICATE"
	title.add_theme_font_size_override("font_size", 14)
	pane.add_child(title)

	_auth_item_label = Label.new()
	_auth_item_label.name = "ItemLabel"
	_auth_item_label.text = "Select item to authenticate"
	pane.add_child(_auth_item_label)

	var tiers_row := HBoxContainer.new()
	tiers_row.add_theme_constant_override("separation", 8)
	pane.add_child(tiers_row)

	var tier_data: Array = [
		[0, "Economy ($5)"],
		[1, "Express ($15)"],
		[2, "Premium ($35)"],
	]
	for td: Array in tier_data:
		var tier_int: int = td[0]
		var tier_label: String = td[1]
		var btn := Button.new()
		btn.name = "TierBtn%d" % tier_int
		btn.text = tier_label
		btn.pressed.connect(_on_auth_tier_selected.bind(tier_int))
		tiers_row.add_child(btn)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelBtn"
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(close_mode)
	pane.add_child(cancel_btn)

	return pane


func _build_warranty_pane() -> VBoxContainer:
	var pane := VBoxContainer.new()
	pane.name = "WarrantyPane"
	_content.add_child(pane)

	var title := Label.new()
	title.text = "WARRANTY OFFER"
	title.add_theme_font_size_override("font_size", 14)
	pane.add_child(title)

	_warranty_offer_label = Label.new()
	_warranty_offer_label.name = "OfferLabel"
	_warranty_offer_label.text = "Offer warranty to customer?"
	pane.add_child(_warranty_offer_label)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	pane.add_child(btns)

	var accept_btn := Button.new()
	accept_btn.name = "AcceptBtn"
	accept_btn.text = "Offer Warranty"
	accept_btn.pressed.connect(_on_warranty_accept)
	btns.add_child(accept_btn)

	var decline_btn := Button.new()
	decline_btn.name = "DeclineBtn"
	decline_btn.text = "No Thanks"
	decline_btn.pressed.connect(_on_warranty_decline)
	btns.add_child(decline_btn)

	return pane


func _build_trade_pane() -> VBoxContainer:
	var pane := VBoxContainer.new()
	pane.name = "TradePane"
	_content.add_child(pane)

	var title := Label.new()
	title.text = "TRADE OFFER"
	title.add_theme_font_size_override("font_size", 14)
	pane.add_child(title)

	_trade_offer_label = Label.new()
	_trade_offer_label.name = "OfferLabel"
	_trade_offer_label.text = "Review trade offer"
	pane.add_child(_trade_offer_label)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	pane.add_child(btns)

	var accept_btn := Button.new()
	accept_btn.name = "AcceptBtn"
	accept_btn.text = "Accept Trade"
	accept_btn.pressed.connect(_on_trade_accept)
	btns.add_child(accept_btn)

	var decline_btn := Button.new()
	decline_btn.name = "DeclineBtn"
	decline_btn.text = "Decline"
	decline_btn.pressed.connect(_on_trade_decline)
	btns.add_child(decline_btn)

	return pane


# ── Pane data refresh ─────────────────────────────────────────────────────────

func _refresh_haggle_pane() -> void:
	if _haggle_offer_label:
		_haggle_offer_label.text = (
			"Customer offers: $%.2f  (asking $%.2f)" % [
				_haggle_customer_offer, _haggle_sticker_price
			]
		)
	if _haggle_round_label:
		_haggle_round_label.text = (
			"Round %d / %d" % [_haggle_round, _haggle_max_rounds]
		)
	if _haggle_counter_input:
		var max_val: float = maxf(_haggle_sticker_price * 1.5, 0.25)
		_haggle_counter_input.max_value = max_val
		_haggle_counter_input.value = snappedf(
			clampf(_haggle_sticker_price, 0.01, max_val), 0.25
		)


func _refresh_warranty_pane() -> void:
	if _warranty_offer_label:
		_warranty_offer_label.text = (
			"Offer extended warranty for item: %s?" % _warranty_item_id
		)


func _refresh_auth_pane() -> void:
	if _auth_item_label:
		_auth_item_label.text = (
			"Authenticate: %s" % _auth_item_id
		)


# ── Player action handlers ────────────────────────────────────────────────────

func _on_haggle_accept() -> void:
	EventBus.haggle_player_accepted.emit()
	close_mode()


func _on_haggle_counter() -> void:
	var price: float = (
		_haggle_counter_input.value if _haggle_counter_input else _haggle_sticker_price
	)
	EventBus.haggle_player_countered.emit(price)


func _on_haggle_decline() -> void:
	EventBus.haggle_player_declined.emit()
	close_mode()


func _on_refurb_start() -> void:
	EventBus.refurb_player_queued.emit(_current_store_id)
	close_mode()


func _on_auth_tier_selected(tier: int) -> void:
	EventBus.authentication_player_submitted.emit(_auth_item_id, tier)
	close_mode()


func _on_warranty_accept() -> void:
	EventBus.warranty_player_accepted.emit(_warranty_item_id, _warranty_tier_id)
	close_mode()


func _on_warranty_decline() -> void:
	EventBus.warranty_player_declined.emit(_warranty_item_id)
	close_mode()


func _on_trade_accept() -> void:
	EventBus.trade_player_accepted.emit()
	close_mode()


func _on_trade_decline() -> void:
	EventBus.trade_player_declined.emit()
	close_mode()


# ── Internal helpers ──────────────────────────────────────────────────────────

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _on_close_finished() -> void:
	_content.hide()
	_separator.hide()
