## GUT unit tests for StoreSelectorSystem signal contracts and scene path lookup.
extends GutTest


class TestStoreSelectorSystem extends StoreSelectorSystem:
	var error_messages: Array[String] = []

	func _push_system_error(message: String) -> void:
		error_messages.append(message)


const _STORE_ID: StringName = &"sports"
const _UNKNOWN_STORE_ID: StringName = &"unknown_store"
const _STORE_SCENE_PATH: String = "res://game/scenes/stores/sports_memorabilia.tscn"

var _system: TestStoreSelectorSystem
var _saved_current_store_id: StringName = &""
var _valid_zone_player: AudioStreamPlayer
var _unknown_zone_player: AudioStreamPlayer


func before_each() -> void:
	_saved_current_store_id = GameManager.current_store_id
	GameManager.current_store_id = &""
	ContentRegistry.clear_for_testing()
	ContentRegistry.register_entry(
		{
			"id": String(_STORE_ID),
			"name": "Sports",
			"scene_path": _STORE_SCENE_PATH,
		},
		"store"
	)

	_valid_zone_player = AudioStreamPlayer.new()
	add_child_autofree(_valid_zone_player)
	AudioManager.register_zone(String(_STORE_ID), _valid_zone_player)

	_unknown_zone_player = AudioStreamPlayer.new()
	add_child_autofree(_unknown_zone_player)
	AudioManager.register_zone(String(_UNKNOWN_STORE_ID), _unknown_zone_player)

	_system = TestStoreSelectorSystem.new()
	add_child_autofree(_system)
	_disconnect_autoload_listeners()
	watch_signals(EventBus)


func after_each() -> void:
	_restore_autoload_listeners()
	AudioManager.unregister_zone(String(_STORE_ID))
	AudioManager.unregister_zone(String(_UNKNOWN_STORE_ID))
	GameManager.current_store_id = _saved_current_store_id
	ContentRegistry.clear_for_testing()


func test_store_entered_emits_active_store_changed_for_valid_store() -> void:
	EventBus.store_entered.emit(_STORE_ID)

	assert_signal_emitted(EventBus, "active_store_changed")
	assert_signal_emitted_with_parameters(
		EventBus, "active_store_changed", [_STORE_ID]
	)


func test_unknown_store_entry_records_error_without_active_store_change() -> void:
	EventBus.store_entered.emit(_UNKNOWN_STORE_ID)

	assert_eq(
		_system.error_messages.size(), 1,
		"Unknown store entry should record a single error"
	)
	assert_true(
		_system.error_messages[0].contains(String(_UNKNOWN_STORE_ID)),
		"Error message should include the unknown store id"
	)
	assert_signal_not_emitted(
		EventBus,
		"active_store_changed",
		"Unknown store entry must not emit active_store_changed"
	)
	assert_eq(
		_system.get_active_store_id(), &"",
		"Unknown store entry should leave the active store empty"
	)


func test_get_active_store_id_returns_store_after_store_entered() -> void:
	EventBus.store_entered.emit(_STORE_ID)

	assert_eq(
		_system.get_active_store_id(), _STORE_ID,
		"get_active_store_id should return the current store id"
	)


func test_store_exited_clears_active_store_identity() -> void:
	EventBus.store_entered.emit(_STORE_ID)
	EventBus.store_exited.emit(_STORE_ID)

	assert_eq(
		_system.get_active_store_id(), &"",
		"store_exited should clear the active store id"
	)


func test_get_store_scene_path_matches_content_registry() -> void:
	assert_eq(
		_system.get_store_scene_path(_STORE_ID),
		ContentRegistry.get_scene_path(_STORE_ID),
		"get_store_scene_path should match ContentRegistry"
	)


func _disconnect_autoload_listeners() -> void:
	_disconnect_listener(
		EventBus.store_entered,
		Callable(EnvironmentManager, "_on_store_entered")
	)
	_disconnect_listener(
		EventBus.store_exited,
		Callable(EnvironmentManager, "_on_store_exited")
	)
	_disconnect_listener(
		EventBus.store_entered,
		Callable(CameraManager, "_on_store_entered")
	)
	_disconnect_listener(
		EventBus.store_exited,
		Callable(CameraManager, "_on_store_exited")
	)


func _restore_autoload_listeners() -> void:
	_connect_listener(
		EventBus.store_entered,
		Callable(EnvironmentManager, "_on_store_entered")
	)
	_connect_listener(
		EventBus.store_exited,
		Callable(EnvironmentManager, "_on_store_exited")
	)
	_connect_listener(
		EventBus.store_entered,
		Callable(CameraManager, "_on_store_entered")
	)
	_connect_listener(
		EventBus.store_exited,
		Callable(CameraManager, "_on_store_exited")
	)


func _disconnect_listener(signal_ref: Signal, callable: Callable) -> void:
	if signal_ref.is_connected(callable):
		signal_ref.disconnect(callable)


func _connect_listener(signal_ref: Signal, callable: Callable) -> void:
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)
