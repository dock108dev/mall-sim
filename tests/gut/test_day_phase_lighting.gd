## Tests DayPhaseLighting hallway presets, tweening, and scene wiring.
extends GutTest


const GAME_WORLD_SCENE: PackedScene = preload(
	"res://game/scenes/world/game_world.tscn"
)
const HALLWAY_ZONE_ID: StringName = &"hallway"
const STORE_ZONE_ID: StringName = &"electronics"

var _lighting: DayPhaseLighting = null
var _world_env: WorldEnvironment = null
var _env: Environment = null
var _dir_light: DirectionalLight3D = null
var _saved_hallway_state: Dictionary = {}


func before_each() -> void:
	EnvironmentManager.swap_environment(HALLWAY_ZONE_ID, 0.0)
	_world_env = EnvironmentManager.get_world_environment()
	_env = _world_env.environment
	_saved_hallway_state = _capture_environment_state(_env)

	_dir_light = DirectionalLight3D.new()
	_dir_light.light_color = Color.WHITE
	_dir_light.light_energy = 1.0
	add_child_autofree(_dir_light)

	_lighting = DayPhaseLighting.new()
	_lighting.directional_light = _dir_light
	add_child_autofree(_lighting)
	_lighting.initialize()


func after_each() -> void:
	EnvironmentManager.swap_environment(HALLWAY_ZONE_ID, 0.0)
	var hallway_env: Environment = EnvironmentManager.get_world_environment().environment
	_restore_environment_state(hallway_env, _saved_hallway_state)


func test_game_world_scene_wires_day_phase_lighting_node() -> void:
	var state: SceneState = GAME_WORLD_SCENE.get_state()
	var idx: int = _find_node_index(state, &"DayPhaseLighting")
	assert_ne(idx, -1, "game_world.tscn should contain a DayPhaseLighting node")
	assert_eq(
		state.get_node_type(idx),
		&"Node",
		"DayPhaseLighting should be attached to a helper Node"
	)
	assert_eq(
		_get_node_script_path(state, idx),
		"res://game/scripts/world/day_phase_lighting.gd",
		"DayPhaseLighting node should point at the hallway lighting controller"
	)
	assert_eq(
		_get_node_property(state, idx, &"directional_light"),
		NodePath("../SunLight"),
		"DayPhaseLighting should target the hallway SunLight node"
	)


func test_representative_phase_presets_match_issue_targets() -> void:
	var morning: Dictionary = _lighting.get_preset(TimeSystem.DayPhase.PRE_OPEN)
	var afternoon: Dictionary = _lighting.get_preset(TimeSystem.DayPhase.AFTERNOON)
	var evening: Dictionary = _lighting.get_preset(TimeSystem.DayPhase.EVENING)
	var night: Dictionary = _lighting.get_preset(TimeSystem.DayPhase.LATE_EVENING)

	assert_eq(
		morning["ambient_color"],
		Color(0.9, 0.7, 0.5),
		"MORNING ambient color should stay warm orange"
	)
	assert_eq(
		afternoon["ambient_color"],
		Color(1.0, 1.0, 0.95),
		"AFTERNOON ambient color should stay neutral white"
	)
	assert_eq(
		evening["ambient_color"],
		Color(0.8, 0.5, 0.3),
		"EVENING ambient color should stay cool orange"
	)
	assert_eq(
		night["ambient_color"],
		Color(0.1, 0.1, 0.25),
		"NIGHT ambient color should stay dark blue"
	)

	assert_eq(
		morning["light_energy"],
		1.2,
		"MORNING sun intensity should stay medium"
	)
	assert_eq(
		afternoon["light_energy"],
		1.8,
		"AFTERNOON sun intensity should stay brightest"
	)
	assert_eq(
		evening["light_energy"],
		0.8,
		"EVENING sun intensity should stay low"
	)
	assert_eq(
		night["light_energy"],
		0.0,
		"NIGHT should disable the directional sun light"
	)


func test_four_lighting_states_have_distinct_ambient_colors() -> void:
	var representative_phases: Array[int] = [
		TimeSystem.DayPhase.PRE_OPEN,
		TimeSystem.DayPhase.AFTERNOON,
		TimeSystem.DayPhase.EVENING,
		TimeSystem.DayPhase.LATE_EVENING,
	]
	var colors: Array[Color] = []
	for phase: int in representative_phases:
		var color: Color = _lighting.get_preset(phase)["ambient_color"] as Color
		for existing: Color in colors:
			assert_ne(
				color,
				existing,
				"Representative phase %d should keep a unique ambient color" % phase
			)
		colors.append(color)


