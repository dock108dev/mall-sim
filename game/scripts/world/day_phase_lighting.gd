## Tweens hallway ambient lighting and directional light per day phase.
class_name DayPhaseLighting
extends Node


enum LightingState { MORNING, AFTERNOON, EVENING, NIGHT }

const TWEEN_DURATION: float = 2.0
const _HALLWAY_ZONE_ID: StringName = &"hallway"

@export var directional_light: DirectionalLight3D

var _tween: Tween = null
var _in_hallway: bool = true
var _current_day_phase: int = TimeSystem.DayPhase.PRE_OPEN
var _phase_presets: Dictionary = _build_phase_presets()

@onready var _world_environment: WorldEnvironment = (
	EnvironmentManager.get_world_environment()
)
@onready var _scene_directional_light: DirectionalLight3D = (
	directional_light
	if directional_light != null
	else get_node_or_null(^"../SunLight") as DirectionalLight3D
)


class LightingPreset:
	extends RefCounted

	var ambient_color: Color
	var ambient_energy: float
	var light_color: Color
	var light_energy: float
	var background_color: Color


	func _init(
		p_ambient_color: Color,
		p_ambient_energy: float,
		p_light_color: Color,
		p_light_energy: float,
		p_background_color: Color
	) -> void:
		ambient_color = p_ambient_color
		ambient_energy = p_ambient_energy
		light_color = p_light_color
		light_energy = p_light_energy
		background_color = p_background_color


	func to_dictionary() -> Dictionary:
		return {
			"ambient_color": ambient_color,
			"ambient_energy": ambient_energy,
			"light_color": light_color,
			"light_energy": light_energy,
			"background_color": background_color,
		}


## Connects runtime signals and applies the current hallway lighting preset.
func initialize() -> void:
	if not EventBus.day_phase_changed.is_connected(_on_day_phase_changed):
		EventBus.day_phase_changed.connect(_on_day_phase_changed)
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	if not EventBus.store_entered.is_connected(_on_store_entered):
		EventBus.store_entered.connect(_on_store_entered)
	if not EventBus.store_exited.is_connected(_on_store_exited):
		EventBus.store_exited.connect(_on_store_exited)
	if not EventBus.environment_changed.is_connected(_on_environment_changed):
		EventBus.environment_changed.connect(_on_environment_changed)

	_sync_current_phase_from_scene()
	var current_zone_key: StringName = _get_current_zone_key()
	_in_hallway = current_zone_key.is_empty() or current_zone_key == _HALLWAY_ZONE_ID
	if _in_hallway:
		_apply_current_phase_instant()


## Returns the resolved lighting preset dictionary for a runtime day phase.
func get_preset(phase: int) -> Dictionary:
	var preset: LightingPreset = _get_preset_resource(phase)
	return preset.to_dictionary()


func _exit_tree() -> void:
	_kill_tween()


func _on_day_phase_changed(new_phase: int) -> void:
	_current_day_phase = new_phase
	if not _in_hallway:
		return
	_tween_to_preset(new_phase)


func _on_day_started(_day: int) -> void:
	_current_day_phase = TimeSystem.DayPhase.PRE_OPEN
	if not _in_hallway:
		return
	_apply_preset_instant(_current_day_phase)


func _on_store_entered(_store_id: StringName) -> void:
	_in_hallway = false
	_kill_tween()


func _on_store_exited(_store_id: StringName) -> void:
	_in_hallway = true


func _on_environment_changed(zone_key: StringName) -> void:
	_in_hallway = zone_key == _HALLWAY_ZONE_ID
	if not _in_hallway:
		return
	_apply_current_phase_instant()


func _tween_to_preset(phase: int) -> void:
	var preset: LightingPreset = _get_preset_resource(phase)
	var env: Environment = _get_environment()
	if env == null:
		return

	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel(true)

	_tween.tween_property(
		env, "ambient_light_color", preset.ambient_color, TWEEN_DURATION
	)
	_tween.tween_property(
		env, "ambient_light_energy", preset.ambient_energy, TWEEN_DURATION
	)
	_tween.tween_property(
		env, "background_color", preset.background_color, TWEEN_DURATION
	)

	var scene_light: DirectionalLight3D = _get_directional_light()
	if scene_light != null:
		_tween.tween_property(
			scene_light, "light_color", preset.light_color, TWEEN_DURATION
		)
		_tween.tween_property(
			scene_light, "light_energy", preset.light_energy, TWEEN_DURATION
		)


