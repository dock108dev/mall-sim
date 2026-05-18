## Compact right-anchored Day panel for the beta loop.
##
## Owns quiet store status and passive Day milestone progress. The active
## objective label, action copy, key badge, and target hint belong to
## `ObjectiveRail` and `InteractionPrompt`, so this panel never paints an
## active objective row or rail-style stepper.
class_name BetaRightPanel
extends CanvasLayer

const LAYER_INDEX: int = 30

## Modal-fade contract mirrors `hud.gd._MODAL_DIM_ALPHA`.
const _MODAL_DIM_ALPHA: float = 0.65

const _PANEL_BG: Color = Color(0.08, 0.08, 0.14, 0.88)
const _HEADER_FONT_SIZE: int = 16
const _SECTION_FONT_SIZE: int = 12
const _ROW_FONT_SIZE: int = 13
const _ROW_MIN_HEIGHT: float = 24.0
const _SECTION_MIN_HEIGHT: float = 18.0
const _PADDING: int = 12
const _PANEL_WIDTH: float = 244.0
const _RIGHT_INSET: float = 16.0
const _TOP_INSET: float = 56.0

const _HEADER_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const _ROW_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)
const _SECTION_COLOR: Color = Color(1.0, 1.0, 1.0, 0.45)
const _COMPLETED_COLOR: Color = Color(0.3, 1.0, 0.5)
const _MILESTONE_PENDING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.5)
const _CHECK: String = "✓"
const _PENDING_GLYPH: String = "•"

const _DAY_ONE_MILESTONES: Array[Dictionary] = [
	{
		"id": "customer",
		"objective_id": "talk_to_customer",
		"label": "First customer",
	},
	{
		"id": "delivery",
		"objective_id": "back_room_inventory",
		"label": "Delivery",
	},
	{
		"id": "shelf",
		"objective_id": "stock_shelf",
		"label": "Shelf stock",
	},
	{
		"id": "close",
		"objective_id": "close_day",
		"label": "Close",
	},
]

const _PHASE_NAMES: Dictionary = {
	TimeSystem.DayPhase.PRE_OPEN: "OPENING",
	TimeSystem.DayPhase.MORNING_RAMP: "MORNING",
	TimeSystem.DayPhase.MIDDAY_RUSH: "MIDDAY",
	TimeSystem.DayPhase.AFTERNOON: "AFTERNOON",
	TimeSystem.DayPhase.EVENING: "EVENING",
	TimeSystem.DayPhase.LATE_EVENING: "LATE EVENING",
}

var _column: VBoxContainer
var _header: Label
var _on_shelves_value: Label
var _back_room_value: Label
var _customers_value: Label
var _sold_today_value: Label
var _today_anchor: Label

var _milestone_labels: Dictionary = {}
var _completed_objective_ids: Dictionary = {}
var _milestones: Array[Dictionary] = _DAY_ONE_MILESTONES.duplicate(true)

var _current_day: int = 1
var _current_phase: TimeSystem.DayPhase = TimeSystem.DayPhase.PRE_OPEN
var _customers_served_today: int = 0
var _on_shelves_count: int = 0
var _back_room_count: int = 0
var _sold_today_count: int = 0
var _shelf_target_count: int = 0


func _ready() -> void:
	add_to_group("beta_right_panel")
	layer = LAYER_INDEX
	_build_panel()
	_seed_initial_state()
	_refresh_header()
	_refresh_all_values()
	_rebuild_milestones()
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.beta_shelf_count_changed.connect(_on_beta_shelf_count_changed)
	EventBus.beta_backroom_count_changed.connect(_on_beta_backroom_count_changed)
	EventBus.customer_purchased.connect(_on_customer_purchased)
	EventBus.item_sold.connect(_on_item_sold)
	EventBus.beta_objective_completed.connect(_on_beta_objective_completed)
	InputFocus.context_changed.connect(_on_input_focus_changed)


func _exit_tree() -> void:
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)
	if EventBus.day_phase_changed.is_connected(_on_day_phase_changed):
		EventBus.day_phase_changed.disconnect(_on_day_phase_changed)
	if EventBus.beta_shelf_count_changed.is_connected(_on_beta_shelf_count_changed):
		EventBus.beta_shelf_count_changed.disconnect(_on_beta_shelf_count_changed)
	if EventBus.beta_backroom_count_changed.is_connected(_on_beta_backroom_count_changed):
		EventBus.beta_backroom_count_changed.disconnect(_on_beta_backroom_count_changed)
	if EventBus.customer_purchased.is_connected(_on_customer_purchased):
		EventBus.customer_purchased.disconnect(_on_customer_purchased)
	if EventBus.item_sold.is_connected(_on_item_sold):
		EventBus.item_sold.disconnect(_on_item_sold)
	if EventBus.beta_objective_completed.is_connected(_on_beta_objective_completed):
		EventBus.beta_objective_completed.disconnect(_on_beta_objective_completed)
	if InputFocus.context_changed.is_connected(_on_input_focus_changed):
		InputFocus.context_changed.disconnect(_on_input_focus_changed)


