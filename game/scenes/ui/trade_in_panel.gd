## Right-dock slide-in panel for the trade-in intake flow.
##
## Thin view layer for `TradeInSystem`. Owns the scene tree, condition
## CheckBox widgets, and the receipt auto-dismiss Timer. All state transitions
## live on the system; the panel observes `state_changed` and renders the
## visibility / enable matrix from §4 of the trade-in design research.
##
## Cancellation contract: Escape-key, leaving interaction range, or pressing
## the Decline button while AWAITING_PLAYER_DECISION all close the panel
## silently — no confirmation dialog. The customer NPC is signaled to play
## its waiting idle while AWAITING_PLAYER_DECISION (state-changed listeners
## downstream handle the animation; the panel only emits the canonical
## EventBus signals).
class_name TradeInPanel
extends CanvasLayer

const PANEL_NAME: String = "trade_in"
const RECEIPT_DISPLAY_DURATION: float = 3.0

const _CONDITION_BUTTON_PATHS: Dictionary = {
	"mint": "PanelRoot/Margin/VBox/ConditionSection/ConditionOptions/MintButton",
	"good": "PanelRoot/Margin/VBox/ConditionSection/ConditionOptions/GoodButton",
	"fair": "PanelRoot/Margin/VBox/ConditionSection/ConditionOptions/FairButton",
	"poor": "PanelRoot/Margin/VBox/ConditionSection/ConditionOptions/PoorButton",
	"damaged": (
		"PanelRoot/Margin/VBox/ConditionSection/ConditionOptions/DamagedButton"
	),
}

var system: TradeInSystem = null

var _condition_buttons: Dictionary = {}
var _receipt_timer: Timer = null
var _is_open: bool = false

@onready var _panel: PanelContainer = $PanelRoot
@onready var _locked_banner: Label = $PanelRoot/Margin/VBox/LockedBanner
@onready var _inspect_section: VBoxContainer = (
	$PanelRoot/Margin/VBox/InspectSection
)
@onready var _item_name_label: Label = (
	$PanelRoot/Margin/VBox/InspectSection/ItemNameLabel
)
@onready var _platform_label: Label = (
	$PanelRoot/Margin/VBox/InspectSection/PlatformLabel
)
@onready var _condition_section: VBoxContainer = (
	$PanelRoot/Margin/VBox/ConditionSection
)
@onready var _offer_section: VBoxContainer = (
	$PanelRoot/Margin/VBox/OfferSection
)
@onready var _offer_value_label: Label = (
	$PanelRoot/Margin/VBox/OfferSection/OfferValueLabel
)
@onready var _status_label: Label = $PanelRoot/Margin/VBox/StatusLabel
@onready var _button_row: VBoxContainer = $PanelRoot/Margin/VBox/ButtonRow
@onready var _appraise_button: Button = (
	$PanelRoot/Margin/VBox/ButtonRow/AppraiseButton
)
@onready var _make_offer_button: Button = (
	$PanelRoot/Margin/VBox/ButtonRow/MakeOfferButton
)
@onready var _decline_button: Button = (
	$PanelRoot/Margin/VBox/ButtonRow/DeclineButton
)
@onready var _receipt_section: VBoxContainer = (
	$PanelRoot/Margin/VBox/ReceiptSection
)
@onready var _receipt_item_label: Label = (
	$PanelRoot/Margin/VBox/ReceiptSection/ReceiptItemLabel
)
@onready var _receipt_condition_label: Label = (
	$PanelRoot/Margin/VBox/ReceiptSection/ReceiptConditionLabel
)
@onready var _receipt_credit_label: Label = (
	$PanelRoot/Margin/VBox/ReceiptSection/ReceiptCreditLabel
)


func _ready() -> void:
	_panel.visible = false
	for cond: String in _CONDITION_BUTTON_PATHS:
		var btn: CheckBox = get_node(_CONDITION_BUTTON_PATHS[cond]) as CheckBox
		_condition_buttons[cond] = btn
		btn.toggled.connect(_on_condition_toggled.bind(cond))
	_appraise_button.pressed.connect(_on_appraise_pressed)
	_make_offer_button.pressed.connect(_on_make_offer_pressed)
	_decline_button.pressed.connect(_on_decline_pressed)
	_receipt_timer = Timer.new()
	_receipt_timer.one_shot = true
	_receipt_timer.wait_time = RECEIPT_DISPLAY_DURATION
	_receipt_timer.timeout.connect(_on_receipt_timer_timeout)
	add_child(_receipt_timer)


## Binds the panel to a TradeInSystem instance. Caller is responsible for
## injecting the system's own dependencies (inventory, economy, reputation).
func bind_system(system_ref: TradeInSystem) -> void:
	if system != null and system.state_changed.is_connected(_on_state_changed):
		system.state_changed.disconnect(_on_state_changed)
	system = system_ref
	if system != null:
		system.state_changed.connect(_on_state_changed)
		_render_for_state(system.current_state)


## Opens the panel with a customer + item context. Forwards to the system.
func open_for_customer(
	customer_id: String,
	item_def_id: String,
	definition: ItemDefinition,
) -> void:
	if system == null:
		push_error("TradeInPanel: no TradeInSystem bound")
		return
	if system.is_locked():
		_show_locked_state()
		return
	_clear_condition_selection()
	_status_label.visible = false
	_status_label.text = ""
	system.begin_interaction(customer_id, item_def_id, definition)
	_populate_inspect(definition)
	_panel.visible = true
	_is_open = true
	EventBus.panel_opened.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open or system == null:
		return
	if event.is_action_pressed("ui_cancel"):
		_silent_cancel()
		get_viewport().set_input_as_handled()
		return
	if system.current_state == TradeInSystem.State.RECEIPT_SHOWN:
		# Receipt auto-dismisses on E (interact) or after the 3s timer.
		if event.is_action_pressed("interact"):
			_dismiss_receipt()
			get_viewport().set_input_as_handled()


