## In-game HUD — shows cash, time, day phase, reputation, store name, and prompts.
extends CanvasLayer

const _PHASE_NAMES: Dictionary = {
	TimeSystem.DayPhase.MORNING: "Morning",
	TimeSystem.DayPhase.MIDDAY: "Midday",
	TimeSystem.DayPhase.AFTERNOON: "Afternoon",
	TimeSystem.DayPhase.EVENING: "Evening",
}

const _PHASE_COLORS: Dictionary = {
	TimeSystem.DayPhase.MORNING: Color(0.95, 0.85, 0.3),
	TimeSystem.DayPhase.MIDDAY: Color(1.0, 1.0, 0.9),
	TimeSystem.DayPhase.AFTERNOON: Color(0.95, 0.65, 0.3),
	TimeSystem.DayPhase.EVENING: Color(0.5, 0.4, 0.8),
}

const _SPEED_LABELS: Dictionary = {
	0.0: "|| PAUSED",
	1.0: ">",
	2.0: ">>",
	4.0: ">>>",
}

const _CASH_PULSE_DURATION: float = 0.4
const _REP_FLASH_DURATION: float = 0.6
const _REP_FLASH_COUNT: int = 3

const _TIER_THRESHOLDS: Array[float] = [0.0, 25.0, 50.0, 80.0]

@onready var cash_label: Label = $CashLabel
@onready var time_label: Label = $TimeLabel
@onready var day_phase_label: Label = $DayPhaseLabel
@onready var prompt_label: Label = $PromptLabel
@onready var reputation_label: Label = $ReputationLabel
@onready var store_label: Label = $StoreLabel
@onready var speed_label: Label = $SpeedLabel
@onready var seasonal_event_label: Label = $SeasonalEventLabel
@onready var _milestones_button: Button = $MilestonesButton

var _current_day: int = 1
var _current_hour: int = Constants.STORE_OPEN_HOUR
var _current_phase: int = TimeSystem.DayPhase.MORNING
var _cash_tween: Tween
var _rep_tween: Tween


func _ready() -> void:
	prompt_label.visible = false
	store_label.visible = false
	seasonal_event_label.visible = false
	EventBus.notification_requested.connect(_on_notification_requested)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.store_opened.connect(_on_store_opened)
	EventBus.store_closed.connect(_on_store_closed)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.speed_changed.connect(_on_speed_changed)
	EventBus.seasonal_event_started.connect(
		_on_seasonal_event_started
	)
	EventBus.seasonal_event_ended.connect(
		_on_seasonal_event_ended
	)
	_milestones_button.pressed.connect(_on_milestones_pressed)
	_update_reputation_display(0.0)
	_update_speed_display(1.0)
	_initialize_from_systems.call_deferred()


func _initialize_from_systems() -> void:
	var time_sys: TimeSystem = _find_time_system()
	if time_sys:
		_current_day = time_sys.current_day
		_current_hour = time_sys.current_hour
		_current_phase = time_sys.current_phase
		_update_speed_display(time_sys.time_scale)
	var econ_sys: EconomySystem = _find_economy_system()
	if econ_sys:
		update_cash(econ_sys.get_cash())
	_refresh_time_display()
	_refresh_phase_display()


func update_cash(amount: float) -> void:
	cash_label.text = "$%.2f" % amount


func update_time(day: int, hour: int) -> void:
	_current_day = day
	_current_hour = hour
	_refresh_time_display()


func show_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = true


func hide_prompt() -> void:
	prompt_label.visible = false


func _on_hour_changed(hour: int) -> void:
	_current_hour = hour
	_refresh_time_display()


func _on_day_started(day: int) -> void:
	_current_day = day
	_refresh_time_display()


func _on_day_phase_changed(new_phase: int) -> void:
	_current_phase = new_phase
	_refresh_phase_display()


func _on_money_changed(
	old_amount: float, new_amount: float
) -> void:
	update_cash(new_amount)
	_pulse_cash_label(new_amount - old_amount)


func _refresh_time_display() -> void:
	var formatted: String = _format_hour_12(_current_hour)
	time_label.text = "Day %d — %s" % [_current_day, formatted]


func _refresh_phase_display() -> void:
	var phase_name: String = _PHASE_NAMES.get(
		_current_phase, "Morning"
	)
	var phase_color: Color = _PHASE_COLORS.get(
		_current_phase, Color.WHITE
	)
	day_phase_label.text = phase_name
	day_phase_label.modulate = phase_color


func _format_hour_12(hour: int) -> String:
	var period: String = "AM" if hour < 12 else "PM"
	var display_hour: int = hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%d:00 %s" % [display_hour, period]


func _on_notification_requested(message: String) -> void:
	if message.is_empty():
		hide_prompt()
	else:
		show_prompt(message)


func _on_reputation_changed(
	old_value: float, new_value: float
) -> void:
	_update_reputation_display(new_value)
	if _get_tier_index(old_value) != _get_tier_index(new_value):
		_flash_reputation_label()


func _update_reputation_display(score: float) -> void:
	var tier_name: String = _get_tier_name(score)
	reputation_label.text = "Rep: %.0f — %s" % [score, tier_name]


