## In-game HUD — persistent top bar with cash, day/time, speed, and reputation.
extends CanvasLayer


const _PHASE_KEYS: Dictionary = {
	TimeSystem.DayPhase.PRE_OPEN: "HUD_PHASE_PRE_OPEN",
	TimeSystem.DayPhase.MORNING_RAMP: "HUD_PHASE_MORNING",
	TimeSystem.DayPhase.MIDDAY_RUSH: "HUD_PHASE_MIDDAY",
	TimeSystem.DayPhase.AFTERNOON: "HUD_PHASE_AFTERNOON",
	TimeSystem.DayPhase.EVENING: "HUD_PHASE_EVENING",
}

const _PHASE_COLORS: Dictionary = {
	TimeSystem.DayPhase.PRE_OPEN: Color(0.7, 0.75, 0.9),
	TimeSystem.DayPhase.MORNING_RAMP: Color(0.95, 0.85, 0.3),
	TimeSystem.DayPhase.MIDDAY_RUSH: Color(1.0, 1.0, 0.9),
	TimeSystem.DayPhase.AFTERNOON: Color(0.95, 0.65, 0.3),
	TimeSystem.DayPhase.EVENING: Color(0.5, 0.4, 0.8),
}

const _SPEED_LABELS: Dictionary = {
	0.0: "Paused",
	1.0: "Normal",
	3.0: "Fast",
	6.0: "Ultra",
}

const _SPEED_CYCLE: Array[TimeSystem.SpeedTier] = [
	TimeSystem.SpeedTier.PAUSED,
	TimeSystem.SpeedTier.NORMAL,
	TimeSystem.SpeedTier.FAST,
	TimeSystem.SpeedTier.ULTRA,
]

const _TIER_THRESHOLDS: Array[float] = [80.0, 50.0, 25.0, 0.0]
const _TIER_COLORS: Array[Color] = [
	Color(1.0, 0.84, 0.0),
	Color(0.3, 0.69, 0.31),
	Color(0.7, 0.7, 0.7),
	Color(0.9, 0.3, 0.25),
]

const _CASH_COUNT_DURATION: float = 0.3
const _CASH_PULSE_DURATION: float = PanelAnimator.FEEDBACK_PULSE_DURATION
const _CASH_INCOME_SCALE: float = 1.15
const _CASH_EXPENSE_SCALE: float = 1.1
const _REP_ARROW_FADE_IN: float = 0.1
const _REP_ARROW_HOLD: float = 1.0
const _REP_ARROW_FADE_OUT: float = 0.4
const _BUILD_MODE_DIM_ALPHA: float = 0.5
const _COUNTER_PULSE_SCALE: float = 1.08
const _COUNTER_PULSE_DURATION: float = PanelAnimator.FEEDBACK_PULSE_DURATION

var _telegraphed_events: Dictionary = {}
var _random_event_telegraph: String = ""

var _current_day: int = 1
var _current_hour: int = Constants.STORE_OPEN_HOUR
var _current_phase: TimeSystem.DayPhase = TimeSystem.DayPhase.PRE_OPEN
var _displayed_cash: float = 0.0
var _target_cash: float = 0.0
var _current_speed: float = 1.0
var _last_reputation: float = ReputationSystemSingleton.DEFAULT_REPUTATION

var _tutorial_step_active: bool = false
var _objective_active: bool = false
var _interactable_focused: bool = false
var _cash_count_tween: Tween
var _cash_scale_tween: Tween
var _cash_color_tween: Tween
var _rep_arrow_tween: Tween
var _dim_tween: Tween
var _close_day_button: Button
var _hub_back_button: Button
var _items_placed_count: int = 0
var _customers_active_count: int = 0
var _sales_today_count: int = 0
var _counter_scale_tweens: Dictionary = {}
var _counter_color_tweens: Dictionary = {}

