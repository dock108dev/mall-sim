## Manages a single WorldEnvironment node with crossfade transitions between zones.
extends Node

const DEFAULT_FADE_DURATION: float = 0.5

const ZONE_ENVIRONMENTS: Dictionary = {
	&"hallway": preload("res://game/resources/environments/env_hallway.tres"),
	&"sports": preload("res://game/resources/environments/env_sports.tres"),
	&"retro_games": preload("res://game/resources/environments/env_retro_games.tres"),
	&"rentals": preload("res://game/resources/environments/env_rentals.tres"),
	&"pocket_creatures": preload("res://game/resources/environments/env_pocket_creatures.tres"),
	&"electronics": preload("res://game/resources/environments/env_electronics.tres"),
}

var _world_env: WorldEnvironment
var _current_key: StringName = &""
var _fade_tween: Tween


func _ready() -> void:
	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnvironment"
	add_child(_world_env)
	swap_environment(&"hallway", 0.0)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)


func swap_environment(
	zone_id: StringName, fade_duration: float = DEFAULT_FADE_DURATION
) -> void:
	if zone_id == _current_key:
		return

	var resolved: StringName = _resolve_zone(zone_id)
	if resolved.is_empty():
		push_error("EnvironmentManager: unknown zone '%s'" % zone_id)
		return

	var target_env: Environment = ZONE_ENVIRONMENTS[resolved]

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	if fade_duration <= 0.0 or _world_env.environment == null:
		_world_env.environment = target_env
		_current_key = resolved
		EventBus.environment_changed.emit(resolved)
		return

	_current_key = resolved
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)

	_fade_tween.tween_property(
		_world_env.environment, "ambient_light_color",
		target_env.ambient_light_color, fade_duration
	)
	_fade_tween.tween_property(
		_world_env.environment, "ambient_light_energy",
		target_env.ambient_light_energy, fade_duration
	)
	_fade_tween.tween_property(
		_world_env.environment, "background_color",
		target_env.background_color, fade_duration
	)

	_fade_tween.chain().tween_callback(func() -> void:
		_world_env.environment = target_env
		EventBus.environment_changed.emit(resolved)
	)


func get_current_key() -> StringName:
	return _current_key


func get_world_environment() -> WorldEnvironment:
	return _world_env


func _resolve_zone(zone_id: StringName) -> StringName:
	if ZONE_ENVIRONMENTS.has(zone_id):
		return zone_id
	if ContentRegistry.is_ready() and ContentRegistry.exists(String(zone_id)):
		var canonical: StringName = ContentRegistry.resolve(String(zone_id))
		if ZONE_ENVIRONMENTS.has(canonical):
			return canonical
	return &""


func _on_store_entered(store_id: StringName) -> void:
	swap_environment(store_id)


func _on_store_exited(_store_id: StringName) -> void:
	swap_environment(&"hallway")