func _get_tier_name(score: float) -> String:
	if score >= 80.0:
		return "Legendary"
	elif score >= 50.0:
		return "Destination Shop"
	elif score >= 25.0:
		return "Local Favorite"
	return "Unknown"


func _on_store_opened(store_id: String) -> void:
	if store_id.is_empty():
		store_label.visible = false
		return
	var display_name: String = _get_store_display_name(store_id)
	store_label.text = display_name
	store_label.visible = true


func _on_store_closed(_store_id: String) -> void:
	store_label.visible = false


func _on_seasonal_event_started(_event_id: String) -> void:
	_refresh_seasonal_event_display()


func _on_seasonal_event_ended(_event_id: String) -> void:
	_refresh_seasonal_event_display()


func _refresh_seasonal_event_display() -> void:
	var sys: SeasonalEventSystem = _find_seasonal_event_system()
	if not sys:
		seasonal_event_label.visible = false
		return
	var active: Array[Dictionary] = sys.get_active_events()
	if active.is_empty():
		seasonal_event_label.visible = false
		return
	var names: PackedStringArray = []
	for evt: Dictionary in active:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if def:
			names.append(def.name)
	seasonal_event_label.text = "[S] %s" % ", ".join(names)
	seasonal_event_label.tooltip_text = _build_seasonal_tooltip(
		active
	)
	seasonal_event_label.visible = true


func _build_seasonal_tooltip(
	events: Array[Dictionary]
) -> String:
	var lines: PackedStringArray = []
	for evt: Dictionary in events:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if not def:
			continue
		var desc: String = def.name
		if not def.description.is_empty():
			desc += ": " + def.description
		lines.append(desc)
	return "\n".join(lines)


func _find_seasonal_event_system() -> SeasonalEventSystem:
	var game_world: Node = get_tree().current_scene
	if not game_world:
		return null
	var sys: Node = game_world.find_child(
		"SeasonalEventSystem", false
	)
	if sys is SeasonalEventSystem:
		return sys as SeasonalEventSystem
	return null


func _on_milestones_pressed() -> void:
	EventBus.toggle_milestones_panel.emit()


func _get_store_display_name(store_id: String) -> String:
	if not GameManager.data_loader:
		return store_id.capitalize()
	var store_def: StoreDefinition = (
		GameManager.data_loader.get_store(store_id)
	)
	if store_def:
		return store_def.name
	return store_id.capitalize()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var time_sys: TimeSystem = _find_time_system()
	if not time_sys:
		return
	if event.is_action("time_speed_1"):
		time_sys.set_time_scale(1.0)
		get_viewport().set_input_as_handled()
	elif event.is_action("time_speed_2"):
		time_sys.set_time_scale(2.0)
		get_viewport().set_input_as_handled()
	elif event.is_action("time_speed_4"):
		time_sys.set_time_scale(4.0)
		get_viewport().set_input_as_handled()
	elif event.is_action("time_toggle_pause"):
		time_sys.toggle_pause()
		get_viewport().set_input_as_handled()


func _on_speed_changed(new_speed: float) -> void:
	_update_speed_display(new_speed)


func _update_speed_display(speed: float) -> void:
	speed_label.text = _SPEED_LABELS.get(speed, ">")
	if speed <= 0.0:
		speed_label.modulate = Color(1.0, 0.4, 0.4)
	else:
		speed_label.modulate = Color.WHITE


func _find_time_system() -> TimeSystem:
	var game_world: Node = get_tree().current_scene
	if not game_world:
		return null
	var sys: Node = game_world.find_child("TimeSystem", false)
	return sys as TimeSystem if sys is TimeSystem else null


func _find_economy_system() -> EconomySystem:
	var game_world: Node = get_tree().current_scene
	if not game_world:
		return null
	var sys: Node = game_world.find_child("EconomySystem", false)
	return sys as EconomySystem if sys is EconomySystem else null


func _pulse_cash_label(delta: float) -> void:
	if is_zero_approx(delta):
		return
	if _cash_tween and _cash_tween.is_valid():
		_cash_tween.kill()
	var pulse_color: Color
	if delta > 0.0:
		pulse_color = UIThemeConstants.get_positive_color()
	else:
		pulse_color = UIThemeConstants.get_negative_color()
	cash_label.modulate = pulse_color
	_cash_tween = create_tween()
	_cash_tween.tween_property(
		cash_label, "modulate", Color.WHITE,
		_CASH_PULSE_DURATION
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _flash_reputation_label() -> void:
	if _rep_tween and _rep_tween.is_valid():
		_rep_tween.kill()
	var flash_color: Color = UIThemeConstants.get_warning_color()
	_rep_tween = create_tween()
	for i: int in range(_REP_FLASH_COUNT):
		_rep_tween.tween_property(
			reputation_label, "modulate", flash_color,
			_REP_FLASH_DURATION / (_REP_FLASH_COUNT * 2.0)
		)
		_rep_tween.tween_property(
			reputation_label, "modulate", Color.WHITE,
			_REP_FLASH_DURATION / (_REP_FLASH_COUNT * 2.0)
		)


func _get_tier_index(score: float) -> int:
	var tier_idx: int = 0
	for i: int in range(_TIER_THRESHOLDS.size()):
		if score >= _TIER_THRESHOLDS[i]:
			tier_idx = i
	return tier_idx
