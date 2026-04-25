## Tests for HUD signal-driven updates, cash animation, and speed cycling.
extends GutTest


var _hud: CanvasLayer
const _HudScene: PackedScene = preload(
	"res://game/scenes/ui/hud.tscn"
)


func before_each() -> void:
	_hud = _HudScene.instantiate()
	add_child_autofree(_hud)


func test_cash_updates_on_money_changed() -> void:
	EventBus.money_changed.emit(0.0, 1234.56)
	await get_tree().create_timer(_hud._CASH_COUNT_DURATION + 0.05).timeout
	var label: Label = _hud.get_node("TopBar/CashLabel")
	assert_string_contains(label.text, "1,234.56")


func test_cash_count_animation_target() -> void:
	EventBus.money_changed.emit(0.0, 500.0)
	assert_eq(_hud._target_cash, 500.0)


func test_cash_flash_green_on_income() -> void:
	EventBus.money_changed.emit(100.0, 200.0)
	assert_not_null(
		_hud._cash_color_tween,
		"Should create a color flash tween for income"
	)


func test_cash_flash_red_on_expense() -> void:
	EventBus.money_changed.emit(200.0, 100.0)
	assert_not_null(
		_hud._cash_color_tween,
		"Should create a color flash tween for expense"
	)


func test_day_updates_on_day_started() -> void:
	EventBus.day_started.emit(5)
	assert_eq(_hud._current_day, 5)


func test_hour_updates_on_hour_changed() -> void:
	EventBus.hour_changed.emit(14)
	assert_eq(_hud._current_hour, 14)


func test_phase_updates_on_day_phase_changed() -> void:
	EventBus.day_phase_changed.emit(TimeSystem.DayPhase.MIDDAY_RUSH)
	assert_eq(_hud._current_phase, TimeSystem.DayPhase.MIDDAY_RUSH)


func test_speed_display_updates_on_speed_changed() -> void:
	EventBus.speed_changed.emit(3.0)
	var btn: Button = _hud.get_node("TopBar/SpeedButton")
	assert_eq(btn.text, "Fast")


func test_speed_paused_display() -> void:
	EventBus.speed_changed.emit(0.0)
	var btn: Button = _hud.get_node("TopBar/SpeedButton")
	assert_eq(btn.text, "Paused")


func test_speed_cycle_emits_time_speed_requested() -> void:
	var received: Array[int] = []
	EventBus.time_speed_requested.connect(
		func(tier: int) -> void: received.append(tier)
	)
	_hud._current_speed = 1.0
	GameManager.current_state = GameManager.State.GAMEPLAY
	_hud._on_speed_button_pressed()
	assert_eq(received.size(), 1)
	assert_eq(
		received[0], TimeSystem.SpeedTier.FAST,
		"Normal -> Fast in speed cycle"
	)


func test_speed_cycle_wraps_around() -> void:
	var received: Array[int] = []
	EventBus.time_speed_requested.connect(
		func(tier: int) -> void: received.append(tier)
	)
	_hud._current_speed = 6.0
	GameManager.current_state = GameManager.State.GAMEPLAY
	_hud._on_speed_button_pressed()
	assert_eq(
		received[0], TimeSystem.SpeedTier.PAUSED,
		"Ultra -> Paused wraps around"
	)


func test_reputation_updates_on_signal() -> void:
	EventBus.reputation_changed.emit("test_store", 0.0, 80.0)
	assert_eq(_hud._last_reputation, 80.0)


func test_reputation_tier_color_applied_by_display_update() -> void:
	var label: Label = _hud.get_node("TopBar/ReputationLabel")
	_hud._update_reputation_display(80.0)
	var expected: Color = Color(1.0, 0.84, 0.0)
	assert_true(
		label.has_theme_color_override("font_color"),
		"Should have font_color override for tier"
	)
	var actual: Color = label.get_theme_color("font_color")
	assert_eq(actual, expected, "Legendary tier should use gold color")


func test_no_direct_system_references() -> void:
	var script: GDScript = _hud.get_script()
	var source: String = script.source_code
	assert_false(
		source.contains("_find_time_system"),
		"HUD should not reference TimeSystem directly"
	)
	assert_false(
		source.contains("_find_economy_system"),
		"HUD should not reference EconomySystem directly"
	)
	assert_false(
		source.contains("_find_reputation_system"),
		"HUD should not reference ReputationSystem directly"
	)
	assert_false(
		source.contains("time_sys.set_speed"),
		"HUD should not call TimeSystem.set_speed directly"
	)


func test_cash_format_with_commas() -> void:
	var formatted: String = _hud._format_cash(1234567.89)
	assert_eq(formatted, "1,234,567.89")


func test_cash_format_zero() -> void:
	var formatted: String = _hud._format_cash(0.0)
	assert_eq(formatted, "0.00")


func test_cash_format_small() -> void:
	var formatted: String = _hud._format_cash(42.50)
	assert_eq(formatted, "42.50")


func test_cash_pulse_scale_income() -> void:
	EventBus.money_changed.emit(100.0, 200.0)
	assert_not_null(
		_hud._cash_scale_tween,
		"Should create a scale pulse tween for income"
	)


func test_cash_pulse_scale_expense() -> void:
	EventBus.money_changed.emit(200.0, 100.0)
	assert_not_null(
		_hud._cash_scale_tween,
		"Should create a scale pulse tween for expense"
	)