@onready var _top_bar: HBoxContainer = $TopBar
@onready var _cash_label: Label = $TopBar/CashLabel
@onready var _time_label: Label = $TopBar/TimeLabel
@onready var _items_placed_label: Label = $TopBar/ItemsPlacedLabel
@onready var _customers_label: Label = $TopBar/CustomersLabel
@onready var _sales_today_label: Label = $TopBar/SalesTodayLabel
@onready var _speed_button: Button = $TopBar/SpeedButton
@onready var _reputation_label: Label = $TopBar/ReputationLabel
@onready var _prompt_label: Label = $PromptLabel
@onready var _store_label: Label = $StoreLabel
@onready var _objective_label: Label = $ObjectiveLabel
@onready var _seasonal_event_label: Label = $SeasonalEventLabel
@onready var _telegraph_card: Label = $TelegraphCard
@onready var _milestones_button: Button = $TopBar/MilestonesButton


func _ready() -> void:
	_prompt_label.visible = false
	_store_label.visible = false
	_seasonal_event_label.visible = false
	_telegraph_card.visible = false
	_objective_label.visible = false
	_speed_button.visible = false

	EventBus.objective_text_changed.connect(_on_objective_text_changed)
	EventBus.notification_requested.connect(_on_notification_requested)
	EventBus.critical_notification_requested.connect(_on_critical_notification_requested)
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
	EventBus.event_telegraphed.connect(_on_event_telegraphed)
	EventBus.random_event_telegraphed.connect(_on_random_event_telegraphed)
	EventBus.locale_changed.connect(_on_locale_changed)
	EventBus.build_mode_entered.connect(_on_build_mode_entered)
	EventBus.build_mode_exited.connect(_on_build_mode_exited)
	EventBus.store_entered.connect(_on_store_entered_hub)
	EventBus.store_exited.connect(_on_store_exited_hub)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.customer_entered.connect(_on_customer_entered)
	EventBus.customer_left.connect(_on_customer_left)
	EventBus.item_sold.connect(_on_item_sold)
	_milestones_button.pressed.connect(_on_milestones_pressed)
	_speed_button.pressed.connect(_on_speed_button_pressed)
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.tutorial_step_changed.connect(_on_tutorial_step_changed_hud)
	EventBus.tutorial_completed.connect(_on_tutorial_hint_ended)
	EventBus.tutorial_skipped.connect(_on_tutorial_hint_ended)
	EventBus.run_state_changed.connect(_on_run_state_changed)
	EventBus.interactable_focused.connect(_on_interactable_focused)
	EventBus.interactable_unfocused.connect(_on_interactable_unfocused)

	_create_close_day_button()
	_create_hub_back_button()

	_update_cash_display(_displayed_cash)
	_update_reputation_display(_last_reputation)
	_update_speed_display(_current_speed)
	_refresh_time_display()
	_seed_counters_from_systems()
	_apply_state_visibility(GameManager.current_state)


func _on_day_started(day: int) -> void:
	_current_day = day
	_random_event_telegraph = ""
	_sales_today_count = 0
	_update_sales_today_display(_sales_today_count)
	_refresh_time_display()
	_refresh_items_placed()
	_refresh_customers_active()
	_apply_state_visibility(GameManager.current_state)


func _on_hour_changed(hour: int) -> void:
	_current_hour = hour
	_refresh_time_display()


func _on_day_phase_changed(new_phase: int) -> void:
	_current_phase = new_phase as TimeSystem.DayPhase
	_refresh_time_display()


func _on_money_changed(
	old_amount: float, new_amount: float
) -> void:
	_target_cash = new_amount
	_animate_cash_count(old_amount, new_amount)
	_pulse_cash_label(new_amount - old_amount)


func _on_speed_changed(new_speed: float) -> void:
	_current_speed = new_speed
	_update_speed_display(new_speed)


func _on_reputation_changed(
	_store_id: String, _old_score: float, new_value: float
) -> void:
	var old_value: float = _last_reputation
	_last_reputation = new_value
	_update_reputation_display(new_value)
	_flash_reputation_label(old_value, new_value)


