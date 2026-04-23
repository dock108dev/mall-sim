## Player-facing view of CompletionTracker criteria. Pure consumer of existing
## EventBus signals — no new tracker logic (ISSUE-022).
class_name CompletionTrackerPanel
extends CanvasLayer


const PANEL_NAME: String = "completion_tracker"

const EMPTY_STATE_TEXT: String = (
	"No completion criteria tracked yet.\n"
	+ "Open stores and start selling to light these up."
)

const STATE_LOCKED: String = "Locked"
const STATE_IN_PROGRESS: String = "In progress"
const STATE_COMPLETE: String = "Complete"

const _REFRESH_SIGNALS: Array[StringName] = [
	&"store_leased",
	&"reputation_changed",
	&"active_store_changed",
	&"upgrade_purchased",
	&"milestone_completed",
	&"item_sold",
	&"tournament_completed",
	&"authentication_completed",
	&"refurbishment_completed",
	&"item_rented",
	&"rental_returned",
	&"rental_item_lost",
	&"warranty_purchased",
	&"warranty_claim_triggered",
	&"completion_reached",
]

var completion_tracker: CompletionTracker = null

var _is_open: bool = false

@onready var _panel: PanelContainer = $PanelRoot
@onready var _summary: Label = $PanelRoot/Margin/VBox/Summary
@onready var _close_button: Button = $PanelRoot/Margin/VBox/Header/CloseButton
@onready var _grid: VBoxContainer = $PanelRoot/Margin/VBox/Scroll/Grid
@onready var _empty_state: Label = $PanelRoot/Margin/VBox/EmptyState


func _ready() -> void:
	_panel.visible = false
	_empty_state.text = EMPTY_STATE_TEXT
	_close_button.pressed.connect(close_panel)
	EventBus.toggle_completion_tracker_panel.connect(toggle)
	EventBus.panel_opened.connect(_on_panel_opened)
	_connect_refresh_signals()


func _connect_refresh_signals() -> void:
	var arity_by_signal: Dictionary = {}
	for info: Dictionary in EventBus.get_signal_list():
		arity_by_signal[StringName(info.get("name", ""))] = (
			(info.get("args", []) as Array).size()
		)
	for signal_name: StringName in _REFRESH_SIGNALS:
		if not arity_by_signal.has(signal_name):
			continue
		var arity: int = int(arity_by_signal[signal_name])
		var callable: Callable = _refresh_if_open
		if arity > 0:
			callable = callable.unbind(arity)
		EventBus.connect(signal_name, callable)


func open_panel() -> void:
	if _is_open:
		return
	_is_open = true
	_panel.visible = true
	_refresh()
	EventBus.panel_opened.emit(PANEL_NAME)


func close_panel() -> void:
	if not _is_open:
		return
	_is_open = false
	_panel.visible = false
	EventBus.panel_closed.emit(PANEL_NAME)


func toggle() -> void:
	if _is_open:
		close_panel()
	else:
		open_panel()


func is_open() -> bool:
	return _is_open


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func _on_panel_opened(panel_name: String) -> void:
	# Mutually exclusive panels — close if another panel takes the stage.
	if panel_name != PANEL_NAME and _is_open:
		close_panel()


func _refresh_if_open() -> void:
	if _is_open:
		_refresh()


func _refresh() -> void:
	_clear_rows()
	var data: Array[Dictionary] = _fetch_data()
	if data.is_empty():
		_empty_state.visible = true
		_summary.text = "0 / 0 complete"
		return
	_empty_state.visible = false
	var completed: int = 0
	for criterion: Dictionary in data:
		if bool(criterion.get("complete", false)):
			completed += 1
		_create_row(criterion)
	_summary.text = "%d / %d complete" % [completed, data.size()]


func _fetch_data() -> Array[Dictionary]:
	if completion_tracker == null:
		return []
	if not completion_tracker.has_method("get_completion_data"):
		return []
	return completion_tracker.get_completion_data()


func _clear_rows() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()


func _create_row(criterion: Dictionary) -> void:
	var current: float = float(criterion.get("current", 0.0))
	var required: float = float(criterion.get("required", 0.0))
	var complete: bool = bool(criterion.get("complete", false))
	var state: String = _classify_state(current, required, complete)

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label: Label = Label.new()
	label.text = str(criterion.get("label", criterion.get("id", "?")))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var progress: Label = Label.new()
	progress.text = _format_progress(current, required)
	progress.custom_minimum_size = Vector2(120.0, 0.0)
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(progress)

	var state_label: Label = Label.new()
	state_label.text = state
	state_label.custom_minimum_size = Vector2(110.0, 0.0)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(state_label)

	_grid.add_child(row)
	_grid.add_child(HSeparator.new())


func _classify_state(current: float, required: float, complete: bool) -> String:
	if complete:
		return STATE_COMPLETE
	if current > 0.0 and required > 0.0:
		return STATE_IN_PROGRESS
	return STATE_LOCKED


func _format_progress(current: float, required: float) -> String:
	if required <= 0.0:
		return "—"
	# Whole-number criteria (counts) render without a decimal; money/cash
	# criteria are large enough that a decimal adds noise.
	if _is_whole_number(current) and _is_whole_number(required):
		return "%d / %d" % [int(current), int(required)]
	return "%.0f / %.0f" % [current, required]


func _is_whole_number(value: float) -> bool:
	return absf(value - floor(value)) < 0.0001
