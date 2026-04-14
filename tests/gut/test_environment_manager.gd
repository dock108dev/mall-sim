## Tests EnvironmentManager: per-zone environment switching, crossfade, signal wiring.
extends GutTest


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


func test_all_store_zones_have_distinct_ambient() -> void:
	var zones: Array[StringName] = [
		&"hallway", &"sports", &"retro_games",
		&"rentals", &"pocket_creatures", &"electronics",
	]
	var seen_colors: Array[Color] = []
	for zone_id: StringName in zones:
		_manager.swap_environment(zone_id, 0.0)
		var env: Environment = _manager.get_world_environment().environment
		assert_not_null(env, "Zone '%s' should have a valid Environment" % zone_id)
		for prev: Color in seen_colors:
			assert_ne(
				env.ambient_light_color, prev,
				"Zone '%s' ambient color should be unique" % zone_id
			)
		seen_colors.append(env.ambient_light_color)


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
