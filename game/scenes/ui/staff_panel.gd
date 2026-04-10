## Staff hiring and management panel for viewing, hiring, and firing staff.
class_name StaffPanel
extends CanvasLayer

const PANEL_NAME: String = "staff"

const SPEC_COLORS: Dictionary = {
	"stocking": Color(0.4, 0.7, 0.3),
	"pricing": Color(0.3, 0.5, 0.9),
	"customer_service": Color(0.9, 0.6, 0.2),
}

var staff_system: StaffSystem
var economy_system: EconomySystem
var reputation_system: ReputationSystem

var _is_open: bool = false
var _current_store_id: String = ""

@onready var _panel: PanelContainer = $PanelRoot
@onready var _close_button: Button = (
	$PanelRoot/Margin/VBox/Header/CloseButton
)
@onready var _cash_label: Label = (
	$PanelRoot/Margin/VBox/Header/CashLabel
)
@onready var _status_label: Label = (
	$PanelRoot/Margin/VBox/StatusLabel
)
@onready var _hired_title: Label = (
	$PanelRoot/Margin/VBox/HiredSection/HiredTitle
)
@onready var _hired_list: VBoxContainer = (
	$PanelRoot/Margin/VBox/HiredSection/HiredList
)
@onready var _available_list: VBoxContainer = (
	$PanelRoot/Margin/VBox/AvailableScroll/AvailableList
)
@onready var _wages_label: Label = (
	$PanelRoot/Margin/VBox/Footer/WagesLabel
)
@onready var _min_slider: HSlider = (
	$PanelRoot/Margin/VBox/PolicySection/MinSlider
)
@onready var _max_slider: HSlider = (
	$PanelRoot/Margin/VBox/PolicySection/MaxSlider
)
@onready var _min_value_label: Label = (
	$PanelRoot/Margin/VBox/PolicySection/MinValue
)
@onready var _max_value_label: Label = (
	$PanelRoot/Margin/VBox/PolicySection/MaxValue
)


func _ready() -> void:
	_panel.visible = false
	_close_button.pressed.connect(close)
	_min_slider.value_changed.connect(_on_min_slider_changed)
	_max_slider.value_changed.connect(_on_max_slider_changed)
	EventBus.panel_opened.connect(_on_panel_opened)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.toggle_staff_panel.connect(_toggle)
	EventBus.store_opened.connect(_on_store_opened)


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
	_current_store_id = GameManager.current_store_id
	if _current_store_id.is_empty():
		push_warning("StaffPanel: no current store")
		return
	_is_open = true
	_refresh_all()
	_panel.visible = true
	EventBus.panel_opened.emit(PANEL_NAME)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_panel.visible = false
	EventBus.panel_closed.emit(PANEL_NAME)


func _toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _refresh_all() -> void:
	_update_status()
	_update_cash_label()
	_refresh_hired_list()
	_refresh_available_list()
	_update_wages_label()
	_load_policy_sliders()


func _update_status() -> void:
	if not reputation_system:
		_status_label.text = "Reputation: --"
		return
	var rep: float = reputation_system.get_reputation()
	if rep < StaffSystem.MIN_REPUTATION_TO_HIRE:
		_status_label.text = (
			"Reputation: %.0f (need %.0f to hire)"
			% [rep, StaffSystem.MIN_REPUTATION_TO_HIRE]
		)
	else:
		_status_label.text = "Reputation: %.0f" % rep


func _update_cash_label() -> void:
	if economy_system:
		_cash_label.text = (
			"Cash: $%.2f" % economy_system.get_cash()
		)


func _refresh_hired_list() -> void:
	_clear_container(_hired_list)
	if not staff_system:
		return
	var staff: Array[Dictionary] = (
		staff_system.get_staff_for_store(_current_store_id)
	)
	var max_staff: int = StaffSystem.MAX_STAFF_PER_STORE
	_hired_title.text = (
		"Current Staff (%d/%d)" % [staff.size(), max_staff]
	)
	if staff.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No staff hired"
		empty_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_hired_list.add_child(empty_label)
		return
	for entry: Dictionary in staff:
		_create_hired_row(entry)


func _create_hired_row(staff_data: Dictionary) -> void:
	var def_id: String = staff_data.get("definition_id", "")
	var def: StaffDefinition = _get_definition(def_id)
	if not def:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var spec_rect := ColorRect.new()
	spec_rect.custom_minimum_size = Vector2(6, 0)
	spec_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spec_rect.color = SPEC_COLORS.get(
		def.specialization, Color.GRAY
	)
	row.add_child(spec_rect)

	var name_label := Label.new()
	name_label.text = def.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var spec_label := Label.new()
	spec_label.text = _format_specialization(def.specialization)
	spec_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(spec_label)

	var skill_label := Label.new()
	skill_label.text = "Skill %d" % def.skill_level
	skill_label.custom_minimum_size = Vector2(50, 0)
	row.add_child(skill_label)

	var wage_label := Label.new()
	wage_label.text = "$%.0f/day" % def.daily_wage
	wage_label.custom_minimum_size = Vector2(60, 0)
	wage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(wage_label)

	var fire_btn := Button.new()
	fire_btn.text = "Fire"
	fire_btn.custom_minimum_size = Vector2(60, 0)
	var inst_id: String = staff_data.get("instance_id", "")
	fire_btn.pressed.connect(
		_on_fire_pressed.bind(inst_id, _current_store_id)
	)
	row.add_child(fire_btn)

	_hired_list.add_child(row)