func _apply_preset_instant(phase: int) -> void:
	var preset: LightingPreset = _get_preset_resource(phase)
	var env: Environment = _get_environment()
	if env == null:
		return

	_kill_tween()
	env.ambient_light_color = preset.ambient_color
	env.ambient_light_energy = preset.ambient_energy
	env.background_color = preset.background_color

	var scene_light: DirectionalLight3D = _get_directional_light()
	if scene_light != null:
		scene_light.light_color = preset.light_color
		scene_light.light_energy = preset.light_energy


func _apply_current_phase_instant() -> void:
	_apply_preset_instant(_current_day_phase)


func _get_preset_resource(phase: int) -> LightingPreset:
	var lighting_state: LightingState = _get_lighting_state(phase)
	if _phase_presets.has(lighting_state):
		return _phase_presets[lighting_state] as LightingPreset
	push_error("DayPhaseLighting: missing preset for lighting state %d" % lighting_state)
	return _phase_presets[LightingState.MORNING] as LightingPreset


func _get_lighting_state(phase: int) -> LightingState:
	match phase:
		TimeSystem.DayPhase.PRE_OPEN, TimeSystem.DayPhase.MORNING_RAMP:
			return LightingState.MORNING
		TimeSystem.DayPhase.MIDDAY_RUSH, TimeSystem.DayPhase.AFTERNOON:
			return LightingState.AFTERNOON
		TimeSystem.DayPhase.EVENING:
			return LightingState.EVENING
		TimeSystem.DayPhase.LATE_EVENING:
			return LightingState.NIGHT
		_:
			push_error("DayPhaseLighting: unknown phase %d" % phase)
			return LightingState.MORNING


func _build_phase_presets() -> Dictionary:
	return {
		LightingState.MORNING: LightingPreset.new(
			Color(0.9, 0.7, 0.5),
			0.24,
			Color(1.0, 0.82, 0.64),
			1.2,
			Color(0.96, 0.82, 0.68)
		),
		LightingState.AFTERNOON: LightingPreset.new(
			Color(1.0, 1.0, 0.95),
			0.3,
			Color(1.0, 0.98, 0.92),
			1.8,
			Color(0.72, 0.84, 1.0)
		),
		LightingState.EVENING: LightingPreset.new(
			Color(0.8, 0.5, 0.3),
			0.18,
			Color(0.9, 0.6, 0.38),
			0.8,
			Color(0.58, 0.38, 0.28)
		),
		LightingState.NIGHT: LightingPreset.new(
			Color(0.1, 0.1, 0.25),
			0.08,
			Color(0.22, 0.26, 0.42),
			0.0,
			Color(0.04, 0.05, 0.12)
		),
	}


func _sync_current_phase_from_scene() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	var time_system: TimeSystem = current_scene.get_node_or_null(
		"TimeSystem"
	) as TimeSystem
	if time_system == null:
		return
	_current_day_phase = time_system.get_current_phase()


func _get_current_zone_key() -> StringName:
	return EnvironmentManager.get_current_key()


func _get_environment() -> Environment:
	if _world_environment == null or not is_instance_valid(_world_environment):
		_world_environment = EnvironmentManager.get_world_environment()
	if _world_environment != null and _world_environment.environment != null:
		return _world_environment.environment
	push_error("DayPhaseLighting: missing hallway WorldEnvironment")
	return null


func _get_directional_light() -> DirectionalLight3D:
	if _scene_directional_light == null or not is_instance_valid(_scene_directional_light):
		_scene_directional_light = (
			directional_light
			if directional_light != null
			else get_node_or_null(^"../SunLight") as DirectionalLight3D
		)
	if _scene_directional_light == null:
		push_error("DayPhaseLighting: missing hallway DirectionalLight3D")
	return _scene_directional_light


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
