## Multi-step dialog for leasing a storefront: type selection, naming, confirmation.
class_name StoreLeaseDialog
extends Control

enum Step { TYPE_SELECTION, NAMING, CONFIRMATION }

const UNLOCK_REQUIREMENTS: Array[Dictionary] = (
	StoreStateManager.LEASE_UNLOCK_REQUIREMENTS
)
const MAX_STORE_NAME_LENGTH: int = 24
const STARTER_ITEM_COUNT_MIN: int = 6
const STARTER_ITEM_COUNT_MAX: int = 10

var _current_slot_index: int = -1
var _selected_store_type: String = ""
var _store_name: String = ""
var _current_cash: float = 0.0
var _current_reputation: float = 0.0
var _owned_stores: Array[StringName] = []
var _store_buttons: Dictionary = {}
var _is_pending: bool = false
var _current_step: Step = Step.TYPE_SELECTION
var _selected_store_def: StoreDefinition

@onready var _overlay: ColorRect = $Overlay
@onready var _dialog_panel: PanelContainer = $DialogPanel
@onready var _title_label: Label = $DialogPanel/Margin/VBox/TitleLabel
@onready var _type_page: VBoxContainer = $DialogPanel/Margin/VBox/TypeSelectionPage
@onready var _req_label: Label = (
	$DialogPanel/Margin/VBox/TypeSelectionPage/ReqLabel
)
@onready var _store_list: VBoxContainer = (
	$DialogPanel/Margin/VBox/TypeSelectionPage/StoreScroll/StoreList
)
@onready var _desc_label: Label = (
	$DialogPanel/Margin/VBox/TypeSelectionPage/DescLabel
)
@onready var _naming_page: VBoxContainer = $DialogPanel/Margin/VBox/NamingPage
@onready var _name_input: LineEdit = (
	$DialogPanel/Margin/VBox/NamingPage/NameInput
)
@onready var _char_count_label: Label = (
	$DialogPanel/Margin/VBox/NamingPage/CharCountLabel
)
@onready var _confirm_page: VBoxContainer = (
	$DialogPanel/Margin/VBox/ConfirmationPage
)
@onready var _summary_label: Label = (
	$DialogPanel/Margin/VBox/ConfirmationPage/SummaryLabel
)
@onready var _error_label: Label = $DialogPanel/Margin/VBox/ErrorLabel
@onready var _pending_spinner: ProgressBar = (
	$DialogPanel/Margin/VBox/PendingRow/PendingSpinner
)
@onready var _status_label: Label = $DialogPanel/Margin/VBox/PendingRow/StatusLabel
@onready var _back_button: Button = (
	$DialogPanel/Margin/VBox/ButtonRow/BackButton
)
@onready var _confirm_button: Button = (
	$DialogPanel/Margin/VBox/ButtonRow/ConfirmButton
)
@onready var _cancel_button: Button = (
	$DialogPanel/Margin/VBox/ButtonRow/CancelButton
)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_name_input.text_changed.connect(_on_name_text_changed)
	EventBus.lease_completed.connect(_on_lease_completed)


## Shows the dialog for a specific storefront slot with full context.
func show_for_slot(
	slot_index: int,
	store_defs: Array[StoreDefinition],
	owned_stores: Array[StringName],
	current_cash: float,
	current_reputation: float
) -> void:
	_current_slot_index = slot_index
	_current_cash = current_cash
	_current_reputation = current_reputation
	_owned_stores = owned_stores
	var canonical_owned: Array[StringName] = []
	for owned_id: StringName in _owned_stores:
		var canonical: StringName = ContentRegistry.resolve(String(owned_id))
		if canonical.is_empty():
			canonical_owned.append(owned_id)
		else:
			canonical_owned.append(canonical)
	_owned_stores = canonical_owned
	_selected_store_type = ""
	_store_name = ""
	_selected_store_def = null
	_is_pending = false

	_populate_store_list(store_defs)
	_error_label.text = ""
	_set_pending(false)
	_go_to_step(Step.TYPE_SELECTION)

	visible = true
	EventBus.panel_opened.emit("store_lease_dialog")


