## Integration test: AmbientMomentsSystem context trigger, cooldown enforcement,
## and refire after expiry — all four scenario chains using real EventBus signals.
extends GutTest


var _sys: AmbientMomentsSystem
var _data_loader: DataLoader

# Loaded from ambient_moments.json — trigger_category="time_of_day", trigger_value="9"
var _hour_9_moment: AmbientMomentDefinition
# Loaded from ambient_moments.json — trigger_category="time_of_day", trigger_value="12"
var _hour_12_moment: AmbientMomentDefinition


func before_each() -> void:
	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_load_ambient_moments_from_json()

	GameManager.data_loader = _data_loader
	GameManager.current_store_id = &""

	_sys = AmbientMomentsSystem.new()
	add_child_autofree(_sys)
	_sys._apply_state({})
	# Restrict the moment pool to only the two moments under test to prevent
	# random_chance or other triggers from firing during hour evaluations.
	_sys._moment_definitions = [_hour_9_moment, _hour_12_moment]
	_sys._connect_signals()
	# Transition from IDLE → MONITORING so hour_changed evaluations are active.
	EventBus.day_started.emit(1)


func after_each() -> void:
	GameManager.current_store_id = &""
	GameManager.data_loader = null


# ── Scenario A ───────────────────────────────────────────────────────────────


## Scenario A: moment fires when EventBus.hour_changed matches trigger_value.
func test_scenario_a_moment_fires_on_hour_changed() -> void:
	var trigger_hour: int = int(_hour_9_moment.trigger_value)
	var delivered: Array[StringName] = []
	var cb := func(
		id: StringName, _dt: StringName, _ft: String, _ac: StringName
	) -> void:
		delivered.append(id)
	EventBus.ambient_moment_delivered.connect(cb)

	EventBus.hour_changed.emit(trigger_hour)

	EventBus.ambient_moment_delivered.disconnect(cb)

	assert_eq(
		delivered.size(), 1,
		"Moment should fire exactly once on matching hour_changed"
	)
	assert_eq(
		delivered[0], StringName(_hour_9_moment.id),
		"Delivered moment_id must match the time_of_day trigger definition"
	)


# ── Scenario B ───────────────────────────────────────────────────────────────


## Scenario B: cooldown blocks immediate refire — no push_error on rejection.
func test_scenario_b_cooldown_blocks_immediate_refire() -> void:
	var trigger_hour: int = int(_hour_9_moment.trigger_value)
	# Fire once to activate cooldown.
	EventBus.hour_changed.emit(trigger_hour)

	var delivered: Array[StringName] = []
	var cb := func(
		id: StringName, _dt: StringName, _ft: String, _ac: StringName
	) -> void:
		delivered.append(id)
	EventBus.ambient_moment_delivered.connect(cb)

	# Second emission within cooldown window — must not deliver.
	EventBus.hour_changed.emit(trigger_hour)

	EventBus.ambient_moment_delivered.disconnect(cb)

	assert_eq(
		delivered.size(), 0,
		"Cooldown should silently block immediate refire without push_error"
	)
	assert_true(
		_sys._cooldowns.has(_hour_9_moment.id),
		"Cooldown entry must remain active after blocked refire"
	)


# ── Scenario C ───────────────────────────────────────────────────────────────


## Scenario C: moment fires again after cooldown_days-worth of day_started ticks.
func test_scenario_c_moment_fires_again_after_cooldown_expires() -> void:
	var trigger_hour: int = int(_hour_9_moment.trigger_value)
	# Fire once to activate cooldown.
	EventBus.hour_changed.emit(trigger_hour)

	# Advance exactly cooldown_days days via day_started to expire the entry.
	for i: int in range(_hour_9_moment.cooldown_days):
		EventBus.day_started.emit(i + 2)

	assert_false(
		_sys._cooldowns.has(_hour_9_moment.id),
		"Cooldown entry should be removed after cooldown_days ticks"
	)

	var delivered: Array[StringName] = []
	var cb := func(
		id: StringName, _dt: StringName, _ft: String, _ac: StringName
	) -> void:
		delivered.append(id)
	EventBus.ambient_moment_delivered.connect(cb)

	EventBus.hour_changed.emit(trigger_hour)

	EventBus.ambient_moment_delivered.disconnect(cb)

	assert_eq(
		delivered.size(), 1,
		"Moment should fire again after cooldown expires"
	)
	assert_eq(
		delivered[0], StringName(_hour_9_moment.id),
		"Re-fired id must match the original time_of_day moment"
	)


# ── Scenario D ───────────────────────────────────────────────────────────────


## Scenario D: hour-based trigger fires at the correct hour and not at adjacent hours.
func test_scenario_d_hour_based_trigger_fires_at_correct_hour() -> void:
	# Isolate to the hour-12 moment only; clear any residual cooldowns.
	_sys._moment_definitions = [_hour_12_moment]
	_sys._cooldowns.clear()

	var delivered: Array[StringName] = []
	var cb := func(
		id: StringName, _dt: StringName, _ft: String, _ac: StringName
	) -> void:
		delivered.append(id)
	EventBus.ambient_moment_delivered.connect(cb)

	# Must fire at the matching hour.
	EventBus.hour_changed.emit(12)
	assert_eq(delivered.size(), 1, "Hour-based moment must fire at hour 12")
	assert_eq(
		delivered[0], StringName(_hour_12_moment.id),
		"Delivered id must match the hour-12 moment"
	)

	# Must not re-fire at an adjacent hour while cooldown is active.
	EventBus.hour_changed.emit(13)
	assert_eq(
		delivered.size(), 1,
		"Moment must not re-fire at hour 13 while cooldown is active"
	)

	EventBus.ambient_moment_delivered.disconnect(cb)


# ── Helpers ──────────────────────────────────────────────────────────────────


func _load_ambient_moments_from_json() -> void:
	var json_path := "res://game/content/events/ambient_moments.json"
	var file := FileAccess.open(json_path, FileAccess.READ)
	assert_not_null(file, "ambient_moments.json must be readable at boot path")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_true(parsed is Dictionary, "ambient_moments.json root must be a Dictionary")

	var entries: Array = (parsed as Dictionary).get("moments", [])
	for entry: Variant in entries:
		var d: Dictionary = entry as Dictionary
		var def: AmbientMomentDefinition = ContentParser.parse_ambient_moment(d)
		if def == null:
			continue
		_data_loader._ambient_moments[def.id] = def
		if (
			def.trigger_category == "time_of_day"
			and def.trigger_value == "9"
			and _hour_9_moment == null
		):
			_hour_9_moment = def
		if (
			def.trigger_category == "time_of_day"
			and def.trigger_value == "12"
			and _hour_12_moment == null
		):
			_hour_12_moment = def

	assert_not_null(
		_hour_9_moment,
		"ambient_moments.json must contain a time_of_day moment at hour 9"
	)
	assert_not_null(
		_hour_12_moment,
		"ambient_moments.json must contain a time_of_day moment at hour 12"
	)