func _create_close_day_button() -> void:
	_close_day_button = Button.new()
	_close_day_button.name = "CloseDayButton"
	_close_day_button.text = "Close Day"
	_close_day_button.custom_minimum_size.x = 80
	_close_day_button.clip_text = false
	_close_day_button.pressed.connect(_on_close_day_pressed)
	_top_bar.add_child(_close_day_button)


func _is_day1_gate_active() -> bool:
	return (
		GameManager.get_current_day() == 1
		and not GameState.get_flag(&"first_sale_complete")
	)


func _on_run_state_changed() -> void:
	if is_instance_valid(_close_day_button):
		_close_day_button.tooltip_text = (
			"Make your first sale before closing Day 1."
			if _is_day1_gate_active()
			else ""
		)


func _on_close_day_pressed() -> void:
	var state := GameManager.current_state
	if state == GameManager.State.STORE_VIEW or state == GameManager.State.GAMEPLAY:
		if _is_day1_gate_active():
			EventBus.critical_notification_requested.emit(
				"Make your first sale before closing Day 1."
			)
			return
		EventBus.day_close_requested.emit()


func _create_hub_back_button() -> void:
	_hub_back_button = Button.new()
	_hub_back_button.name = "HubBackButton"
	_hub_back_button.text = "← Hub"
	_hub_back_button.custom_minimum_size.x = 80
	_hub_back_button.clip_text = false
	_hub_back_button.visible = false
	_hub_back_button.pressed.connect(_on_hub_back_pressed)
	_top_bar.add_child(_hub_back_button)


func _on_hub_back_pressed() -> void:
	EventBus.exit_store_requested.emit()


func _on_store_entered_hub(_store_id: StringName) -> void:
	if is_instance_valid(_hub_back_button):
		_hub_back_button.visible = (
			GameManager.current_state == GameManager.State.STORE_VIEW
		)


func _on_store_exited_hub(_store_id: StringName) -> void:
	if is_instance_valid(_hub_back_button):
		_hub_back_button.visible = false


func _on_game_state_changed(_old_state: int, new_state: int) -> void:
	_apply_state_visibility(new_state as GameManager.State)


func _apply_state_visibility(state: GameManager.State) -> void:
	match state:
		GameManager.State.MAIN_MENU, GameManager.State.DAY_SUMMARY:
			visible = false
		GameManager.State.MALL_OVERVIEW:
			visible = true
			_cash_label.visible = true
			_time_label.visible = true
			_milestones_button.visible = true
			_close_day_button.visible = false
			_hub_back_button.visible = false
			_store_label.visible = false
			_objective_label.visible = false
			_items_placed_label.visible = false
			_customers_label.visible = false
			_sales_today_label.visible = false
			_seasonal_event_label.visible = false
			_telegraph_card.visible = false
		GameManager.State.STORE_VIEW:
			visible = true
			_cash_label.visible = true
			_time_label.visible = true
			_reputation_label.visible = true
			_speed_button.visible = false
			# Day 1 quarantine: the centered MilestonesPanel covers store fixtures
			# while the player is still learning the stock-and-sell loop. Hide the
			# button on Day 1 STORE_VIEW; it remains accessible from MALL_OVERVIEW
			# and re-appears in STORE_VIEW on Day 2+.
			_milestones_button.visible = (
				GameManager.get_current_day() > 1
			)
			_close_day_button.visible = true
			_items_placed_label.visible = true
			_customers_label.visible = true
			_sales_today_label.visible = true
			_store_label.visible = false
			_objective_label.visible = false
			_seasonal_event_label.visible = false
			_telegraph_card.visible = false
		_:
			# §J4: PAUSED, LOADING, BUILD, and other intermediate states inherit
			# the current visibility established by the most recent explicit
			# transition (STORE_VIEW / MALL_OVERVIEW → visible; MAIN_MENU /
			# DAY_SUMMARY → hidden). New GameManager.State values must be
			# added explicitly here if they need distinct HUD visibility.
			pass


