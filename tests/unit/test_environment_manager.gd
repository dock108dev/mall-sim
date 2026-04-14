## GUT unit tests for EnvironmentManager autoload — zone resource swap, single-authority enforcement, and environment_changed signal contract.
extends GutTest

const EnvironmentManagerScript: GDScript = preload("res://game/autoload/environment_manager.gd")

const _ENV_SPORTS: Environment = preload("res://game/resources/environments/env_sports.tres")
const _ENV_RETRO_GAMES: Environment = preload("res://game/resources/environments/env_retro_games.tres")
const _ENV_RENTALS: Environment = preload("res://game/resources/environments/env_rentals.tres")
const _ENV_POCKET_CREATURES: Environment = preload(
	"res://game/resources/environments/env_pocket_creatures.tres"
)
const _ENV_ELECTRONICS: Environment = preload(
	"res://game/resources/environments/env_electronics.tres"
)
const _ENV_HALLWAY: Environment = preload("res://game/resources/environments/env_hallway.tres")

var _manager: Node
var _received_zones: Array[StringName] = []
var _signal_count: int = 0


func before_each() -> void:
	_received_zones.clear()
	_signal_count = 0
	_manager = Node.new()
	_manager.set_script(EnvironmentManagerScript)
	add_child_autofree(_manager)
	EventBus.environment_changed.connect(_on_environment_changed)


func after_each() -> void:
	_safe_disconnect(EventBus.environment_changed, _on_environment_changed)
	_safe_disconnect(EventBus.store_entered, _manager._on_store_entered)
	_safe_disconnect(EventBus.store_exited, _manager._on_store_exited)


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_environment_changed(zone_key: StringName) -> void:
	_received_zones.append(zone_key)
	_signal_count += 1


# ── 1. Initial state ──────────────────────────────────────────────────────────


func test_initial_zone_is_hallway() -> void:
	assert_eq(
		_manager.get_current_key(),
		&"hallway",
		"get_current_key() must return &\"hallway\" after initialization"
	)


func test_world_environment_node_exists_after_init() -> void:
	assert_not_null(
		_manager.get_world_environment(),
		"get_world_environment() must return a non-null WorldEnvironment after init"
	)


# ── 2. swap_environment applies correct resource ──────────────────────────────


func test_swap_environment_sports_applies_correct_resource() -> void:
	_manager.swap_environment(&"sports", 0.0)
	assert_eq(
		_manager.get_world_environment().environment,
		_ENV_SPORTS,
		"swap_environment(&\"sports\") must apply the sports Environment resource"
	)


func test_swap_environment_retro_games_applies_correct_resource() -> void:
	_manager.swap_environment(&"retro_games", 0.0)
	assert_eq(
		_manager.get_world_environment().environment,
		_ENV_RETRO_GAMES,
		"swap_environment(&\"retro_games\") must apply the retro_games Environment resource"
	)


func test_swap_environment_electronics_applies_correct_resource() -> void:
	_manager.swap_environment(&"electronics", 0.0)
	assert_eq(
		_manager.get_world_environment().environment,
		_ENV_ELECTRONICS,
		"swap_environment(&\"electronics\") must apply the electronics Environment resource"
	)


# ── 3. environment_changed signal contract ────────────────────────────────────


func test_swap_environment_emits_environment_changed_once() -> void:
	_manager.swap_environment(&"electronics", 0.0)
	assert_eq(
		_signal_count, 1,
		"swap_environment must emit environment_changed exactly once"
	)


func test_swap_environment_emits_correct_zone_id() -> void:
	_manager.swap_environment(&"rentals", 0.0)
	assert_eq(
		_received_zones.size(), 1,
		"Exactly one environment_changed signal should have been received"
	)
	if _received_zones.size() > 0:
		assert_eq(
			_received_zones[0],
			&"rentals",
			"environment_changed must carry the zone_id passed to swap_environment()"
		)


func test_sequential_swaps_each_emit_signal() -> void:
	_manager.swap_environment(&"sports", 0.0)
	_manager.swap_environment(&"electronics", 0.0)
	assert_eq(
		_signal_count, 2,
		"Each distinct zone swap must emit environment_changed once"
	)
	if _received_zones.size() == 2:
		assert_eq(_received_zones[0], &"sports", "First emission must carry &\"sports\"")
		assert_eq(_received_zones[1], &"electronics", "Second emission must carry &\"electronics\"")


# ── 4. Dirty-flag guard — duplicate call does not re-emit ────────────────────


func test_duplicate_swap_does_not_emit_second_time() -> void:
	_manager.swap_environment(&"pocket_creatures", 0.0)
	_signal_count = 0
	_received_zones.clear()
	_manager.swap_environment(&"pocket_creatures", 0.0)
	assert_eq(
		_signal_count, 0,
		"swap_environment with same zone_id must not emit environment_changed again"
	)