func set_objectives(objectives: Array[Dictionary]) -> void:
	_milestones = _milestones_for_objectives(objectives)
	if _column != null:
		_rebuild_milestones()


func seed_for_day(day: int) -> void:
	_current_day = day
	_customers_served_today = 0
	_sold_today_count = 0
	var controller: Node = get_tree().get_first_node_in_group(
		"beta_day_one_controller"
	)
	if controller != null:
		var objs: Variant = controller.get("_objectives")
		if objs is Array:
			var typed: Array[Dictionary] = []
			for entry: Variant in objs as Array:
				if entry is Dictionary:
					typed.append(entry as Dictionary)
			_milestones = _milestones_for_objectives(typed)
	_refresh_header()
	_refresh_all_values()
	_rebuild_milestones()


func _build_panel() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -(_PANEL_WIDTH + _RIGHT_INSET)
	panel.offset_top = _TOP_INSET
	panel.offset_right = -_RIGHT_INSET
	panel.offset_bottom = _TOP_INSET
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = _PANEL_BG
	style.content_margin_left = float(_PADDING)
	style.content_margin_top = float(_PADDING)
	style.content_margin_right = float(_PADDING)
	style.content_margin_bottom = float(_PADDING)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.add_theme_constant_override("separation", 4)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_column)

	_header = Label.new()
	_header.name = "Header"
	_header.custom_minimum_size = Vector2(0.0, _ROW_MIN_HEIGHT)
	_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_theme_font_size_override("font_size", _HEADER_FONT_SIZE)
	_header.add_theme_color_override("font_color", _HEADER_COLOR)
	_column.add_child(_header)

	_build_section_label("StoreSection", "STORE")
	_on_shelves_value = _build_stat_row("Shelf")
	_back_room_value = _build_stat_row("Stockroom")
	_customers_value = _build_stat_row("Customers")
	_sold_today_value = _build_stat_row("Sales")
	_today_anchor = _build_section_label("TodaySection", "TODAY")