func test_day_phase_change_uses_two_second_tween() -> void:
	var target: Dictionary = _lighting.get_preset(TimeSystem.DayPhase.EVENING)

	_lighting._on_day_phase_changed(TimeSystem.DayPhase.EVENING)

	assert_not_null(_lighting._tween, "day_phase_changed should start a Tween")
	assert_true(
		_lighting._tween.is_valid(),
		"day_phase_changed should keep the tween alive during transition"
	)
	await get_tree().process_frame
	assert_ne(
		_env.ambient_light_color,
		target["ambient_color"] as Color,
		"Transition should not snap to the target color instantly"
	)
	await get_tree().create_timer(
		DayPhaseLighting.TWEEN_DURATION + 0.05
	).timeout
	assert_eq(
		_env.ambient_light_color,
		target["ambient_color"] as Color,
		"Transition should finish on the target ambient color within 2 seconds"
	)
	assert_almost_eq(
		_env.ambient_light_energy,
		target["ambient_energy"] as float,
		0.001,
		"Transition should finish on the target ambient energy"
	)
	assert_eq(
		_dir_light.light_color,
		target["light_color"] as Color,
		"Transition should finish on the target directional light color"
	)
	assert_almost_eq(
		_dir_light.light_energy,
		target["light_energy"] as float,
		0.001,
		"Transition should finish on the target directional light energy"
	)


func test_day_started_resets_to_morning_without_tween() -> void:
	_lighting._apply_preset_instant(TimeSystem.DayPhase.LATE_EVENING)

	_lighting._on_day_started(2)

	var morning: Dictionary = _lighting.get_preset(TimeSystem.DayPhase.PRE_OPEN)
	assert_eq(
		_env.ambient_light_color,
		morning["ambient_color"] as Color,
		"day_started should snap hallway ambient color back to MORNING"
	)
	assert_almost_eq(
		_env.ambient_light_energy,
		morning["ambient_energy"] as float,
		0.001,
		"day_started should snap hallway ambient energy back to MORNING"
	)
	assert_eq(
		_dir_light.light_color,
		morning["light_color"] as Color,
		"day_started should snap directional light color back to MORNING"
	)
	assert_almost_eq(
		_dir_light.light_energy,
		morning["light_energy"] as float,
		0.001,
		"day_started should snap directional light energy back to MORNING"
	)
	assert_null(_lighting._tween, "day_started should not leave a hallway tween running")


func test_phase_changes_do_not_touch_store_environment() -> void:
	EnvironmentManager.swap_environment(STORE_ZONE_ID, 0.0)
	_lighting._on_store_entered(STORE_ZONE_ID)

	var store_env: Environment = EnvironmentManager.get_world_environment().environment
	var before: Dictionary = _capture_environment_state(store_env)
	_lighting._on_day_phase_changed(TimeSystem.DayPhase.LATE_EVENING)
	await get_tree().process_frame

	assert_eq(
		store_env.ambient_light_color,
		before["ambient_light_color"] as Color,
		"Store environment ambient color should remain unchanged"
	)
	assert_eq(
		store_env.ambient_light_energy,
		before["ambient_light_energy"] as float,
		"Store environment ambient energy should remain unchanged"
	)
	assert_eq(
		store_env.background_color,
		before["background_color"] as Color,
		"Store environment sky/background color should remain unchanged"
	)
	assert_null(
		_lighting._tween,
		"Store interior phase changes should not start hallway tweens"
	)


func _capture_environment_state(env: Environment) -> Dictionary:
	return {
		"ambient_light_color": env.ambient_light_color,
		"ambient_light_energy": env.ambient_light_energy,
		"background_color": env.background_color,
	}


func _restore_environment_state(env: Environment, state: Dictionary) -> void:
	env.ambient_light_color = state["ambient_light_color"] as Color
	env.ambient_light_energy = state["ambient_light_energy"] as float
	env.background_color = state["background_color"] as Color


func _find_node_index(state: SceneState, node_name: StringName) -> int:
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) == node_name:
			return i
	return -1


func _get_node_script_path(state: SceneState, node_idx: int) -> String:
	var script: GDScript = _get_node_property(state, node_idx, &"script") as GDScript
	if script == null:
		return ""
	return script.resource_path


func _get_node_property(
	state: SceneState,
	node_idx: int,
	property_name: StringName
) -> Variant:
	for prop_idx: int in range(state.get_node_property_count(node_idx)):
		if state.get_node_property_name(node_idx, prop_idx) == property_name:
			return state.get_node_property_value(node_idx, prop_idx)
	return null
