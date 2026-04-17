## Staff hiring and management panel with candidate list and per-store overview.
class_name StaffPanel
extends CanvasLayer

# Localization marker for static validation: tr("STAFF_HIRE")

const PANEL_NAME: String = "staff"
const MAX_SKILL: int = 3

const ROLE_ICONS: Dictionary = {
	StaffDefinition.StaffRole.CASHIER: "💵",
	StaffDefinition.StaffRole.STOCKER: "📦",
	StaffDefinition.StaffRole.GREETER: "👋",
}

const MORALE_GREEN_THRESHOLD: float = 0.65
const MORALE_YELLOW_THRESHOLD: float = 0.30
const MORALE_COLOR_GREEN: Color = Color(0.3, 0.8, 0.3)
const MORALE_COLOR_YELLOW: Color = Color(0.9, 0.8, 0.2)
const MORALE_COLOR_RED: Color = Color(0.9, 0.2, 0.2)
const MORALE_BG_COLOR: Color = Color(0.2, 0.2, 0.2)
const MORALE_BAR_WIDTH: float = 80.0
const MORALE_BAR_HEIGHT: float = 14.0

const TOAST_DURATION: float = 2.5

var _is_open: bool = false
var _anim_tween: Tween
var _rest_x: float = 0.0
var _current_store_id: String = ""
var _pending_fire_id: String = ""

@onready var _panel: PanelContainer = $PanelRoot
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/Header/CloseButton
)
@onready var _capacity_label: Label = (
	$PanelRoot/Margin/VBox/Header/CapacityLabel
)
@onready var _tab_container: TabContainer = (
	$PanelRoot/Margin/VBox/TabContainer
)
@onready var _current_staff_list: VBoxContainer = (
	$PanelRoot/Margin/VBox/TabContainer/CurrentStaff/StaffScroll/StaffList
)
@onready var _hire_list: VBoxContainer = (
	$PanelRoot/Margin/VBox/TabContainer/Hire/HireScroll/HireList
)
@onready var _confirm_dialog: ConfirmationDialog = $ConfirmDialog
@onready var _toast_panel: PanelContainer = $ToastPanel
@onready var _toast_label: Label = $ToastPanel/ToastLabel


