## Modal dialog for selecting a sports card condition grade before pricing.
class_name ConditionPickerDialog
extends CanvasLayer

const PANEL_NAME: String = "condition_picker"

## Ordered from best to worst for display.
const CONDITIONS: Array[String] = ["mint", "near_mint", "good", "fair", "poor"]
const CONDITION_LABELS: Dictionary = {
	"mint": "Mint",
	"near_mint": "Near Mint",
	"good": "Good",
	"fair": "Fair",
	"poor": "Poor",
}

var _inventory_system: InventorySystem = null
var _current_item: ItemInstance = null
var _is_open: bool = false
var _selected_condition: String = "good"
var _anim_tween: Tween

@onready var _panel: PanelContainer = $PanelRoot
@onready var _title_label: Label = $PanelRoot/Margin/VBox/TitleLabel
@onready var _item_name_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/ItemNameLabel
)
@onready var _condition_option: OptionButton = (
	$PanelRoot/Margin/VBox/InfoVBox/ConditionOption
)
@onready var _preview_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/PreviewLabel
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
	_cancel_button.pressed.connect(_on_cancel)
	_condition_option.item_selected.connect(_on_condition_changed)
	EventBus.condition_picker_requested.connect(_on_picker_requested)
	_populate_option_button()


## Sets the InventorySystem reference for item lookups.
func set_inventory_system(inventory: InventorySystem) -> void:
	_inventory_system = inventory


## Opens the dialog for the given item, defaulting to its current condition.
func open(item: ItemInstance) -> void:
	if _is_open:
		return
	_current_item = item
	_populate(item)
	_is_open = true
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_open(_panel)
	EventBus.panel_opened.emit(PANEL_NAME)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_current_item = null
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.modal_close(_panel)
	_anim_tween.finished.connect(
		func() -> void: EventBus.panel_closed.emit(PANEL_NAME),
		CONNECT_ONE_SHOT,
	)


func is_open() -> bool:
	return _is_open


func _populate_option_button() -> void:
	_condition_option.clear()
	for cond: String in CONDITIONS:
		var factor: float = ItemInstance.CONDITION_MULTIPLIERS.get(cond, 1.0)
		_condition_option.add_item(
			"%s  (×%.2f)" % [CONDITION_LABELS[cond], factor]
		)


func _populate(item: ItemInstance) -> void:
	_title_label.text = "Grade Card Condition"
	_item_name_label.text = item.definition.item_name
	var idx: int = CONDITIONS.find(item.condition)
	if idx < 0:
		idx = CONDITIONS.find("good")
	_condition_option.select(maxi(idx, 0))
	_selected_condition = CONDITIONS[maxi(idx, 0)]
	_update_preview()


func _update_preview() -> void:
	var factor: float = ItemInstance.CONDITION_MULTIPLIERS.get(
		_selected_condition, 1.0
	)
	_preview_label.text = "Price multiplier: ×%.2f" % factor


func _on_condition_changed(index: int) -> void:
	if index >= 0 and index < CONDITIONS.size():
		_selected_condition = CONDITIONS[index]
		_update_preview()


func _on_confirm() -> void:
	if not _current_item:
		return
	EventBus.card_condition_selected.emit(
		_current_item.instance_id, _selected_condition
	)
	close()


func _on_cancel() -> void:
	close()


func _on_picker_requested(item_id: StringName) -> void:
	if not _inventory_system:
		return
	var item: ItemInstance = _inventory_system.get_item(String(item_id))
	if not item:
		return
	open(item)
