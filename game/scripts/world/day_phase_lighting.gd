## Tweens hallway ambient lighting and directional light per day phase.
class_name DayPhaseLighting
extends Node

const TWEEN_DURATION: float = 2.0

const _PHASE_PRESETS: Dictionary = {
	TimeSystem.DayPhase.PRE_OPEN: {
		"ambient_color": Color(0.9, 0.7, 0.5),
		"ambient_energy": 0.15,
		"light_color": Color(0.9, 0.7, 0.5),
		"light_energy": 0.6,
	},
	TimeSystem.DayPhase.MORNING_RAMP: {
		"ambient_color": Color(0.95, 0.85, 0.7),
		"ambient_energy": 0.2,
		"light_color": Color(1.0, 0.9, 0.75),
		"light_energy": 1.2,
	},
	TimeSystem.DayPhase.MIDDAY_RUSH: {
		"ambient_color": Color(1.0, 1.0, 0.95),
		"ambient_energy": 0.25,
		"light_color": Color(1.0, 1.0, 0.95),
		"light_energy": 1.8,
	},
	TimeSystem.DayPhase.AFTERNOON: {
		"ambient_color": Color(0.95, 0.9, 0.8),
		"ambient_energy": 0.22,
		"light_color": Color(0.95, 0.85, 0.7),
		"light_energy": 1.4,
	},
	TimeSystem.DayPhase.EVENING: {
		"ambient_color": Color(0.8, 0.5, 0.3),
		"ambient_energy": 0.12,
		"light_color": Color(0.8, 0.55, 0.35),
		"light_energy": 0.8,
	},
}

@export var directional_light: DirectionalLight3D

var _tween: Tween
var _in_hallway: bool = true


func initialize() -> void:
	EventBus.day_phase_changed.connect(_on_day_phase_changed)
	EventBus.day_started.connect(_on_day_started)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)
	EventBus.environment_changed.connect(_on_environment_changed)
	_apply_preset_instant(TimeSystem.DayPhase.PRE_OPEN)


func _on_day_phase_changed(new_phase: int) -> void:
	if not _in_hallway:
		return
	_tween_to_preset(new_phase)


func _on_day_started(_day: int) -> void:
	_apply_preset_instant(TimeSystem.DayPhase.PRE_OPEN)


func _on_store_entered(_store_id: StringName) -> void:
	_in_hallway = false
	_kill_tween()


func _on_store_exited(_store_id: StringName) -> void:
	_in_hallway = true


func _on_environment_changed(zone_key: StringName) -> void:
	if zone_key != &"hallway":
		return
	if not _in_hallway:
		return
	_apply_current_phase_instant()


func get_preset(phase: int) -> Dictionary:
	if _PHASE_PRESETS.has(phase):
		return _PHASE_PRESETS[phase]
	push_error("DayPhaseLighting: unknown phase %d" % phase)
	return _PHASE_PRESETS[TimeSystem.DayPhase.PRE_OPEN]


func _tween_to_preset(phase: int) -> void:
	var preset: Dictionary = get_preset(phase)
	var env: Environment = _get_environment()
	if env == null:
		return

	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel(true)

	_tween.tween_property(
		env, "ambient_light_color",
		preset["ambient_color"] as Color, TWEEN_DURATION
	)
	_tween.tween_property(
		env, "ambient_light_energy",
		preset["ambient_energy"] as float, TWEEN_DURATION
	)

	if directional_light:
		_tween.tween_property(
			directional_light, "light_color",
			preset["light_color"] as Color, TWEEN_DURATION
		)
		_tween.tween_property(
			directional_light, "light_energy",
			preset["light_energy"] as float, TWEEN_DURATION
		)


func _apply_preset_instant(phase: int) -> void:
	var preset: Dictionary = get_preset(phase)
	var env: Environment = _get_environment()
	if env == null:
		return

	_kill_tween()
	env.ambient_light_color = preset["ambient_color"]
	env.ambient_light_energy = preset["ambient_energy"]

	if directional_light:
		directional_light.light_color = preset["light_color"]
		directional_light.light_energy = preset["light_energy"]


func _apply_current_phase_instant() -> void:
	var world: Node = get_tree().current_scene
	if world == null:
		return
	var time_sys: TimeSystem = world.get_node_or_null("TimeSystem")
	if time_sys:
		_apply_preset_instant(time_sys.get_current_phase())


func _get_environment() -> Environment:
	var world_env: WorldEnvironment = EnvironmentManager.get_world_environment()
	if world_env and world_env.environment:
		return world_env.environment
	return null


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
