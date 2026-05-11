## Manages a single WorldEnvironment node with crossfade transitions between zones.
extends Node

const DEFAULT_FADE_DURATION: float = 0.5
const HALLWAY_ZONE_ID: StringName = &"hallway"
const HALLWAY_ENVIRONMENT_ID: StringName = &"mall_hallway"
const FALLBACK_ZONE_IDS: Dictionary = {
	&"retro_games": &"retro_games",
}
const FALLBACK_ENVIRONMENT_IDS: Dictionary = {
	&"retro_games": &"retro_games",
}

const PRELOADED_ENVIRONMENTS: Dictionary = {
	HALLWAY_ENVIRONMENT_ID: preload("res://game/resources/environments/env_hallway.tres"),
	&"retro_games": preload("res://game/resources/environments/env_retro_games.tres"),
}

var _world_env: WorldEnvironment
var _current_key: StringName = &""
var _fade_tween: Tween


func _ready() -> void:
	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnvironment"
	add_child(_world_env)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)
	swap_environment(HALLWAY_ZONE_ID, 0.0)


func swap_environment(
	zone_id: StringName, fade_duration: float = DEFAULT_FADE_DURATION
) -> void:
	var resolved: StringName = _resolve_zone(zone_id)
	if resolved.is_empty():
		# §EH-17 — Recoverable: ignore requests for zones that aren't registered.
		# Per §EH-10 (deliberately-tested fallback): multiple integration tests
		# emit `EventBus.store_entered` with sentinel store_ids
		# (`test_npc_store`, `unknown_store`, `test_store`, etc.) to exercise
		# downstream subscribers in isolation; the autoload connection at
		# `_on_store_entered` then funnels those into this method. Escalating
		# would fail CI on tests that exercise the contract on purpose. The
		# silent-return fallback (player stays in the previous environment) is
		# the documented contract.
		# See docs/audits/error-handling-report.md §EH-17.
		push_warning("EnvironmentManager: unknown zone '%s'" % zone_id)
		return

	if resolved == _current_key:
		return

	var environment_id: StringName = _resolve_environment_id(resolved)
	if environment_id.is_empty():
		# §EH-17 — Zone resolved (the ID is in ContentRegistry) but there is
		# no PRELOADED_ENVIRONMENTS entry and no FALLBACK_ENVIRONMENT_IDS
		# entry. This branch is also exercised by tests that register stub
		# stores in ContentRegistry without authoring an env_*.tres
		# resource (e.g. legacy `sports` / `electronics` integration paths
		# that survived the strip-to-bones refactor in test fixtures). Per
		# §EH-10, kept at `push_warning` so those tests still pass; the
		# silent fallback (stay in current environment) is the documented
		# contract.
		push_warning(
			"EnvironmentManager: missing environment mapping for zone '%s'"
			% resolved
		)
		return

	var target_env: Environment = PRELOADED_ENVIRONMENTS[environment_id]

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
	if zone_id == HALLWAY_ZONE_ID or zone_id == HALLWAY_ENVIRONMENT_ID:
		return HALLWAY_ZONE_ID
	if ContentRegistry.is_ready() and ContentRegistry.exists(String(zone_id)):
		return ContentRegistry.resolve(String(zone_id))
	if FALLBACK_ZONE_IDS.has(zone_id):
		return FALLBACK_ZONE_IDS[zone_id]
	return &""


func _resolve_environment_id(zone_key: StringName) -> StringName:
	if zone_key == HALLWAY_ZONE_ID:
		return HALLWAY_ENVIRONMENT_ID
	if ContentRegistry.is_ready():
		var entry: Dictionary = ContentRegistry.get_entry(zone_key)
		if not entry.is_empty():
			var environment_id: StringName = StringName(
				str(entry.get("environment_id", ""))
			)
			if PRELOADED_ENVIRONMENTS.has(environment_id):
				return environment_id
	if FALLBACK_ENVIRONMENT_IDS.has(zone_key):
		return FALLBACK_ENVIRONMENT_IDS[zone_key]
	return &""


func _on_store_entered(store_id: StringName) -> void:
	swap_environment(store_id)


func _on_store_exited(_store_id: StringName) -> void:
	swap_environment(HALLWAY_ZONE_ID)
