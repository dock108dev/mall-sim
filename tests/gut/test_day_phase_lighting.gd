## Tests for DayPhaseLighting phase presets and tween behavior.
extends GutTest


var _lighting: DayPhaseLighting
var _world_env: WorldEnvironment
var _dir_light: DirectionalLight3D
var _env: Environment


func before_each() -> void:
	_env = Environment.new()
	_env.ambient_light_color = Color(0.5, 0.5, 0.5)
	_env.ambient_light_energy = 0.5

	_world_env = WorldEnvironment.new()
	_world_env.environment = _env
	add_child_autofree(_world_env)

	_dir_light = DirectionalLight3D.new()
	_dir_light.light_color = Color.WHITE
	_dir_light.light_energy = 1.0
	add_child_autofree(_dir_light)

	_lighting = DayPhaseLighting.new()
	_lighting.directional_light = _dir_light
	add_child_autofree(_lighting)


func test_all_phases_have_presets() -> void:
	for phase: int in [
		TimeSystem.DayPhase.PRE_OPEN,
		TimeSystem.DayPhase.MORNING_RAMP,
		TimeSystem.DayPhase.MIDDAY_RUSH,
		TimeSystem.DayPhase.AFTERNOON,
		TimeSystem.DayPhase.EVENING,
	]:
		var preset: Dictionary = _lighting.get_preset(phase)
		assert_has(preset, "ambient_color", "Phase %d missing ambient_color" % phase)
		assert_has(preset, "ambient_energy", "Phase %d missing ambient_energy" % phase)
		assert_has(preset, "light_color", "Phase %d missing light_color" % phase)
		assert_has(preset, "light_energy", "Phase %d missing light_energy" % phase)


func test_presets_have_distinct_ambient_colors() -> void:
	var colors: Array[Color] = []
	for phase: int in [
		TimeSystem.DayPhase.PRE_OPEN,
		TimeSystem.DayPhase.MORNING_RAMP,
		TimeSystem.DayPhase.MIDDAY_RUSH,
		TimeSystem.DayPhase.AFTERNOON,
		TimeSystem.DayPhase.EVENING,
	]:
		var preset: Dictionary = _lighting.get_preset(phase)
		var color: Color = preset["ambient_color"]
		for existing: Color in colors:
			assert_ne(
				color, existing,
				"Phase %d has duplicate ambient_color" % phase
			)
		colors.append(color)


func test_midday_has_highest_light_energy() -> void:
	var midday: Dictionary = _lighting.get_preset(
		TimeSystem.DayPhase.MIDDAY_RUSH
	)
	for phase: int in [
		TimeSystem.DayPhase.PRE_OPEN,
		TimeSystem.DayPhase.MORNING_RAMP,
		TimeSystem.DayPhase.AFTERNOON,
		TimeSystem.DayPhase.EVENING,
	]:
		var preset: Dictionary = _lighting.get_preset(phase)
		assert_gt(
			midday["light_energy"],
			preset["light_energy"],
			"MIDDAY_RUSH should have highest light_energy"
		)


func test_evening_has_lowest_ambient_energy() -> void:
	var evening: Dictionary = _lighting.get_preset(
		TimeSystem.DayPhase.EVENING
	)
	for phase: int in [
		TimeSystem.DayPhase.PRE_OPEN,
		TimeSystem.DayPhase.MORNING_RAMP,
		TimeSystem.DayPhase.MIDDAY_RUSH,
		TimeSystem.DayPhase.AFTERNOON,
	]:
		var preset: Dictionary = _lighting.get_preset(phase)
		assert_lt(
			evening["ambient_energy"],
			preset["ambient_energy"],
			"EVENING should have lowest ambient_energy"
		)


func test_day_started_resets_to_pre_open_instantly() -> void:
	_env.ambient_light_color = Color(1.0, 0.0, 0.0)
	_env.ambient_light_energy = 9.0

	_lighting._on_day_started(2)

	var preset: Dictionary = _lighting.get_preset(
		TimeSystem.DayPhase.PRE_OPEN
	)
	assert_eq(
		_env.ambient_light_color,
		preset["ambient_color"] as Color,
		"day_started should instantly set PRE_OPEN ambient color"
	)
	assert_eq(
		_env.ambient_light_energy,
		preset["ambient_energy"] as float,
		"day_started should instantly set PRE_OPEN ambient energy"
	)


func test_store_entered_disables_hallway_tweening() -> void:
	_lighting._in_hallway = true
	_lighting._on_store_entered(&"retro_games")
	assert_false(
		_lighting._in_hallway,
		"store_entered should set _in_hallway to false"
	)


func test_store_exited_enables_hallway_tweening() -> void:
	_lighting._in_hallway = false
	_lighting._on_store_exited(&"retro_games")
	assert_true(
		_lighting._in_hallway,
		"store_exited should set _in_hallway to true"
	)


func test_phase_change_ignored_when_in_store() -> void:
	_lighting._in_hallway = false
	var before_color: Color = _env.ambient_light_color

	_lighting._on_day_phase_changed(TimeSystem.DayPhase.EVENING)

	assert_eq(
		_env.ambient_light_color,
		before_color,
		"Phase change should not modify lighting when in store"
	)