func test_duplicate_swap_does_not_change_current_key() -> void:
	_manager.swap_environment(&"electronics", 0.0)
	_manager.swap_environment(&"electronics", 0.0)
	assert_eq(
		_manager.get_current_key(),
		&"electronics",
		"get_current_key() must remain unchanged after a duplicate swap_environment() call"
	)


# ── 5. Unknown zone — does not change environment ────────────────────────────


func test_unknown_zone_does_not_change_current_key() -> void:
	var before: StringName = _manager.get_current_key()
	_manager.swap_environment(&"nonexistent_zone_xyz", 0.0)
	assert_eq(
		_manager.get_current_key(),
		before,
		"Unknown zone_id must not change the current zone"
	)


func test_unknown_zone_does_not_emit_signal() -> void:
	_manager.swap_environment(&"nonexistent_zone_xyz", 0.0)
	assert_eq(
		_signal_count, 0,
		"Unknown zone_id must not emit environment_changed"
	)


func test_unknown_zone_does_not_change_environment_resource() -> void:
	var before_env: Environment = _manager.get_world_environment().environment
	_manager.swap_environment(&"nonexistent_zone_xyz", 0.0)
	assert_eq(
		_manager.get_world_environment().environment,
		before_env,
		"Unknown zone_id must not change the active Environment resource"
	)


# ── 6. Single WorldEnvironment authority ─────────────────────────────────────


func test_exactly_one_world_environment_after_init() -> void:
	var world_envs: Array[Node] = _manager.find_children("*", "WorldEnvironment", true, false)
	assert_eq(
		world_envs.size(),
		1,
		"EnvironmentManager must contain exactly one WorldEnvironment node after init"
	)


func test_exactly_one_world_environment_after_swap() -> void:
	_manager.swap_environment(&"sports", 0.0)
	var world_envs: Array[Node] = _manager.find_children("*", "WorldEnvironment", true, false)
	assert_eq(
		world_envs.size(),
		1,
		"EnvironmentManager must still contain exactly one WorldEnvironment after swap_environment()"
	)


# ── 7. get_current_key returns last successful zone ───────────────────────────


func test_get_current_key_returns_last_set_zone() -> void:
	_manager.swap_environment(&"retro_games", 0.0)
	assert_eq(
		_manager.get_current_key(),
		&"retro_games",
		"get_current_key() must return the StringName of the last successfully set zone"
	)


func test_get_current_key_updates_after_each_successful_swap() -> void:
	_manager.swap_environment(&"sports", 0.0)
	assert_eq(_manager.get_current_key(), &"sports", "key should be sports after first swap")
	_manager.swap_environment(&"electronics", 0.0)
	assert_eq(
		_manager.get_current_key(), &"electronics", "key should be electronics after second swap"
	)


func test_get_current_key_unchanged_after_unknown_zone() -> void:
	_manager.swap_environment(&"rentals", 0.0)
	_manager.swap_environment(&"totally_unknown", 0.0)
	assert_eq(
		_manager.get_current_key(),
		&"rentals",
		"get_current_key() must not change after an unknown zone swap attempt"
	)


# ── 8. EventBus store_entered / store_exited integration ─────────────────────


func test_store_entered_triggers_swap_to_store_zone() -> void:
	EventBus.store_entered.emit(&"retro_games")
	assert_eq(
		_manager.get_current_key(),
		&"retro_games",
		"store_entered must trigger swap_environment to the matching store zone"
	)


func test_store_entered_emits_environment_changed() -> void:
	EventBus.store_entered.emit(&"sports")
	assert_eq(
		_signal_count, 1,
		"store_entered must cause environment_changed to emit once"
	)
	if _received_zones.size() > 0:
		assert_eq(
			_received_zones[0],
			&"sports",
			"environment_changed must carry the store zone id on store_entered"
		)


func test_store_exited_triggers_swap_to_hallway() -> void:
	EventBus.store_entered.emit(&"sports")
	_signal_count = 0
	_received_zones.clear()
	EventBus.store_exited.emit(&"sports")
	assert_eq(
		_manager.get_current_key(),
		&"hallway",
		"store_exited must trigger swap_environment back to hallway"
	)


func test_store_exited_emits_environment_changed_with_hallway() -> void:
	EventBus.store_entered.emit(&"electronics")
	_signal_count = 0
	_received_zones.clear()
	EventBus.store_exited.emit(&"electronics")
	assert_eq(_signal_count, 1, "store_exited must cause environment_changed to emit once")
	if _received_zones.size() > 0:
		assert_eq(
			_received_zones[0],
			&"hallway",
			"environment_changed must carry &\"hallway\" after store_exited"
		)
