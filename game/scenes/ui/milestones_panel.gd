## Panel displaying all milestones with progress and completion status.
class_name MilestonesPanel
extends CanvasLayer


const PANEL_NAME: String = "milestones"

var progression_system: ProgressionSystem
var _is_open: bool = false

@onready var _panel: PanelContainer = $PanelRoot
@onready var _grid: VBoxContainer = (
	$PanelRoot/Margin/VBox/Scroll/Grid
)
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/Header/CloseButton
)


func _ready() -> void:
	_panel.visible = false
	_close_button.pressed.connect(close)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.milestone_completed.connect(_on_milestone_completed)
	EventBus.toggle_milestones_panel.connect(_toggle)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_M:
		_toggle()
		get_viewport().set_input_as_handled()
	elif key_event.is_action_pressed("ui_cancel") and _is_open:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_refresh_list()
	_panel.visible = true
	EventBus.panel_opened.emit(PANEL_NAME)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_panel.visible = false
	EventBus.panel_closed.emit(PANEL_NAME)


func is_open() -> bool:
	return _is_open


func _toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _refresh_list() -> void:
	_clear_list()
	if not progression_system:
		return
	var milestones: Array[Dictionary] = (
		progression_system.get_milestones()
	)
	for milestone: Dictionary in milestones:
		_create_milestone_row(milestone)


func _clear_list() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()


func _create_milestone_row(milestone: Dictionary) -> void:
	var mid: String = milestone.get("id", "")
	var mname: String = milestone.get("name", mid)
	var desc: String = milestone.get("description", "")
	var reward: String = milestone.get("reward_description", "")
	var is_done: bool = progression_system.is_milestone_completed(mid)
	var progress: float = (
		progression_system.get_milestone_progress(milestone)
	)

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 50)

	var status_label := Label.new()
	status_label.custom_minimum_size = Vector2(30, 0)
	if is_done:
		status_label.text = "[x]"
	else:
		status_label.text = "[ ]"
	row.add_child(status_label)

	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = mname
	info_box.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.add_theme_font_size_override("font_size", 12)
	info_box.add_child(desc_label)

	row.add_child(info_box)

	var right_box := VBoxContainer.new()
	right_box.custom_minimum_size = Vector2(160, 0)

	var reward_label := Label.new()
	reward_label.text = reward
	reward_label.add_theme_font_size_override("font_size", 12)
	right_box.add_child(reward_label)

	if is_done:
		var done_label := Label.new()
		done_label.text = "Completed"
		done_label.add_theme_color_override(
			"font_color", Color(0.3, 0.9, 0.3)
		)
		right_box.add_child(done_label)
	else:
		var progress_label := Label.new()
		var pct: int = int(progress * 100.0)
		progress_label.text = "Progress: %d%%" % pct
		right_box.add_child(progress_label)

	row.add_child(right_box)

	var sep := HSeparator.new()

	_grid.add_child(row)
	_grid.add_child(sep)


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close()


func _on_milestone_completed(
	_milestone_id: String,
	_milestone_name: String,
	_reward_description: String,
) -> void:
	if _is_open:
		_refresh_list()