func _on_speed_button_pressed() -> void:
	if GameManager.current_state != GameManager.State.GAMEPLAY:
		return
	var next_tier: TimeSystem.SpeedTier = _get_next_speed_tier()
	EventBus.time_speed_requested.emit(int(next_tier))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if GameManager.current_state != GameManager.State.GAMEPLAY:
		return
	if event.is_action("close_day"):
		if _is_day1_gate_active():
			EventBus.critical_notification_requested.emit(
				"Make your first sale before closing Day 1."
			)
			get_viewport().set_input_as_handled()
			return
		EventBus.day_close_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action("time_speed_1"):
		EventBus.time_speed_requested.emit(TimeSystem.SpeedTier.NORMAL)
		get_viewport().set_input_as_handled()
	elif event.is_action("time_speed_2"):
		EventBus.time_speed_requested.emit(TimeSystem.SpeedTier.FAST)
		get_viewport().set_input_as_handled()
	elif event.is_action("time_speed_4"):
		EventBus.time_speed_requested.emit(TimeSystem.SpeedTier.ULTRA)
		get_viewport().set_input_as_handled()
	elif event.is_action("time_toggle_pause"):
		var tier: TimeSystem.SpeedTier = (
			TimeSystem.SpeedTier.NORMAL
			if _current_speed <= 0.0
			else TimeSystem.SpeedTier.PAUSED
		)
		EventBus.time_speed_requested.emit(tier as int)
		get_viewport().set_input_as_handled()


func show_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = true


func hide_prompt() -> void:
	_prompt_label.visible = false


func _refresh_time_display() -> void:
	var formatted: String = _format_hour_12(_current_hour)
	var phase_key: String = _PHASE_KEYS.get(
		_current_phase, "HUD_PHASE_MORNING"
	)
	var phase_color: Color = _PHASE_COLORS.get(
		_current_phase, Color.WHITE
	)
	_time_label.text = tr("HUD_DAY_FORMAT") % [
		_current_day, formatted
	]
	_time_label.tooltip_text = tr(phase_key)
	_time_label.modulate = phase_color


func _format_hour_12(hour: int) -> String:
	var period: String = tr("HUD_AM") if hour < 12 else tr("HUD_PM")
	var display_hour: int = hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%d:00 %s" % [display_hour, period]


func _update_cash_display(amount: float) -> void:
	_cash_label.text = "$%s" % _format_cash(amount)


func _format_cash(amount: float) -> String:
	var whole: int = int(absf(amount))
	var cents: int = int(absf(amount - float(whole)) * 100.0 + 0.5)
	var groups: PackedStringArray = []
	if whole == 0:
		groups.append("0")
	else:
		while whole > 0:
			var chunk: int = whole % 1000
			whole = int(whole / 1000.0)
			if whole > 0:
				groups.append("%03d" % chunk)
			else:
				groups.append(str(chunk))
		groups.reverse()
	var prefix: String = "-" if amount < 0.0 else ""
	return "%s%s.%02d" % [prefix, ",".join(groups), cents]


func _animate_cash_count(
	from_amount: float, to_amount: float
) -> void:
	PanelAnimator.kill_tween(_cash_count_tween)
	_displayed_cash = from_amount
	_cash_count_tween = _cash_label.create_tween()
	_cash_count_tween.tween_method(
		_on_cash_count_step, from_amount, to_amount,
		_CASH_COUNT_DURATION
	)


func _on_cash_count_step(value: float) -> void:
	_displayed_cash = value
	_update_cash_display(value)


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
		_cash_label, target_scale, _CASH_PULSE_DURATION
	)
	_cash_color_tween = PanelAnimator.flash_color(
		_cash_label, pulse_color, _CASH_PULSE_DURATION
	)


func _update_speed_display(speed: float) -> void:
	_speed_button.text = _SPEED_LABELS.get(speed, "Normal")
	if speed <= 0.0:
		_speed_button.modulate = Color(1.0, 0.4, 0.4)
	else:
		_speed_button.modulate = Color.WHITE


