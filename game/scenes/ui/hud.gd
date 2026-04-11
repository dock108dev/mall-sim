## In-game HUD — shows cash, time, day phase, reputation, store name, and prompts.
extends CanvasLayer

const _PHASE_KEYS: Dictionary = {
	TimeSystem.DayPhase.MORNING: "HUD_PHASE_MORNING",
	TimeSystem.DayPhase.MIDDAY: "HUD_PHASE_MIDDAY",
	TimeSystem.DayPhase.AFTERNOON: "HUD_PHASE_AFTERNOON",
	TimeSystem.DayPhase.EVENING: "HUD_PHASE_EVENING",
}

const _PHASE_COLORS: Dictionary = {
	TimeSystem.DayPhase.MORNING: Color(0.95, 0.85, 0.3),
	TimeSystem.DayPhase.MIDDAY: Color(1.0, 1.0, 0.9),
	TimeSystem.DayPhase.AFTERNOON: Color(0.95, 0.65, 0.3),
	TimeSystem.DayPhase.EVENING: Color(0.5, 0.4, 0.8),
}

const _SPEED_LABELS: Dictionary = {
	0.0: "HUD_SPEED_PAUSED",
	1.0: ">",
	2.0: ">>",
	4.0: ">>>",
}

const _CASH_PULSE_DURATION: float = PanelAnimator.FEEDBACK_PULSE_DURATION
const _CASH_INCOME_SCALE: float = 1.15
const _CASH_EXPENSE_SCALE: float = 1.1
const _REP_COLOR_FLASH: float = 0.1
const _REP_HOLD_DURATION: float = 1.0
const _REP_FADE_BACK: float = 0.4


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
var _cash_scale_tween: Tween
var _cash_color_tween: Tween
var _rep_tween: Tween
var _dim_tween: Tween


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
	EventBus.locale_changed.connect(_on_locale_changed)
	EventBus.build_mode_entered.connect(_on_build_mode_entered)
	EventBus.build_mode_exited.connect(_on_build_mode_exited)
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


func _on_locale_changed(_new_locale: String) -> void:
	_refresh_time_display()
	_refresh_phase_display()
	var econ_sys: EconomySystem = _find_economy_system()
	if econ_sys:
		update_cash(econ_sys.get_cash())
	var rep_sys: Node = _find_reputation_system()
	if rep_sys and rep_sys.has_method("get_score"):
		_update_reputation_display(rep_sys.get_score())
	var time_sys: TimeSystem = _find_time_system()
	if time_sys:
		_update_speed_display(time_sys.time_scale)


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
	time_label.text = tr("HUD_DAY_FORMAT") % [_current_day, formatted]


func _refresh_phase_display() -> void:
	var phase_key: String = _PHASE_KEYS.get(
		_current_phase, "HUD_PHASE_MORNING"
	)
	var phase_name: String = tr(phase_key)
	var phase_color: Color = _PHASE_COLORS.get(
		_current_phase, Color.WHITE
	)
	day_phase_label.text = phase_name
	day_phase_label.modulate = phase_color


func _format_hour_12(hour: int) -> String:
	var period: String = tr("HUD_AM") if hour < 12 else tr("HUD_PM")
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
	_flash_reputation_label(old_value, new_value)


func _update_reputation_display(score: float) -> void:
	reputation_label.text = _format_reputation(score)


func _format_reputation(score: float) -> String:
	var tier_name: String = _get_tier_name(score)
	return tr("HUD_REP_FORMAT") % [score, tier_name]


func _get_tier_name(score: float) -> String:
	if score >= 80.0:
		return tr("HUD_TIER_LEGENDARY")
	elif score >= 50.0:
		return tr("HUD_TIER_DESTINATION")
	elif score >= 25.0:
		return tr("HUD_TIER_LOCAL_FAV")
	return tr("HUD_TIER_UNKNOWN")


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
	var label_key: String = _SPEED_LABELS.get(speed, ">")
	speed_label.text = tr(label_key) if label_key == "HUD_SPEED_PAUSED" else label_key
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


func _find_reputation_system() -> Node:
	var game_world: Node = get_tree().current_scene
	if not game_world:
		return null
	return game_world.find_child("ReputationSystem", false)


func _find_economy_system() -> EconomySystem:
	var game_world: Node = get_tree().current_scene
	if not game_world:
		return null
	var sys: Node = game_world.find_child("EconomySystem", false)
	return sys as EconomySystem if sys is EconomySystem else null


func _pulse_cash_label(delta: float) -> void:
	if is_zero_approx(delta):
		return
	PanelAnimator.kill_tween(_cash_scale_tween)
	PanelAnimator.kill_tween(_cash_color_tween)
	var is_income: bool = delta > 0.0
	var target_scale: float = (
		_CASH_INCOME_SCALE if is_income else _CASH_EXPENSE_SCALE
	)
	var pulse_color: Color = (
		UIThemeConstants.get_positive_color() if is_income
		else UIThemeConstants.get_negative_color()
	)
	_cash_scale_tween = PanelAnimator.pulse_scale(
		cash_label, target_scale, _CASH_PULSE_DURATION
	)
	_cash_color_tween = PanelAnimator.flash_color(
		cash_label, pulse_color, _CASH_PULSE_DURATION
	)


func _flash_reputation_label(
	old_value: float, new_value: float
) -> void:
	if is_equal_approx(old_value, new_value):
		return
	PanelAnimator.kill_tween(_rep_tween)
	var increased: bool = new_value > old_value
	var color: Color = (
		UIThemeConstants.get_positive_color() if increased
		else UIThemeConstants.get_negative_color()
	)
	var arrow: String = " \u25B2" if increased else " \u25BC"
	reputation_label.text = _format_reputation(new_value) + arrow
	_rep_tween = reputation_label.create_tween()
	_rep_tween.tween_property(
		reputation_label,
		"theme_override_colors/font_color", color,
		_REP_COLOR_FLASH,
	)
	_rep_tween.tween_interval(_REP_HOLD_DURATION)
	_rep_tween.tween_callback(func() -> void:
		reputation_label.text = _format_reputation(new_value)
	)
	_rep_tween.tween_property(
		reputation_label,
		"theme_override_colors/font_color",
		UIThemeConstants.BODY_FONT_COLOR,
		_REP_FADE_BACK,
	)



func _on_build_mode_entered() -> void:
	_tween_children_alpha(0.5)


func _on_build_mode_exited() -> void:
	_tween_children_alpha(1.0)


func _tween_children_alpha(target: float) -> void:
	PanelAnimator.kill_tween(_dim_tween)
	_dim_tween = create_tween()
	for child: Node in get_children():
		if child is CanvasItem:
			_dim_tween.parallel().tween_property(
				child, "modulate:a", target,
				PanelAnimator.BUILD_MODE_TRANSITION
			).set_ease(Tween.EASE_OUT).set_trans(
				Tween.TRANS_CUBIC
			)