func _ready() -> void:
	_panel.visible = false
	_rest_x = _panel.position.x
	_toast_panel.visible = false
	_close_button.pressed.connect(close)
	_confirm_dialog.confirmed.connect(_on_fire_confirmed)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.toggle_staff_panel.connect(_toggle)
	EventBus.active_store_changed.connect(_on_active_store_changed)
	EventBus.staff_hired.connect(_on_staff_changed)
	EventBus.staff_fired.connect(_on_staff_changed)
	EventBus.staff_quit.connect(_on_staff_quit)
	_sync_active_store()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.is_action_pressed("toggle_staff"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif key_event.is_action_pressed("ui_cancel") and _is_open:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if _is_open:
		return
	_sync_active_store()
	_is_open = true
	_refresh_all()
	PanelAnimator.kill_tween(_anim_tween)
	_anim_tween = PanelAnimator.slide_open(_panel, _rest_x, false)
	EventBus.panel_opened.emit(PANEL_NAME)


func close(immediate: bool = false) -> void:
	if not _is_open:
		return
	_is_open = false
	PanelAnimator.kill_tween(_anim_tween)
	if immediate:
		_panel.visible = false
		_panel.position.x = _rest_x
	else:
		_anim_tween = PanelAnimator.slide_close(
			_panel, _rest_x, false
		)
	EventBus.panel_closed.emit(PANEL_NAME)


func _toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _refresh_all() -> void:
	if _current_store_id.is_empty():
		_show_inactive_state()
		return
	_update_capacity_label()
	_refresh_current_staff()
	_refresh_hire_list()


func _update_capacity_label() -> void:
	var count: int = StaffManager.get_staff_count_for_store(
		_current_store_id
	)
	var max_count: int = StaffManager.get_max_staff_for_store(
		_current_store_id
	)
	_capacity_label.text = "Staff: %d / %d" % [count, max_count]


func _refresh_current_staff() -> void:
	_clear_container(_current_staff_list)
	var staff: Array[StaffDefinition] = (
		StaffManager.get_staff_for_store(_current_store_id)
	)
	if staff.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No staff hired yet"
		empty_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_current_staff_list.add_child(empty_label)
		return
	for member: StaffDefinition in staff:
		_create_staff_row(member)


func _create_staff_row(staff: StaffDefinition) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = staff.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var role_label := Label.new()
	role_label.text = ROLE_ICONS.get(staff.role, "?")
	role_label.custom_minimum_size = Vector2(30, 0)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(role_label)

	var stars_label := Label.new()
	stars_label.text = _format_skill_stars(staff.skill_level)
	stars_label.custom_minimum_size = Vector2(50, 0)
	row.add_child(stars_label)

	var morale_bar := _create_morale_bar(staff.morale)
	row.add_child(morale_bar)

	var fire_btn := Button.new()
	fire_btn.text = "Fire"
	fire_btn.custom_minimum_size = Vector2(60, 0)
	fire_btn.pressed.connect(
		_on_fire_pressed.bind(staff.staff_id, staff.display_name)
	)
	row.add_child(fire_btn)

	_current_staff_list.add_child(row)


func _refresh_hire_list() -> void:
	_clear_container(_hire_list)
	var candidates: Array[StaffDefinition] = (
		StaffManager.get_candidate_pool()
	)
	var at_capacity: bool = (
		StaffManager.get_staff_count_for_store(_current_store_id)
		>= StaffManager.get_max_staff_for_store(_current_store_id)
	)
	if candidates.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No candidates available"
		empty_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_hire_list.add_child(empty_label)
		return
	for candidate: StaffDefinition in candidates:
		_create_hire_row(candidate, at_capacity)


func _create_hire_row(
	candidate: StaffDefinition, at_capacity: bool
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_label := Label.new()
	name_label.text = candidate.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var role_label := Label.new()
	role_label.text = _get_role_name(candidate.role)
	role_label.custom_minimum_size = Vector2(80, 0)
	row.add_child(role_label)

	var stars_label := Label.new()
	stars_label.text = _format_skill_stars(candidate.skill_level)
	stars_label.custom_minimum_size = Vector2(50, 0)
	row.add_child(stars_label)

	var wage_label := Label.new()
	wage_label.text = "$%d/day" % int(candidate.daily_wage)
	wage_label.custom_minimum_size = Vector2(70, 0)
	wage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(wage_label)

	var hire_btn := Button.new()
	hire_btn.text = "Hire"
	hire_btn.custom_minimum_size = Vector2(60, 0)
	hire_btn.disabled = at_capacity
	if at_capacity:
		hire_btn.tooltip_text = "Store at capacity"
	hire_btn.pressed.connect(
		_on_hire_pressed.bind(candidate.staff_id)
	)
	row.add_child(hire_btn)

	_hire_list.add_child(row)


func _create_morale_bar(morale: float) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(
		MORALE_BAR_WIDTH, MORALE_BAR_HEIGHT
	)

	var bg := ColorRect.new()
	bg.color = MORALE_BG_COLOR
	bg.position = Vector2.ZERO
	bg.size = Vector2(MORALE_BAR_WIDTH, MORALE_BAR_HEIGHT)
	container.add_child(bg)

	var fill := ColorRect.new()
	fill.color = _get_morale_color(morale)
	fill.position = Vector2.ZERO
	fill.size = Vector2(
		MORALE_BAR_WIDTH * morale, MORALE_BAR_HEIGHT
	)
	container.add_child(fill)

	return container


func _on_hire_pressed(candidate_id: String) -> void:
	var success: bool = StaffManager.hire_candidate(
		candidate_id, _current_store_id
	)
	if not success:
		_show_toast("Store at capacity")


func _on_fire_pressed(
	staff_id: String, staff_name: String
) -> void:
	_pending_fire_id = staff_id
	_confirm_dialog.dialog_text = (
		"Fire %s? This cannot be undone." % staff_name
	)
	_confirm_dialog.popup_centered()


func _on_fire_confirmed() -> void:
	if _pending_fire_id.is_empty():
		return
	StaffManager.fire_staff(_pending_fire_id)
	_pending_fire_id = ""


func _show_toast(message: String) -> void:
	_toast_label.text = message
	_toast_panel.visible = true
	_toast_panel.modulate = Color.WHITE
	var tween: Tween = create_tween()
	tween.tween_interval(TOAST_DURATION)
	tween.tween_property(
		_toast_panel, "modulate",
		Color(1.0, 1.0, 1.0, 0.0), 0.3
	)
	tween.tween_callback(
		func() -> void:
			_toast_panel.visible = false
			_toast_panel.modulate = Color.WHITE
	)


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close(true)


func _on_active_store_changed(new_store_id: StringName) -> void:
	_current_store_id = String(new_store_id)
	_pending_fire_id = ""
	_confirm_dialog.hide()
	if _is_open:
		_refresh_all()


func _on_staff_changed(
	_staff_id: String, _store_id: String
) -> void:
	if _is_open:
		_refresh_all()


func _on_staff_quit(_staff_id: String) -> void:
	if _is_open:
		_refresh_all()


func _clear_container(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		child.queue_free()


static func _format_skill_stars(level: int) -> String:
	var filled: String = "★".repeat(level)
	var empty: String = "☆".repeat(MAX_SKILL - level)
	return filled + empty


static func _get_morale_color(morale: float) -> Color:
	if morale >= MORALE_GREEN_THRESHOLD:
		return MORALE_COLOR_GREEN
	if morale >= MORALE_YELLOW_THRESHOLD:
		return MORALE_COLOR_YELLOW
	return MORALE_COLOR_RED


static func _get_role_name(role: StaffDefinition.StaffRole) -> String:
	match role:
		StaffDefinition.StaffRole.CASHIER:
			return "Cashier"
		StaffDefinition.StaffRole.STOCKER:
			return "Stocker"
		StaffDefinition.StaffRole.GREETER:
			return "Greeter"
	return "Unknown"


func _show_inactive_state() -> void:
	_capacity_label.text = "No active store"
	_clear_container(_current_staff_list)
	_clear_container(_hire_list)
	var current_label := Label.new()
	current_label.text = "Enter a store to view staff"
	current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_current_staff_list.add_child(current_label)
	var hire_label := Label.new()
	hire_label.text = "Enter a store to manage hiring"
	hire_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hire_list.add_child(hire_label)


func _sync_active_store() -> void:
	_current_store_id = String(GameManager.current_store_id)