func _get_next_speed_tier() -> TimeSystem.SpeedTier:
	var current_index: int = -1
	for i: int in range(_SPEED_CYCLE.size()):
		if is_equal_approx(float(_SPEED_CYCLE[i]), _current_speed):
			current_index = i
			break
	if current_index == -1:
		return TimeSystem.SpeedTier.NORMAL
	return _SPEED_CYCLE[(current_index + 1) % _SPEED_CYCLE.size()]


func _update_reputation_display(score: float) -> void:
	_reputation_label.text = _format_reputation(score)
	_reputation_label.add_theme_color_override(
		"font_color", _get_tier_color(score)
	)


func _format_reputation(score: float) -> String:
	var tier_name: String = _get_tier_name(score)
	return tr("HUD_REP_FORMAT") % [score, tier_name]


func _get_tier_name(score: float) -> String:
	if score >= 80.0:
		return tr("HUD_TIER_LEGENDARY")
	if score >= 50.0:
		return tr("HUD_TIER_DESTINATION")
	if score >= 25.0:
		return tr("HUD_TIER_LOCAL_FAV")
	return tr("HUD_TIER_UNKNOWN")


func _get_tier_color(score: float) -> Color:
	for i: int in range(_TIER_THRESHOLDS.size()):
		if score >= _TIER_THRESHOLDS[i]:
			return _TIER_COLORS[i]
	return _TIER_COLORS[_TIER_COLORS.size() - 1]