## Hides the dialog and resets state.
func close_dialog() -> void:
	if _is_pending:
		return
	visible = false
	_current_slot_index = -1
	_selected_store_type = ""
	_store_name = ""
	_selected_store_def = null
	_is_pending = false
	EventBus.panel_closed.emit("store_lease_dialog")


## Returns the lease cost for the next store unlock.
func get_unlock_cost() -> float:
	return StoreStateManager.get_setup_fee_for_slot_index(
		_current_slot_index
	)


## Returns the reputation required for the next store unlock.
func get_unlock_reputation() -> float:
	return StoreStateManager.get_reputation_requirement_for_slot_index(
		_current_slot_index
	)


func _can_afford() -> bool:
	return _current_cash >= get_unlock_cost()


func _has_reputation() -> bool:
	return _current_reputation >= get_unlock_reputation()


func _go_to_step(step: Step) -> void:
	_current_step = step
	_type_page.visible = (step == Step.TYPE_SELECTION)
	_naming_page.visible = (step == Step.NAMING)
	_confirm_page.visible = (step == Step.CONFIRMATION)
	_back_button.visible = (step != Step.TYPE_SELECTION)
	_error_label.text = ""

	match step:
		Step.TYPE_SELECTION:
			_title_label.text = (
				"Lease Storefront #%d" % (_current_slot_index + 1)
			)
			_confirm_button.text = "Next"
			_update_requirements_label()
		Step.NAMING:
			_title_label.text = "Name Your Store"
			_confirm_button.text = "Next"
			var default_name: String = _generate_default_name()
			_name_input.text = default_name
			_store_name = default_name
			_name_input.max_length = MAX_STORE_NAME_LENGTH
			_update_char_count()
		Step.CONFIRMATION:
			_title_label.text = "Confirm Lease"
			_confirm_button.text = "Confirm"
			_update_summary()

	_update_confirm_button()


func _generate_default_name() -> String:
	if _selected_store_def:
		return "My %s" % _selected_store_def.store_name
	return "My Store"


func _update_requirements_label() -> void:
	var store_num: int = _current_slot_index + 1
	if (
		_current_slot_index < 0
		or _current_slot_index >= UNLOCK_REQUIREMENTS.size()
	):
		_req_label.text = "No additional stores available."
		return

	var req_rep: float = get_unlock_reputation()
	var req_cost: float = get_unlock_cost()
	var rep_ok: String = "+" if _has_reputation() else "-"
	var cost_ok: String = "+" if _can_afford() else "-"

	_req_label.text = (
		"Store #%d Requirements:\n" % store_num
		+ "[%s] Reputation: %.0f / %.0f\n"
		% [rep_ok, _current_reputation, req_rep]
		+ "[%s] Setup Fee: $%d / $%d"
		% [cost_ok, int(_current_cash), int(req_cost)]
	)


func _update_char_count() -> void:
	var current_len: int = _name_input.text.length()
	_char_count_label.text = "%d / %d" % [
		current_len, MAX_STORE_NAME_LENGTH
	]


func _update_summary() -> void:
	var fee: float = get_unlock_cost()
	var cash_after: float = _current_cash - fee
	var type_name: String = ""
	if _selected_store_def:
		type_name = _selected_store_def.store_name
	else:
		type_name = _selected_store_type

	_summary_label.text = (
		"Store Type: %s\n" % type_name
		+ "Store Name: %s\n" % _store_name
		+ "Daily Rent: $%d/day\n" % int(
			_selected_store_def.daily_rent if _selected_store_def
			else 0
		)
		+ "\nSetup Fee: $%d\n" % int(fee)
		+ "Cash After Fee: $%d\n" % int(cash_after)
		+ "\nStarter Inventory: %d-%d common items" % [
			STARTER_ITEM_COUNT_MIN, STARTER_ITEM_COUNT_MAX
		]
		+ "\nStore opens next morning."
	)


