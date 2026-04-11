## Modal dialog for confirming item refurbishment.
class_name RefurbishmentDialog
extends CanvasLayer

const PANEL_NAME: String = "refurbishment"

var _refurbishment_system: RefurbishmentSystem = null
var _current_item: ItemInstance = null
var _is_open: bool = false
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
@onready var _duration_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/DurationLabel
)
@onready var _chance_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/ChanceLabel
)
@onready var _outcome_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/OutcomeLabel
)
@onready var _warning_label: Label = (
	$PanelRoot/Margin/VBox/InfoVBox/WarningLabel
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


## Sets the RefurbishmentSystem reference.
func set_refurbishment_system(
	system: RefurbishmentSystem
) -> void:
	_refurbishment_system = system


## Opens the dialog for the given item.
func open(item: ItemInstance) -> void:
	if _is_open:
		return
	if not _refurbishment_system:
		push_warning(
			"RefurbishmentDialog: no RefurbishmentSystem set"
		)
		return
	if not _refurbishment_system.can_refurbish(item):
		EventBus.notification_requested.emit(
			tr("REFURBISH_CANNOT")
		)
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


func _populate(item: ItemInstance) -> void:
	_title_label.text = tr("REFURBISH_TITLE")
	_item_name_label.text = item.definition.name
	_condition_label.text = (
		tr("REFURBISH_CONDITION") % item.condition.capitalize()
	)
	var cost: float = _refurbishment_system.get_parts_cost(item)
	_cost_label.text = tr("REFURBISH_COST") % cost
	var duration: int = _refurbishment_system.get_duration(item)
	_duration_label.text = tr("REFURBISH_DURATION") % [
		duration, "" if duration == 1 else "s"
	]
	var chance: float = _refurbishment_system.get_success_chance(item)
	_chance_label.text = tr("REFURBISH_CHANCE") % int(chance * 100.0)
	_outcome_label.text = tr("REFURBISH_SUCCESS")
	_warning_label.text = tr("REFURBISH_FAILURE")
	var active: int = _refurbishment_system.get_active_count()
	_confirm_button.text = tr("REFURBISH_SLOTS") % [
		active, RefurbishmentSystem.MAX_CONCURRENT
	]


func _on_confirm() -> void:
	if not _current_item or not _refurbishment_system:
		return
	var success: bool = _refurbishment_system.start_refurbishment(
		_current_item.instance_id
	)
	if not success:
		return
	close()
