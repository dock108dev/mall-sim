## Dialog for leasing an available storefront with store type selection.
class_name StoreLeaseDialog
extends PanelContainer

const UNLOCK_REQUIREMENTS: Array[Dictionary] = [
	{},
	{"reputation": 25, "cost": 500},
	{"reputation": 50, "cost": 1000},
	{"reputation": 75, "cost": 2000},
	{"reputation": 90, "cost": 5000},
]

var _current_slot_index: int = -1
var _selected_store_type: String = ""
var _current_cash: float = 0.0
var _current_reputation: float = 0.0
var _owned_stores: Array[String] = []
var _store_buttons: Dictionary = {}

@onready var _title_label: Label = $Margin/VBox/TitleLabel
@onready var _req_label: Label = $Margin/VBox/ReqLabel
@onready var _store_list: VBoxContainer = (
	$Margin/VBox/StoreScroll/StoreList
)
@onready var _desc_label: Label = $Margin/VBox/DescLabel
@onready var _confirm_button: Button = (
	$Margin/VBox/ButtonRow/ConfirmButton
)
@onready var _cancel_button: Button = (
	$Margin/VBox/ButtonRow/CancelButton
)


func _ready() -> void:
	visible = false
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)


## Shows the dialog for a specific storefront slot with full context.
func show_for_slot(
	slot_index: int,
	store_defs: Array[StoreDefinition],
	owned_stores: Array[String],
	current_cash: float,
	current_reputation: float
) -> void:
	_current_slot_index = slot_index
	_current_cash = current_cash
	_current_reputation = current_reputation
	_owned_stores = owned_stores
	_selected_store_type = ""

	_title_label.text = "Lease Storefront #%d" % (slot_index + 1)
	_update_requirements_label()
	_populate_store_list(store_defs)
	_desc_label.text = "Select a store type to view details."
	_update_confirm_button()

	visible = true
	EventBus.panel_opened.emit("store_lease_dialog")


## Hides the dialog and resets state.
func close_dialog() -> void:
	visible = false
	_current_slot_index = -1
	_selected_store_type = ""
	EventBus.panel_closed.emit("store_lease_dialog")


## Returns the lease cost for the next store unlock.
func get_unlock_cost() -> float:
	var index: int = _owned_stores.size()
	if index <= 0 or index >= UNLOCK_REQUIREMENTS.size():
		return 0.0
	return float(UNLOCK_REQUIREMENTS[index].get("cost", 0))


## Returns the reputation required for the next store unlock.
func get_unlock_reputation() -> float:
	var index: int = _owned_stores.size()
	if index <= 0 or index >= UNLOCK_REQUIREMENTS.size():
		return 0.0
	return float(UNLOCK_REQUIREMENTS[index].get("reputation", 0))


func _can_afford() -> bool:
	return _current_cash >= get_unlock_cost()


func _has_reputation() -> bool:
	return _current_reputation >= get_unlock_reputation()


func _update_requirements_label() -> void:
	var store_num: int = _owned_stores.size() + 1
	var index: int = _owned_stores.size()
	if index <= 0 or index >= UNLOCK_REQUIREMENTS.size():
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
		+ "[%s] Lease Fee: $%d / $%d"
		% [cost_ok, int(_current_cash), int(req_cost)]
	)


func _populate_store_list(
	store_defs: Array[StoreDefinition]
) -> void:
	for child: Node in _store_list.get_children():
		child.queue_free()
	_store_buttons = {}

	for store_def: StoreDefinition in store_defs:
		var btn := Button.new()
		btn.name = "Btn_%s" % store_def.id
		btn.custom_minimum_size = Vector2(0, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var is_owned: bool = store_def.id in _owned_stores
		if is_owned:
			btn.text = "%s - $%d/day [OWNED]" % [
				store_def.name, int(store_def.daily_rent)
			]
			btn.disabled = true
		else:
			btn.text = "%s - $%d/day" % [
				store_def.name, int(store_def.daily_rent)
			]
			btn.pressed.connect(
				_on_store_selected.bind(store_def)
			)

		_store_list.add_child(btn)
		_store_buttons[store_def.id] = btn


func _on_store_selected(
	store_def: StoreDefinition
) -> void:
	_selected_store_type = store_def.id
	_desc_label.text = "%s\nSize: %s | Shelves: %d | Backroom: %d" % [
		store_def.description,
		store_def.size_category,
		store_def.shelf_capacity,
		store_def.backroom_capacity,
	]
	_highlight_selected()
	_update_confirm_button()


func _highlight_selected() -> void:
	for store_id: String in _store_buttons:
		var btn: Button = _store_buttons[store_id] as Button
		if btn.disabled:
			continue
		btn.button_pressed = (store_id == _selected_store_type)


func _update_confirm_button() -> void:
	var can_unlock: bool = (
		not _selected_store_type.is_empty()
		and _can_afford()
		and _has_reputation()
	)
	_confirm_button.disabled = not can_unlock


func _on_confirm_pressed() -> void:
	if _current_slot_index < 0:
		return
	if _selected_store_type.is_empty():
		return
	if not _can_afford() or not _has_reputation():
		return
	EventBus.store_leased.emit(
		_current_slot_index, _selected_store_type
	)
	close_dialog()


func _on_cancel_pressed() -> void:
	close_dialog()
