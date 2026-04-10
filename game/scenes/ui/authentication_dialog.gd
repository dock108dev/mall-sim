## Modal dialog for confirming autograph authentication.
class_name AuthenticationDialog
extends CanvasLayer

const PANEL_NAME: String = "authentication"

var _authentication_system: AuthenticationSystem = null
var _current_item: ItemInstance = null
var _is_open: bool = false

@onready var _panel: PanelContainer = $PanelRoot
@onready var _title_label: Label = $PanelRoot/Margin/VBox/TitleLabel
@onready var _item_name_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/ItemNameLabel
)
@onready var _cost_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/CostLabel
)
@onready var _duration_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/DurationLabel
)
@onready var _chance_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/ChanceLabel
)
@onready var _genuine_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/GenuineLabel
)
@onready var _fake_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/FakeLabel
)
@onready var _confirm_button: Button = (
	$PanelRoot/Margin/VBox/ButtonHBox/ConfirmButton
)
@onready var _cancel_button: Button = (
	$PanelRoot/Margin/VBox/ButtonHBox/CancelButton
)


func _ready() -> void:
	_panel.visible = false
	_confirm_button.pressed.connect(_on_confirm)
	_cancel_button.pressed.connect(close)


## Sets the AuthenticationSystem reference.
func set_authentication_system(
	system: AuthenticationSystem
) -> void:
	_authentication_system = system


## Opens the dialog for the given autograph item.
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
	_populate(item)
	_is_open = true
	_panel.visible = true
	EventBus.panel_opened.emit(PANEL_NAME)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_current_item = null
	_panel.visible = false
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func _populate(item: ItemInstance) -> void:
	_title_label.text = "Authenticate Autograph"
	_item_name_label.text = item.definition.name
	var cost: float = _authentication_system.get_cost(item)
	_cost_label.text = "Authentication Cost: $%.2f" % cost
	_duration_label.text = "Duration: 1 day"
	var chance: int = int(
		AuthenticationSystem.GENUINE_CHANCE * 100.0
	)
	_chance_label.text = "Genuine Chance: %d%%" % chance
	_genuine_label.text = (
		"If genuine: value doubles (2x multiplier)"
	)
	_fake_label.text = (
		"If fake: item becomes near worthless ($0.50)"
	)
	_confirm_button.text = "Authenticate ($%.2f)" % cost


func _on_confirm() -> void:
	if not _current_item or not _authentication_system:
		return
	var success: bool = _authentication_system.start_authentication(
		_current_item.instance_id
	)
	if not success:
		return
	close()