func _build_section_label(node_name: String, text: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.custom_minimum_size = Vector2(0.0, _SECTION_MIN_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _SECTION_FONT_SIZE)
	label.add_theme_color_override("font_color", _SECTION_COLOR)
	_column.add_child(label)
	return label


func _build_stat_row(label_text: String) -> Label:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row_%s" % label_text.replace(" ", "")
	row.custom_minimum_size = Vector2(0.0, _ROW_MIN_HEIGHT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(row)

	var label: Label = Label.new()
	label.name = "Label"
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _ROW_FONT_SIZE)
	label.add_theme_color_override("font_color", _ROW_COLOR)
	row.add_child(label)

	var value: Label = Label.new()
	value.name = "Value"
	value.text = "0"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", _ROW_FONT_SIZE)
	value.add_theme_color_override("font_color", _ROW_COLOR)
	row.add_child(value)
	return value


func _seed_initial_state() -> void:
	_current_day = BetaRunState.day
	_customers_served_today = 0
	_on_shelves_count = 0
	_back_room_count = 0
	_sold_today_count = 0
	_shelf_target_count = 0


func _refresh_header() -> void:
	if _header == null:
		return
	var phase_name: String
	if _PHASE_NAMES.has(_current_phase):
		phase_name = str(_PHASE_NAMES[_current_phase])
	else:
		if OS.is_debug_build():
			push_warning(
				"BetaRightPanel: unmapped TimeSystem.DayPhase '%d'" % int(_current_phase)
			)
		phase_name = "UNKNOWN"
	_header.text = "DAY %d — %s" % [_current_day, phase_name]


func _refresh_all_values() -> void:
	if _on_shelves_value != null:
		_on_shelves_value.text = "%d / %d" % [
			_on_shelves_count, _shelf_target_count
		]
	if _back_room_value != null:
		_back_room_value.text = str(_back_room_count)
	if _customers_value != null:
		_customers_value.text = str(_customers_served_today)
	if _sold_today_value != null:
		_sold_today_value.text = str(_sold_today_count)


func _rebuild_milestones() -> void:
	if _column == null:
		return
	for objective_id: StringName in _milestone_labels.keys():
		var label: Label = _milestone_labels[objective_id] as Label
		if is_instance_valid(label):
			label.queue_free()
	_milestone_labels.clear()
	if _milestones.is_empty():
		_milestones = _DAY_ONE_MILESTONES.duplicate(true)
	for entry: Dictionary in _milestones:
		var objective_id: StringName = StringName(str(entry.get("objective_id", "")))
		var label_text: String = str(entry.get("label", "")).strip_edges()
		if String(objective_id).is_empty() or label_text.is_empty():
			continue
		_create_milestone_row(objective_id, label_text)


func _create_milestone_row(objective_id: StringName, label_text: String) -> void:
	if String(objective_id).is_empty() or _milestone_labels.has(objective_id):
		return
	var label: Label = Label.new()
	label.name = "Milestone_%s" % String(objective_id)
	label.custom_minimum_size = Vector2(0.0, _ROW_MIN_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", _ROW_FONT_SIZE)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.set_meta("milestone_label", label_text)
	_column.add_child(label)
	_milestone_labels[objective_id] = label
	_refresh_milestone_row(objective_id)


func _refresh_milestone_row(objective_id: StringName) -> void:
	var label: Label = _milestone_labels.get(objective_id) as Label
	if not is_instance_valid(label):
		return
	var label_text: String = str(label.get_meta("milestone_label", ""))
	if _completed_objective_ids.has(objective_id):
		label.text = "%s %s" % [_CHECK, label_text]
		label.add_theme_color_override("font_color", _COMPLETED_COLOR)
	else:
		label.text = "%s %s" % [_PENDING_GLYPH, label_text]
		label.add_theme_color_override("font_color", _MILESTONE_PENDING_COLOR)


func _milestones_for_objectives(objectives: Array[Dictionary]) -> Array[Dictionary]:
	if _matches_day_one_objectives(objectives):
		return _DAY_ONE_MILESTONES.duplicate(true)
	var fallback: Array[Dictionary] = []
	for entry: Dictionary in objectives:
		var objective_id: String = str(entry.get("id", "")).strip_edges()
		if objective_id.is_empty():
			continue
		var display_label: String = str(entry.get("action", "")).strip_edges()
		if display_label.is_empty():
			display_label = str(entry.get("label", "")).strip_edges()
		if display_label.is_empty():
			display_label = objective_id.capitalize()
		fallback.append({
			"id": objective_id,
			"objective_id": objective_id,
			"label": display_label,
		})
	return fallback


func _matches_day_one_objectives(objectives: Array[Dictionary]) -> bool:
	var ids: Dictionary = {}
	for entry: Dictionary in objectives:
		ids[StringName(str(entry.get("id", "")))] = true
	for milestone: Dictionary in _DAY_ONE_MILESTONES:
		var objective_id: StringName = StringName(str(milestone.get("objective_id", "")))
		if not ids.has(objective_id):
			return false
	return true


func _on_day_started(day: int) -> void:
	_current_day = day
	_customers_served_today = 0
	_sold_today_count = 0
	_completed_objective_ids.clear()
	_refresh_header()
	_refresh_all_values()
	_rebuild_milestones()


func _on_day_phase_changed(new_phase: int) -> void:
	_current_phase = new_phase as TimeSystem.DayPhase
	_refresh_header()


func _on_beta_shelf_count_changed(count: int) -> void:
	_on_shelves_count = count
	_shelf_target_count = max(_shelf_target_count, _on_shelves_count)
	_refresh_all_values()


func _on_beta_backroom_count_changed(count: int) -> void:
	_back_room_count = count
	_shelf_target_count = max(_shelf_target_count, _on_shelves_count + count)
	_refresh_all_values()


func _on_customer_purchased(
	_store_id: StringName, _item_id: StringName,
	_price: float, _customer_id: StringName,
) -> void:
	_customers_served_today += 1
	_refresh_all_values()


func _on_item_sold(_item_id: String, _price: float, _category: String) -> void:
	_sold_today_count += 1
	_refresh_all_values()


func _on_beta_objective_completed(objective_id: StringName) -> void:
	if not _milestone_labels.has(objective_id):
		return
	_completed_objective_ids[objective_id] = true
	_refresh_milestone_row(objective_id)


func _on_input_focus_changed(new_ctx: StringName, _old_ctx: StringName) -> void:
	var target: float = (
		_MODAL_DIM_ALPHA if new_ctx == InputFocus.CTX_MODAL else 1.0
	)
	for child: Node in get_children():
		if child is CanvasItem:
			(child as CanvasItem).modulate.a = target


func get_header_text() -> String:
	if _header == null:
		return ""
	return _header.text


func get_stat_value(stat_name: String) -> String:
	var label: Label = null
	match stat_name:
		"Shelf", "On Shelves":
			label = _on_shelves_value
		"Stockroom", "Back Room":
			label = _back_room_value
		"Customers":
			label = _customers_value
		"Sales", "Sold Today":
			label = _sold_today_value
	if label == null:
		return ""
	return label.text


func get_visible_item_count() -> int:
	var count: int = 0
	for label: Label in _milestone_labels.values():
		if is_instance_valid(label) and label.visible:
			count += 1
	return count


func get_item_glyph(objective_id: StringName) -> String:
	var label: Label = _milestone_labels.get(objective_id) as Label
	if label == null or not is_instance_valid(label):
		return ""
	var text: String = label.text
	if text.begins_with(_CHECK):
		return _CHECK
	if text.begins_with(_PENDING_GLYPH):
		return _PENDING_GLYPH
	return ""


func get_row_state(objective_id: StringName) -> String:
	if not _milestone_labels.has(objective_id):
		return ""
	return "completed" if _completed_objective_ids.has(objective_id) else "pending"