func _populate_store_list(
	store_defs: Array[StoreDefinition]
) -> void:
	for child: Node in _store_list.get_children():
		child.queue_free()
	_store_buttons = {}

	for store_def: StoreDefinition in store_defs:
		var resolved_id: StringName = ContentRegistry.resolve(
			store_def.id
		)
		var btn := Button.new()
		btn.name = "Btn_%s" % resolved_id
		btn.custom_minimum_size = Vector2(0, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var is_owned: bool = resolved_id in _owned_stores
		if is_owned:
			btn.text = "%s - $%d/day [OWNED]" % [
				store_def.store_name, int(store_def.daily_rent)
			]
			btn.disabled = true
		else:
			btn.text = "%s - $%d/day" % [
				store_def.store_name, int(store_def.daily_rent)
			]
			btn.pressed.connect(
				_on_store_selected.bind(store_def)
			)

		_store_list.add_child(btn)
		_store_buttons[String(resolved_id)] = btn


func _on_store_selected(
	store_def: StoreDefinition
) -> void:
	if _is_pending:
		return
	var canonical: StringName = ContentRegistry.resolve(store_def.id)
	_selected_store_type = (
		String(canonical) if not canonical.is_empty()
		else store_def.id
	)
	_selected_store_def = store_def
	_desc_label.text = "%s\nSize: %s | Shelves: %d | Backroom: %d" % [
		store_def.description,
		store_def.size_category,
		store_def.shelf_capacity,
		store_def.backroom_capacity,
	]
	_error_label.text = ""
	_highlight_selected()
	_update_confirm_button()


func _highlight_selected() -> void:
	for store_id: String in _store_buttons:
		var btn: Button = _store_buttons[store_id] as Button
		if btn.disabled:
			continue
		btn.button_pressed = (store_id == _selected_store_type)


func _update_confirm_button() -> void:
	if _is_pending:
		_confirm_button.disabled = true
		return

	match _current_step:
		Step.TYPE_SELECTION:
			var can_proceed: bool = (
				not _selected_store_type.is_empty()
				and _can_afford()
				and _has_reputation()
			)
			_confirm_button.disabled = not can_proceed
		Step.NAMING:
			var name_text: String = _name_input.text.strip_edges()
			_confirm_button.disabled = name_text.is_empty()
		Step.CONFIRMATION:
			_confirm_button.disabled = false


func _set_pending(pending: bool) -> void:
	_is_pending = pending
	_confirm_button.disabled = pending
	_cancel_button.disabled = pending
	_back_button.disabled = pending
	_pending_spinner.visible = pending
	if pending:
		_status_label.text = "Processing lease..."
		_error_label.text = ""
	else:
		_status_label.text = ""


func _on_name_text_changed(_new_text: String) -> void:
	_update_char_count()
	_update_confirm_button()


func _on_back_pressed() -> void:
	if _is_pending:
		return
	match _current_step:
		Step.NAMING:
			_go_to_step(Step.TYPE_SELECTION)
		Step.CONFIRMATION:
			_go_to_step(Step.NAMING)


func _on_confirm_pressed() -> void:
	if _is_pending:
		return
	if _current_slot_index < 0:
		return

	match _current_step:
		Step.TYPE_SELECTION:
			if _selected_store_type.is_empty():
				return
			if not _can_afford() or not _has_reputation():
				return
			_go_to_step(Step.NAMING)
		Step.NAMING:
			var name_text: String = _name_input.text.strip_edges()
			if name_text.is_empty():
				_error_label.text = "Please enter a store name."
				return
			_store_name = name_text
			_go_to_step(Step.CONFIRMATION)
		Step.CONFIRMATION:
			_submit_lease()


func _submit_lease() -> void:
	_set_pending(true)
	var canonical: StringName = ContentRegistry.resolve(
		_selected_store_type
	)
	if canonical.is_empty():
		canonical = StringName(_selected_store_type)
	EventBus.lease_requested.emit(
		canonical, _current_slot_index, _store_name
	)


func _on_lease_completed(
	store_id: StringName,
	success: bool,
	message: String
) -> void:
	if not _is_pending:
		return
	var requested_id: StringName = ContentRegistry.resolve(
		_selected_store_type
	)
	if requested_id.is_empty():
		requested_id = StringName(_selected_store_type)
	if store_id != requested_id:
		return

	_set_pending(false)
	if success:
		close_dialog()
	else:
		_error_label.text = message
		_update_confirm_button()


func _on_cancel_pressed() -> void:
	if _is_pending:
		return
	close_dialog()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _is_pending:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		close_dialog()
		get_viewport().set_input_as_handled()
