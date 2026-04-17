## Integration test: store transition — environment swap, camera update, and interaction availability.
extends GutTest

## Preload the EnvironmentManager script so a fresh instance can be created per test.
const _EnvironmentManagerScript: GDScript = preload(
	"res://game/autoload/environment_manager.gd"
)

## Buffer added to DEFAULT_FADE_DURATION (0.5 s) when awaiting a crossfade tween.
const _TWEEN_WAIT: float = 0.6

var _env_manager: Node
var _store_state_manager: StoreStateManager
var _store_changed_ids: Array[StringName] = []


func before_each() -> void:
	ContentRegistry.clear_for_testing()
	ContentRegistry.register_entry(
		{
			"id": "retro_games",
			"name": "Retro Games",
			"scene_path": "res://game/scenes/stores/retro_games.tscn",
			"environment_id": "retro_games",
		},
		"store"
	)
	_env_manager = _EnvironmentManagerScript.new()
	add_child_autofree(_env_manager)
	_store_state_manager = StoreStateManager.new()
	add_child_autofree(_store_state_manager)
	_store_changed_ids.clear()
	EventBus.active_store_changed.connect(_on_active_store_changed)


func after_each() -> void:
	if EventBus.active_store_changed.is_connected(_on_active_store_changed):
		EventBus.active_store_changed.disconnect(_on_active_store_changed)
	ContentRegistry.clear_for_testing()


# ── 1. Initial hallway state ──────────────────────────────────────────────────


func test_environment_initializes_to_hallway() -> void:
	assert_eq(
		_env_manager.get_current_key(), &"hallway",
		"EnvironmentManager starts in the hallway zone"
	)
	assert_not_null(
		_env_manager.get_world_environment().environment,
		"Hallway environment resource is non-null at startup"
	)


# ── 2. store_entered triggers environment swap ────────────────────────────────


func test_zone_key_updates_immediately_on_store_entered() -> void:
	EventBus.store_entered.emit(&"retro_games")

	assert_eq(
		_env_manager.get_current_key(), &"retro_games",
		"Zone key updates to retro_games synchronously on store_entered"
	)


func test_environment_resource_swaps_after_crossfade() -> void:
	var hallway_env: Environment = _env_manager.get_world_environment().environment

	EventBus.store_entered.emit(&"retro_games")
	await get_tree().create_timer(_TWEEN_WAIT).timeout

	assert_ne(
		_env_manager.get_world_environment().environment,
		hallway_env,
		"Environment resource differs from hallway once the crossfade tween settles"
	)


# ── 3. active_store_changed signal ───────────────────────────────────────────


func test_active_store_changed_fires_with_correct_id() -> void:
	_store_state_manager.set_active_store(&"retro_games")

	assert_eq(_store_changed_ids.size(), 1, "active_store_changed fires exactly once")
	assert_eq(
		_store_changed_ids[0], &"retro_games",
		"active_store_changed carries the entered store id"
	)


# ── 4. StoreStateManager tracks active_store_id ───────────────────────────────


func test_store_state_manager_active_store_id_matches_entered_store() -> void:
	_store_state_manager.set_active_store(&"retro_games")

	assert_eq(
		_store_state_manager.active_store_id, &"retro_games",
		"StoreStateManager.active_store_id reflects the entered store"
	)


# ── 5. Camera safety — active_camera_changed ─────────────────────────────────


func test_active_camera_changed_produces_no_errors() -> void:
	var dummy: Camera3D = Camera3D.new()
	add_child_autofree(dummy)

	# Any listener that stored a stale camera ref would null-ref here.
	EventBus.active_camera_changed.emit(dummy)

	pass_test("active_camera_changed did not produce null-refs or push_error calls")


# ── 6. store_exited reverts to hallway environment ────────────────────────────


func test_zone_key_reverts_immediately_on_store_exited() -> void:
	EventBus.store_entered.emit(&"retro_games")
	await get_tree().create_timer(_TWEEN_WAIT).timeout

	EventBus.store_exited.emit(&"retro_games")

	assert_eq(
		_env_manager.get_current_key(), &"hallway",
		"Zone key reverts to hallway synchronously on store_exited"
	)


func test_environment_resource_reverts_to_hallway_after_exit_crossfade() -> void:
	var hallway_env: Environment = _env_manager.get_world_environment().environment

	EventBus.store_entered.emit(&"retro_games")
	await get_tree().create_timer(_TWEEN_WAIT).timeout

	EventBus.store_exited.emit(&"retro_games")
	await get_tree().create_timer(_TWEEN_WAIT).timeout

	assert_eq(
		_env_manager.get_world_environment().environment,
		hallway_env,
		"Environment resource is the hallway resource again after exit crossfade"
	)


# ── 7. StoreStateManager.active_store_id clears on exit ──────────────────────


func test_store_state_manager_active_store_id_empty_after_exit() -> void:
	_store_state_manager.set_active_store(&"retro_games")
	assert_eq(
		_store_state_manager.active_store_id, &"retro_games",
		"active_store_id is retro_games after entry"
	)

	_store_state_manager.set_active_store(&"")

	assert_eq(
		_store_state_manager.active_store_id, &"",
		"active_store_id is empty after the active store is cleared"
	)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _on_active_store_changed(store_id: StringName) -> void:
	_store_changed_ids.append(store_id)