func _refresh_available_list() -> void:
	_clear_container(_available_list)
	if not GameManager.data_loader:
		return
	var can_hire: bool = staff_system != null and staff_system.can_hire()
	var at_max: bool = (
		staff_system != null
		and staff_system.get_staff_count(_current_store_id)
		>= StaffSystem.MAX_STAFF_PER_STORE
	)
	var defs: Array[StaffDefinition] = (
		GameManager.data_loader.get_all_staff_definitions()
	)
	defs.sort_custom(_sort_by_wage)
	for def: StaffDefinition in defs:
		_create_available_row(def, can_hire, at_max)


func _create_available_row(
	def: StaffDefinition,
	can_hire: bool,
	at_max: bool
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var spec_rect := ColorRect.new()
	spec_rect.custom_minimum_size = Vector2(6, 0)
	spec_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spec_rect.color = SPEC_COLORS.get(
		def.specialization, Color.GRAY
	)
	row.add_child(spec_rect)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = def.name
	info_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = def.description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_label)
	row.add_child(info_vbox)

	var spec_label := Label.new()
	spec_label.text = _format_specialization(def.specialization)
	spec_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(spec_label)

	var skill_label := Label.new()
	skill_label.text = "Skill %d" % def.skill_level
	skill_label.custom_minimum_size = Vector2(50, 0)
	row.add_child(skill_label)

	var wage_label := Label.new()
	wage_label.text = "$%.0f/day" % def.daily_wage
	wage_label.custom_minimum_size = Vector2(60, 0)
	wage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(wage_label)

	var hire_btn := Button.new()
	hire_btn.text = "Hire"
	hire_btn.custom_minimum_size = Vector2(60, 0)
	hire_btn.disabled = not can_hire or at_max
	if not can_hire:
		hire_btn.tooltip_text = "Need reputation >= 20"
	elif at_max:
		hire_btn.tooltip_text = "Maximum staff reached"
	hire_btn.pressed.connect(
		_on_hire_pressed.bind(def.id)
	)
	row.add_child(hire_btn)

	_available_list.add_child(row)


func _update_wages_label() -> void:
	if not staff_system:
		_wages_label.text = "Daily wages: $0"
		return
	var wages: float = staff_system.get_store_daily_wages(
		_current_store_id
	)
	_wages_label.text = "Daily wages: $%.0f" % wages


func _load_policy_sliders() -> void:
	if not staff_system:
		return
	var policy: Dictionary = staff_system.get_price_policy(
		_current_store_id
	)
	_min_slider.set_value_no_signal(
		policy.get("min_ratio", 0.5)
	)
	_max_slider.set_value_no_signal(
		policy.get("max_ratio", 2.0)
	)
	_min_value_label.text = "%d%%" % int(
		_min_slider.value * 100.0
	)
	_max_value_label.text = "%d%%" % int(
		_max_slider.value * 100.0
	)


func _on_hire_pressed(definition_id: String) -> void:
	if not staff_system:
		return
	staff_system.hire_staff(definition_id, _current_store_id)
	_refresh_all()


func _on_fire_pressed(
	instance_id: String, store_id: String
) -> void:
	if not staff_system:
		return
	staff_system.fire_staff(instance_id, store_id)
	_refresh_all()


func _on_min_slider_changed(value: float) -> void:
	_min_value_label.text = "%d%%" % int(value * 100.0)
	if staff_system:
		staff_system.set_price_policy(
			_current_store_id, value, _max_slider.value
		)


func _on_max_slider_changed(value: float) -> void:
	_max_value_label.text = "%d%%" % int(value * 100.0)
	if staff_system:
		staff_system.set_price_policy(
			_current_store_id, _min_slider.value, value
		)


func _on_panel_opened(panel_name: String) -> void:
	if panel_name != PANEL_NAME and _is_open:
		close()


func _on_money_changed(
	_old_amount: float, _new_amount: float
) -> void:
	if not _is_open:
		return
	_update_cash_label()


func _on_reputation_changed(
	_old_value: float, _new_value: float
) -> void:
	if not _is_open:
		return
	_update_status()
	_refresh_available_list()


func _on_store_opened(store_id: String) -> void:
	_current_store_id = store_id
	if _is_open:
		_refresh_all()


func _get_definition(def_id: String) -> StaffDefinition:
	if GameManager.data_loader:
		return GameManager.data_loader.get_staff_definition(def_id)
	return null


func _clear_container(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		child.queue_free()


static func _format_specialization(spec: String) -> String:
	return spec.replace("_", " ").capitalize()


static func _sort_by_wage(
	a: StaffDefinition, b: StaffDefinition
) -> bool:
	return a.daily_wage < b.daily_wage
