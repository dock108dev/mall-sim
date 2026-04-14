## Modal dialog for confirming item authentication before high-value listing.
class_name AuthenticationDialog
extends CanvasLayer

const PANEL_NAME: String = "authentication"

var _authentication_system: AuthenticationSystem = null
var _inventory_system: InventorySystem = null
var _current_item: ItemInstance = null
var _is_open: bool = false
var _is_pending: bool = false
var _anim_tween: Tween

@onready var _panel: PanelContainer = $PanelRoot
@onready var _title_label: Label = $PanelRoot/Margin/VBox/TitleLabel
@onready var _item_name_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/ItemNameLabel
)
@onready var _condition_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/ConditionLabel
)
@onready var _cost_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/CostLabel
)
@onready var _error_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/ErrorLabel
)
@onready var _confirm_button: Button = (
	$PanelRoot/Margin/VBox/ButtonHBox/ConfirmButton
)
@onready var _cancel_button: Button = (
	$PanelRoot/Margin/VBox/ButtonHBox/CancelButton
)


func _ready() -> void:
	_panel.visible = false
	_error_label.visible = false
	_confirm_button.pressed.connect(_on_confirm)
	_cancel_button.pressed.connect(_on_cancel)
	EventBus.authentication_completed.connect(
		_on_authentication_completed
	)
	EventBus.authentication_dialog_requested.connect(
		_on_dialog_requested
	)


## Sets the AuthenticationSystem reference.
func set_authentication_system(
	system: AuthenticationSystem
) -> void:
	_authentication_system = system


## Sets the InventorySystem reference for item lookups.
func set_inventory_system(inventory: InventorySystem) -> void:
	_inventory_system = inventory


## Opens the dialog for the given item.
func open(item: ItemInstance) -> void:
	if _is_open:
		return
	if not _authentication_system:
		push_warning(
			"AuthenticationDialog: no AuthenticationSystem set"
		)
		return
	if not _authentication_system.can_authenticate(item):
		EventBus.notification_requested.emit(
			"This item cannot be authenticated"
		)
		return
	_current_item = item
	_is_pending = false
	_error_label.visible = false
	_populate(item)
	_set_inputs_enabled(true)
	_is_open = true
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_open(_panel)
	EventBus.panel_opened.emit(PANEL_NAME)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_is_pending = false
	_current_item = null
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_close(_panel)
	_anim_tween.finished.connect(
		func() -> void: EventBus.panel_closed.emit(PANEL_NAME),
		CONNECT_ONE_SHOT,
	)


func is_open() -> bool:
	return _is_open


func _populate(item: ItemInstance) -> void:
	_title_label.text = "Authenticate Item"
	_item_name_label.text = item.definition.item_name
	_condition_label.text = "Condition: %s" % item.condition.capitalize()
	var fee: float = _authentication_system.get_auth_fee()
	_cost_label.text = "Authentication Fee: $%.2f" % fee
	_confirm_button.text = "Authenticate ($%.2f)" % fee


func _on_confirm() -> void:
	if not _current_item or not _authentication_system:
		return
	if _is_pending:
		return
	_is_pending = true
	_error_label.visible = false
	_set_inputs_enabled(false)
	_authentication_system.authenticate(_current_item.instance_id)


func _on_cancel() -> void:
	if _is_pending:
		return
	close()


func _on_authentication_completed(
	item_id: String, success: bool, message: String
) -> void:
	if not _is_open or not _current_item:
		return
	if item_id != _current_item.instance_id:
		return
	_is_pending = false
	if success:
		close()
	else:
		_error_label.text = message
		_error_label.visible = true
		_set_inputs_enabled(true)


func _set_inputs_enabled(enabled: bool) -> void:
	_confirm_button.disabled = not enabled
	_cancel_button.disabled = not enabled


func _on_dialog_requested(item_id: String) -> void:
	if not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(item_id)
	if not item:
		return
	open(item)