## Called by the store controller when the player walks out of interaction
## range. Identical resolution path as Escape — silent neutral cancel.
func notify_out_of_range() -> void:
	if not _is_open:
		return
	_silent_cancel()


func _silent_cancel() -> void:
	if system == null:
		return
	system.silent_cancel()


func _populate_inspect(definition: ItemDefinition) -> void:
	if definition == null:
		_item_name_label.text = ""
		_platform_label.text = ""
		return
	_item_name_label.text = definition.item_name
	var platform: String = definition.platform
	if platform.is_empty():
		platform = String(definition.platform_id)
	_platform_label.text = platform


func _show_locked_state() -> void:
	_panel.visible = true
	_locked_banner.visible = true
	_inspect_section.visible = false
	_condition_section.visible = false
	_offer_section.visible = false
	_button_row.visible = false
	_receipt_section.visible = false
	_status_label.visible = false
	_is_open = true


func _on_state_changed(_old_state: int, new_state: int) -> void:
	_render_for_state(new_state)


func _render_for_state(state: int) -> void:
	match state:
		TradeInSystem.State.LOCKED:
			_show_locked_state()
		TradeInSystem.State.IDLE:
			_close_panel()
		TradeInSystem.State.CUSTOMER_APPROACHES, TradeInSystem.State.ITEM_INSPECT:
			_show_section_layout(true, false, false, true, false, false)
			_appraise_button.disabled = true
		TradeInSystem.State.PLATFORM_CONFIRM, TradeInSystem.State.CONDITION_CHECK:
			_show_section_layout(true, true, false, true, false, false)
			_appraise_button.disabled = system == null \
					or system.current_condition.is_empty()
		TradeInSystem.State.VALUE_OFFER:
			_offer_value_label.text = "$%.2f" % system.current_offer
			_show_section_layout(true, true, true, false, true, false)
		TradeInSystem.State.AWAITING_PLAYER_DECISION:
			_offer_value_label.text = "$%.2f" % system.current_offer
			_show_section_layout(true, true, true, false, true, false)
		TradeInSystem.State.ACCEPT_PATH, TradeInSystem.State.REJECT_PATH:
			pass
		TradeInSystem.State.RECEIPT_SHOWN:
			_show_receipt()


func _show_section_layout(
	inspect: bool,
	condition: bool,
	offer: bool,
	appraise_visible: bool,
	make_offer_visible: bool,
	receipt: bool,
) -> void:
	_locked_banner.visible = false
	_inspect_section.visible = inspect
	_condition_section.visible = condition
	_offer_section.visible = offer
	_button_row.visible = true
	_appraise_button.visible = appraise_visible
	_make_offer_button.visible = make_offer_visible
	_decline_button.visible = not receipt
	_receipt_section.visible = receipt


func _show_receipt() -> void:
	if system == null:
		return
	var def: ItemDefinition = system.current_item_definition
	var item_name: String = ""
	if def != null:
		item_name = def.item_name
	_receipt_item_label.text = item_name
	_receipt_condition_label.text = "Condition: %s" % (
		system.current_condition.capitalize()
	)
	_receipt_credit_label.text = "Paid: $%.2f" % system.current_offer
	_show_section_layout(false, false, false, false, false, true)
	_receipt_timer.start()


func _close_panel() -> void:
	if not _is_open:
		return
	_panel.visible = false
	_is_open = false
	_clear_condition_selection()
	_status_label.visible = false
	_offer_value_label.text = "$0.00"
	if _receipt_timer != null:
		_receipt_timer.stop()
	EventBus.panel_closed.emit(PANEL_NAME)


func _dismiss_receipt() -> void:
	if system == null:
		return
	system.complete_receipt()


func _on_receipt_timer_timeout() -> void:
	_dismiss_receipt()


func _on_condition_toggled(pressed: bool, condition: String) -> void:
	if not pressed:
		# Untoggling the active row: clear unless another row is already on.
		if system != null and system.current_condition == condition:
			system.current_condition = ""
			_appraise_button.disabled = true
		return
	# Single-select: untick the others.
	for other: String in _condition_buttons:
		if other == condition:
			continue
		var btn: CheckBox = _condition_buttons[other]
		if btn.button_pressed:
			btn.set_pressed_no_signal(false)
	if system != null:
		system.select_condition(condition)
		_appraise_button.disabled = false


func _clear_condition_selection() -> void:
	for cond: String in _condition_buttons:
		var btn: CheckBox = _condition_buttons[cond]
		btn.set_pressed_no_signal(false)
	if system != null:
		system.current_condition = ""
	_appraise_button.disabled = true


func _on_appraise_pressed() -> void:
	if system == null:
		return
	if system.current_condition.is_empty():
		_status_label.text = "Select a condition first."
		_status_label.visible = true
		return
	_status_label.visible = false
	system.appraise()


func _on_make_offer_pressed() -> void:
	if system == null:
		return
	var instance_id: String = system.make_offer()
	if instance_id.is_empty():
		_status_label.text = "Backroom full — clear space first."
		_status_label.visible = true


func _on_decline_pressed() -> void:
	if system == null:
		return
	# Decline during AWAITING_PLAYER_DECISION is a hard rejection (still emits
	# trade_in_rejected — same as silent cancel from the customer's POV).
	system.decline()
