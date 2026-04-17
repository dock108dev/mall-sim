## Tests EnvironmentManager: per-zone environment switching, crossfade, signal wiring.
extends GutTest

const _ENV_HALLWAY: Environment = preload("res://game/resources/environments/env_hallway.tres")
const _ENV_SPORTS: Environment = preload(
	"res://game/resources/environments/env_sports_memorabilia.tres"
)
const _ENV_RETRO_GAMES: Environment = preload("res://game/resources/environments/env_retro_games.tres")
const _ENV_RENTALS: Environment = preload(
	"res://game/resources/environments/env_video_rental.tres"
)
const _ENV_POCKET_CREATURES: Environment = preload(
	"res://game/resources/environments/env_pocket_creatures.tres"
)
const _ENV_ELECTRONICS: Environment = preload("res://game/resources/environments/env_electronics.tres")


var _manager: Node
var _signal_received_key: StringName = &""


func before_each() -> void:
	_signal_received_key = &""
	_manager = Node.new()
	_manager.set_script(
		preload("res://game/autoload/environment_manager.gd")
	)
	EventBus.environment_changed.connect(_on_environment_changed)
	add_child_autofree(_manager)


func after_each() -> void:
	if EventBus.environment_changed.is_connected(_on_environment_changed):
		EventBus.environment_changed.disconnect(_on_environment_changed)


func _on_environment_changed(key: StringName) -> void:
	_signal_received_key = key


func test_initial_state_is_hallway() -> void:
	assert_eq(
		_manager.get_current_key(), &"hallway",
		"Should start with hallway environment"
	)


func test_world_environment_node_exists() -> void:
	var world_env: WorldEnvironment = _manager.get_world_environment()
	assert_not_null(world_env, "Should have a WorldEnvironment child node")
	assert_not_null(
		world_env.environment,
		"WorldEnvironment should have an Environment resource"
	)


func test_swap_to_store_zone() -> void:
	_manager.swap_environment(&"sports", 0.0)
	assert_eq(
		_manager.get_current_key(), &"sports",
		"Should switch to sports environment"
	)


func test_swap_alias_resolves_to_canonical_store_zone() -> void:
	_manager.swap_environment(&"sports_memorabilia", 0.0)
	assert_eq(
		_manager.get_current_key(), &"sports",
		"Alias zone IDs should resolve through ContentRegistry before swapping"
	)


func test_swap_emits_signal() -> void:
	_manager.swap_environment(&"retro_games", 0.0)
	assert_eq(
		_signal_received_key, &"retro_games",
		"Should emit environment_changed with correct zone key"
	)


func test_swap_back_to_hallway() -> void:
	_manager.swap_environment(&"electronics", 0.0)
	_manager.swap_environment(&"hallway", 0.0)
	assert_eq(
		_manager.get_current_key(), &"hallway",
		"Should switch back to hallway"
	)


func test_swap_to_same_key_is_noop() -> void:
	_signal_received_key = &""
	_manager.swap_environment(&"hallway", 0.0)
	assert_eq(
		_signal_received_key, &"",
		"Should not emit signal when switching to same key"
	)


func test_swap_to_unknown_key_errors() -> void:
	_manager.swap_environment(&"nonexistent", 0.0)
	assert_eq(
		_manager.get_current_key(), &"hallway",
		"Should remain on current key when unknown zone is requested"
	)


func test_store_entered_triggers_zone_swap() -> void:
	EventBus.store_entered.emit(&"pocket_creatures")
	assert_eq(
		_manager.get_current_key(), &"pocket_creatures",
		"store_entered should trigger per-store environment swap"
	)


func test_store_exited_returns_to_hallway() -> void:
	_manager.swap_environment(&"rentals", 0.0)
	EventBus.store_exited.emit(&"rentals")
	assert_eq(
		_manager.get_current_key(), &"hallway",
		"store_exited should trigger hallway environment"
	)