func _flash_reputation_label(
	old_value: float, new_value: float
) -> void:
	if is_equal_approx(old_value, new_value):
		return
	PanelAnimator.kill_tween(_rep_arrow_tween)
	var increased: bool = new_value > old_value
	var color: Color = (
		UIThemeConstants.get_positive_color() if increased
		else UIThemeConstants.get_negative_color()
	)
	var arrow: String = " \u25B2" if increased else " \u25BC"
	var label_text: String = _format_reputation(new_value)
	_reputation_label.text = label_text + arrow
	_rep_arrow_tween = _reputation_label.create_tween()
	_rep_arrow_tween.tween_property(
		_reputation_label,
		"theme_override_colors/font_color", color,
		_REP_ARROW_FADE_IN,
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_rep_arrow_tween.tween_interval(_REP_ARROW_HOLD)
	_rep_arrow_tween.tween_callback(func() -> void:
		_reputation_label.text = label_text
	)
	_rep_arrow_tween.tween_property(
		_reputation_label,
		"theme_override_colors/font_color",
		UIThemeConstants.BODY_FONT_COLOR,
		_REP_ARROW_FADE_OUT,
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)


## Updates the visible objective text within one frame of `set_objective_text()`.
func _on_objective_text_changed(text: String) -> void:
	_objective_label.text = text
	var has_text: bool = not text.strip_edges().is_empty()
	_objective_label.visible = has_text
	_objective_active = has_text
	_refresh_telegraph_card()


func _on_interactable_focused(_action_label: String) -> void:
	_interactable_focused = true
	_refresh_telegraph_card()


func _on_interactable_unfocused() -> void:
	_interactable_focused = false
	_refresh_telegraph_card()


func _on_notification_requested(message: String) -> void:
	if _tutorial_step_active:
		return
	if message.is_empty():
		hide_prompt()
	else:
		show_prompt(message)


func _on_critical_notification_requested(message: String) -> void:
	if message.is_empty():
		hide_prompt()
	else:
		show_prompt(message)


func _on_store_opened(store_id: String) -> void:
	if store_id.is_empty():
		_store_label.visible = false
		return
	var display_name: String = _get_store_display_name(store_id)
	_store_label.text = display_name
	var accent: Color = UIThemeConstants.get_store_accent(
		StringName(store_id)
	)
	_store_label.add_theme_color_override("font_color", accent)
	_store_label.visible = true


func _on_store_closed(_store_id: String) -> void:
	_store_label.visible = false


func _on_seasonal_event_started(event_id: String) -> void:
	_telegraphed_events.erase(event_id)
	_refresh_telegraph_card()
	_refresh_seasonal_event_display()


func _on_seasonal_event_ended(_event_id: String) -> void:
	_refresh_seasonal_event_display()


func _on_event_telegraphed(event_id: String, days_until: int) -> void:
	_telegraphed_events[event_id] = days_until
	_refresh_telegraph_card()


func _on_random_event_telegraphed(message: String) -> void:
	_random_event_telegraph = message
	_refresh_telegraph_card()


func _on_tutorial_step_changed_hud(step_id: String) -> void:
	_tutorial_step_active = not step_id.is_empty()
	if _tutorial_step_active:
		_telegraph_card.visible = false
		_seasonal_event_label.visible = false


func _on_tutorial_hint_ended() -> void:
	_tutorial_step_active = false
	_refresh_seasonal_event_display()
	_refresh_telegraph_card()


func _refresh_telegraph_card() -> void:
	if _tutorial_step_active:
		return
	# Overlay priority: tutorial > objective rail > interaction prompt > ticker.
	# Hide the telegraph card whenever a higher-priority surface is active so
	# upcoming-event flavor text never competes with the player's current task.
	if _objective_active or _interactable_focused:
		_telegraph_card.visible = false
		return
	var parts: PackedStringArray = []
	if not _random_event_telegraph.is_empty():
		parts.append(_random_event_telegraph)
	if not _telegraphed_events.is_empty():
		var sys: SeasonalEventSystem = _find_seasonal_event_system()
		for event_id: String in _telegraphed_events:
			var days: int = _telegraphed_events[event_id]
			var display: String = event_id
			if sys:
				for evt: Dictionary in sys.get_announced_events():
					var def: SeasonalEventDefinition = evt.get(
						"definition", null
					) as SeasonalEventDefinition
					if def and def.id == event_id:
						display = def.name
						break
			parts.append("%s in %d day%s" % [
				display, days, "s" if days != 1 else ""
			])
	if parts.is_empty():
		_telegraph_card.visible = false
		return
	_telegraph_card.text = "[!] Coming: %s" % ", ".join(parts)
	_telegraph_card.visible = true


func _refresh_seasonal_event_display() -> void:
	if _tutorial_step_active:
		return
	var sys: SeasonalEventSystem = _find_seasonal_event_system()
	if not sys:
		_seasonal_event_label.visible = false
		return
	var active: Array[Dictionary] = sys.get_active_events()
	if active.is_empty():
		_seasonal_event_label.visible = false
		return
	var names: PackedStringArray = []
	for evt: Dictionary in active:
		var def: SeasonalEventDefinition = evt.get(
			"definition", null
		) as SeasonalEventDefinition
		if def:
			names.append(def.name)
	_seasonal_event_label.text = "[S] %s" % ", ".join(names)
	_seasonal_event_label.tooltip_text = _build_seasonal_tooltip(
		active
	)
	_seasonal_event_label.visible = true


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


func _get_store_display_name(store_id: String) -> String:
	if not GameManager.data_loader:
		return store_id.capitalize()
	var store_def: StoreDefinition = (
		GameManager.data_loader.get_store(store_id)
	)
	if store_def:
		return store_def.store_name
	return store_id.capitalize()


func _on_milestones_pressed() -> void:
	EventBus.toggle_milestones_panel.emit()


func _on_locale_changed(_new_locale: String) -> void:
	_refresh_time_display()
	_update_cash_display(_displayed_cash)
	_update_reputation_display(_last_reputation)
	_update_speed_display(_current_speed)
	_update_items_placed_display(_items_placed_count)
	_update_customers_display(_customers_active_count)
	_update_sales_today_display(_sales_today_count)


func _on_build_mode_entered() -> void:
	_tween_children_alpha(_BUILD_MODE_DIM_ALPHA, Tween.EASE_OUT)


func _on_build_mode_exited() -> void:
	_tween_children_alpha(1.0, Tween.EASE_IN)


func _tween_children_alpha(target: float, tween_ease: int) -> void:
	PanelAnimator.kill_tween(_dim_tween)
	_dim_tween = create_tween()
	for child: Node in get_children():
		if child is CanvasItem:
			_dim_tween.parallel().tween_property(
				child, "modulate:a", target,
				PanelAnimator.BUILD_MODE_TRANSITION
			).set_ease(tween_ease).set_trans(
				Tween.TRANS_CUBIC
			)


## Seeds Items Placed / Customers / Sales Today counters from authoritative
## system getters so save/load and scene reload do not start from zero while
## system state is already populated.
func _seed_counters_from_systems() -> void:
	_refresh_items_placed()
	_refresh_customers_active()
	var economy: EconomySystem = GameManager.get_economy_system()
	if economy != null:
		_sales_today_count = economy.get_items_sold_today()
	_update_sales_today_display(_sales_today_count)


func _on_inventory_changed() -> void:
	_refresh_items_placed()


func _refresh_items_placed() -> void:
	# Silent return: HUD is Tier-5 init (per docs/architecture.md), so
	# inventory_system may legitimately be null on the very first frame and
	# during headless test setup. We re-poll on every inventory_changed
	# signal anyway. See docs/audits/error-handling-report.md §J2.
	var inventory: InventorySystem = GameManager.get_inventory_system()
	if inventory == null:
		return
	var new_count: int = inventory.get_shelf_items().size()
	if new_count == _items_placed_count:
		return
	var delta: int = new_count - _items_placed_count
	_items_placed_count = new_count
	_update_items_placed_display(new_count)
	_pulse_counter(_items_placed_label, delta > 0)


func _on_customer_entered(_data: Dictionary) -> void:
	_customers_active_count += 1
	_update_customers_display(_customers_active_count)
	_pulse_counter(_customers_label, true)


func _on_customer_left(_data: Dictionary) -> void:
	_customers_active_count = maxi(_customers_active_count - 1, 0)
	_update_customers_display(_customers_active_count)
	_pulse_counter(_customers_label, false)


func _refresh_customers_active() -> void:
	# Silent return: HUD is Tier-5 init (per docs/architecture.md), so
	# customer_system may legitimately be null on the first frame and during
	# headless test setup. Re-polls on every customer_entered/left signal.
	# See docs/audits/error-handling-report.md §J2.
	var customers: CustomerSystem = GameManager.get_customer_system()
	if customers == null:
		return
	_customers_active_count = customers.get_active_customer_count()
	_update_customers_display(_customers_active_count)


func _on_item_sold(
	_item_id: String, _price: float, _category: String
) -> void:
	_sales_today_count += 1
	_update_sales_today_display(_sales_today_count)
	_pulse_counter(_sales_today_label, true)


func _update_items_placed_display(count: int) -> void:
	_items_placed_label.text = tr("HUD_PLACED_FORMAT") % count


func _update_customers_display(count: int) -> void:
	_customers_label.text = tr("HUD_CUST_FORMAT") % count


func _update_sales_today_display(count: int) -> void:
	_sales_today_label.text = tr("HUD_SOLD_FORMAT") % count


func _pulse_counter(label: Label, positive: bool) -> void:
	PanelAnimator.kill_tween(_counter_scale_tweens.get(label))
	PanelAnimator.kill_tween(_counter_color_tweens.get(label))
	var color: Color = (
		UIThemeConstants.get_positive_color() if positive
		else UIThemeConstants.get_negative_color()
	)
	_counter_scale_tweens[label] = PanelAnimator.pulse_scale(
		label, _COUNTER_PULSE_SCALE, _COUNTER_PULSE_DURATION
	)
	_counter_color_tweens[label] = PanelAnimator.flash_color(
		label, color, _COUNTER_PULSE_DURATION
	)


## Resets transient display state for test isolation. Called by GUT tests that
## share a single HUD instance across multiple test functions via before_all().
func _reset_for_tests() -> void:
	_telegraphed_events.clear()
	_random_event_telegraph = ""
	_tutorial_step_active = false
	_objective_active = false
	_interactable_focused = false
	_telegraph_card.visible = false
	_seasonal_event_label.visible = false
	_prompt_label.visible = false