func test_expense_scale_is_smaller_than_income_scale() -> void:
	assert_gt(
		_hud._CASH_EXPENSE_SCALE, 1.0,
		"Expense scale should still pulse above 1.0"
	)
	assert_lt(
		_hud._CASH_EXPENSE_SCALE, _hud._CASH_INCOME_SCALE,
		"Expense pulse should be smaller than income pulse"
	)


func test_income_scale_grows() -> void:
	assert_gt(
		_hud._CASH_INCOME_SCALE, 1.0,
		"Income scale should grow above 1.0"
	)


func test_reputation_arrow_tween_on_increase() -> void:
	EventBus.reputation_changed.emit("test_store", 0.0, 60.0)
	_hud._last_reputation = 60.0
	EventBus.reputation_changed.emit("test_store", 0.0, 70.0)
	assert_not_null(
		_hud._rep_arrow_tween,
		"Should create arrow tween on reputation increase"
	)


func test_reputation_arrow_tween_on_decrease() -> void:
	EventBus.reputation_changed.emit("test_store", 0.0, 60.0)
	_hud._last_reputation = 60.0
	EventBus.reputation_changed.emit("test_store", 0.0, 50.0)
	assert_not_null(
		_hud._rep_arrow_tween,
		"Should create arrow tween on reputation decrease"
	)


func test_reputation_arrow_up_text() -> void:
	_hud._last_reputation = 50.0
	EventBus.reputation_changed.emit("test_store", 0.0, 60.0)
	var label: Label = _hud.get_node("TopBar/ReputationLabel")
	assert_string_contains(
		label.text, "\u25B2",
		"Should show up arrow on increase"
	)


func test_reputation_arrow_down_text() -> void:
	_hud._last_reputation = 60.0
	EventBus.reputation_changed.emit("test_store", 0.0, 50.0)
	var label: Label = _hud.get_node("TopBar/ReputationLabel")
	assert_string_contains(
		label.text, "\u25BC",
		"Should show down arrow on decrease"
	)


func test_reputation_flash_uses_issue_025_timing() -> void:
	assert_eq(_hud._REP_ARROW_FADE_IN, 0.1)
	assert_eq(_hud._REP_ARROW_HOLD, 1.0)
	assert_eq(_hud._REP_ARROW_FADE_OUT, 0.4)


func test_reputation_increase_flashes_positive_color() -> void:
	_hud._last_reputation = 50.0
	EventBus.reputation_changed.emit("test_store", 0.0, 60.0)
	await get_tree().create_timer(_hud._REP_ARROW_FADE_IN + 0.05).timeout
	var label: Label = _hud.get_node("TopBar/ReputationLabel")
	assert_eq(
		label.get_theme_color("font_color"),
		UIThemeConstants.get_positive_color(),
		"Increase should flash positive color"
	)


func test_reputation_decrease_flashes_negative_color() -> void:
	_hud._last_reputation = 60.0
	EventBus.reputation_changed.emit("test_store", 0.0, 50.0)
	await get_tree().create_timer(_hud._REP_ARROW_FADE_IN + 0.05).timeout
	var label: Label = _hud.get_node("TopBar/ReputationLabel")
	assert_eq(
		label.get_theme_color("font_color"),
		UIThemeConstants.get_negative_color(),
		"Decrease should flash negative color"
	)


func test_reputation_arrow_removed_after_hold() -> void:
	_hud._last_reputation = 50.0
	EventBus.reputation_changed.emit("test_store", 0.0, 60.0)
	await get_tree().create_timer(
		_hud._REP_ARROW_FADE_IN + _hud._REP_ARROW_HOLD + 0.05
	).timeout
	var label: Label = _hud.get_node("TopBar/ReputationLabel")
	assert_false(
		label.text.contains("\u25B2") or label.text.contains("\u25BC"),
		"Arrow should be removed after the hold"
	)


func test_reputation_color_fades_to_body_font_color() -> void:
	_hud._last_reputation = 50.0
	EventBus.reputation_changed.emit("test_store", 0.0, 60.0)
	await get_tree().create_timer(
		_hud._REP_ARROW_FADE_IN
		+ _hud._REP_ARROW_HOLD
		+ _hud._REP_ARROW_FADE_OUT
		+ 0.05
	).timeout
	var label: Label = _hud.get_node("TopBar/ReputationLabel")
	assert_eq(
		label.get_theme_color("font_color"),
		UIThemeConstants.BODY_FONT_COLOR,
		"Reputation label should fade back to body font color"
	)


func test_no_arrow_on_same_reputation() -> void:
	_hud._last_reputation = 50.0
	EventBus.reputation_changed.emit("test_store", 0.0, 50.0)
	assert_null(
		_hud._rep_arrow_tween,
		"No arrow tween when reputation unchanged"
	)


func test_simultaneous_cash_and_reputation_effects() -> void:
	EventBus.money_changed.emit(100.0, 200.0)
	_hud._last_reputation = 50.0
	EventBus.reputation_changed.emit("test_store", 0.0, 60.0)
	assert_not_null(_hud._cash_scale_tween, "Cash tween active")
	assert_not_null(_hud._rep_arrow_tween, "Rep tween active")