func test_hallway_and_store_zones_have_distinct_color_temperature() -> void:
	var ambient_colors: Dictionary = {
		&"hallway": _ENV_HALLWAY.ambient_light_color,
		&"sports": _ENV_SPORTS.ambient_light_color,
		&"retro_games": _ENV_RETRO_GAMES.ambient_light_color,
		&"rentals": _ENV_RENTALS.ambient_light_color,
		&"pocket_creatures": _ENV_POCKET_CREATURES.ambient_light_color,
		&"electronics": _ENV_ELECTRONICS.ambient_light_color,
	}
	assert_true(
		ambient_colors[&"hallway"].b > ambient_colors[&"hallway"].r,
		"Hallway ambient fill should stay cooler than the warm store interiors"
	)
	assert_true(
		ambient_colors[&"sports"].r > ambient_colors[&"sports"].b,
		"Sports memorabilia should read as a warm environment"
	)
	assert_true(
		ambient_colors[&"retro_games"].b > ambient_colors[&"retro_games"].r,
		"Retro games should read as a cooler neon environment"
	)
	assert_true(
		ambient_colors[&"rentals"].b > ambient_colors[&"rentals"].r,
		"Video rental should read as a cooler fluorescent environment"
	)
	assert_true(
		ambient_colors[&"pocket_creatures"].r > ambient_colors[&"pocket_creatures"].b,
		"Pocket creatures should read as a warm showcase environment"
	)
	assert_true(
		ambient_colors[&"electronics"].b > ambient_colors[&"electronics"].r,
		"Electronics should read as a cool showroom environment"
	)


func test_each_swap_finishes_within_frame_budget() -> void:
	var zones: Array[StringName] = [
		&"hallway",
		&"sports_memorabilia",
		&"retro_games",
		&"video_rental",
		&"pocket_creatures",
		&"consumer_electronics",
	]
	for zone_id: StringName in zones:
		var started_usec: int = Time.get_ticks_usec()
		_manager.swap_environment(zone_id, 0.0)
		var elapsed_usec: int = Time.get_ticks_usec() - started_usec
		assert_true(
			elapsed_usec < 16000,
			"Zone '%s' should swap in under 16 ms" % zone_id
		)


func test_all_zones_have_glow_enabled() -> void:
	var zones: Array[StringName] = [
		&"hallway", &"sports", &"retro_games",
		&"rentals", &"pocket_creatures", &"electronics",
	]
	for zone_id: StringName in zones:
		_manager.swap_environment(zone_id, 0.0)
		var env: Environment = _manager.get_world_environment().environment
		assert_true(
			env.glow_enabled,
			"Zone '%s' should have glow enabled" % zone_id
		)
		assert_true(
			env.glow_strength <= 0.5,
			"Zone '%s' glow_strength should be <= 0.5" % zone_id
		)
		assert_true(
			env.glow_bloom <= 0.3,
			"Zone '%s' glow_bloom should be <= 0.3" % zone_id
		)


func test_all_zones_have_ssao_enabled() -> void:
	var zones: Array[StringName] = [
		&"hallway", &"sports", &"retro_games",
		&"rentals", &"pocket_creatures", &"electronics",
	]
	for zone_id: StringName in zones:
		_manager.swap_environment(zone_id, 0.0)
		var env: Environment = _manager.get_world_environment().environment
		assert_true(
			env.ssao_enabled,
			"Zone '%s' should have SSAO enabled" % zone_id
		)
		assert_eq(
			env.ssao_radius, 1.0,
			"Zone '%s' ssao_radius should be 1.0" % zone_id
		)
		assert_eq(
			env.ssao_intensity, 1.5,
			"Zone '%s' ssao_intensity should be 1.5" % zone_id
		)
		assert_eq(
			env.ssao_detail, 0.5,
			"Zone '%s' should keep SSAO detail tuned for contact depth" % zone_id
		)
