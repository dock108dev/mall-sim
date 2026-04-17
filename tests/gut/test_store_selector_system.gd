## Tests for StoreSelectorSystem scene transition orchestration.
extends GutTest


class TestStoreSelectorSystem extends StoreSelectorSystem:
	var error_messages: Array[String] = []

	func _push_system_error(message: String) -> void:
		error_messages.append(message)


const _PlayerControllerScene: PackedScene = preload(
	"res://game/scenes/player/player_controller.tscn"
)

var _system: TestStoreSelectorSystem
var _store_state_manager: StoreStateManager
var _hallway_node: Node3D
var _store_container: Node3D
var _hallway_camera: PlayerController
var _ui_layer: CanvasLayer
var _entered_stores: Array[StringName] = []
var _exited_stores: Array[StringName] = []
var _active_store_changed_ids: Array[StringName] = []
var _storefront_entered_calls: Array[Dictionary] = []
var _storefront_exited_count: int = 0
var _zone_player: AudioStreamPlayer

const TEST_STORE_ID: StringName = &"retro_games"
const TEST_SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const TEST_STORE_ENTRY: Dictionary = {
	"id": "retro_games",
	"name": "Retro Games",
	"scene_path": "res://game/scenes/stores/retro_games.tscn",
}


func before_each() -> void:
	ContentRegistry.clear_for_testing()
	ContentRegistry.register_entry(TEST_STORE_ENTRY, "store")
	_entered_stores.clear()
	_exited_stores.clear()
	_active_store_changed_ids.clear()
	_storefront_entered_calls.clear()
	_storefront_exited_count = 0

	_store_state_manager = StoreStateManager.new()
	add_child_autofree(_store_state_manager)

	_hallway_node = Node3D.new()
	_hallway_node.name = "HallwayGeometry"
	add_child_autofree(_hallway_node)

	_store_container = Node3D.new()
	_store_container.name = "StoreContainer"
	add_child_autofree(_store_container)

	_hallway_camera = _PlayerControllerScene.instantiate() as PlayerController
	_hallway_camera.name = "HallwayCamera"
	add_child_autofree(_hallway_camera)

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UILayer"
	add_child_autofree(_ui_layer)

	_zone_player = AudioStreamPlayer.new()
	add_child_autofree(_zone_player)
	AudioManager.register_zone(String(TEST_STORE_ID), _zone_player)

	_system = TestStoreSelectorSystem.new()
	_system.name = "StoreSelectorSystem"
	add_child_autofree(_system)

	CameraManager._store_cameras.clear()
	CameraManager.register_hallway_camera(_hallway_camera.get_camera())

	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)
	EventBus.active_store_changed.connect(_on_active_store_changed)
	EventBus.storefront_entered.connect(_on_storefront_entered)
	EventBus.storefront_exited.connect(_on_storefront_exited)


func after_each() -> void:
	if EventBus.store_entered.is_connected(_on_store_entered):
		EventBus.store_entered.disconnect(_on_store_entered)
	if EventBus.store_exited.is_connected(_on_store_exited):
		EventBus.store_exited.disconnect(_on_store_exited)
	if EventBus.active_store_changed.is_connected(
		_on_active_store_changed
	):
		EventBus.active_store_changed.disconnect(
			_on_active_store_changed
		)
	if EventBus.storefront_entered.is_connected(
		_on_storefront_entered
	):
		EventBus.storefront_entered.disconnect(
			_on_storefront_entered
		)
	if EventBus.storefront_exited.is_connected(
		_on_storefront_exited
	):
		EventBus.storefront_exited.disconnect(_on_storefront_exited)
	AudioManager.unregister_zone(String(TEST_STORE_ID))
	ContentRegistry.clear_for_testing()


func test_is_inside_store_initially_false() -> void:
	assert_false(
		_system.is_inside_store(),
		"Should not be inside a store initially"
	)


func test_get_active_store_scene_initially_null() -> void:
	assert_null(
		_system.get_active_store_scene(),
		"Active store scene should be null initially"
	)


func test_exit_store_requested_ignored_when_not_inside() -> void:
	_system.initialize(
		_store_state_manager,
		_hallway_node,
		_store_container,
		_hallway_camera,
		_ui_layer
	)
	EventBus.exit_store_requested.emit()
	assert_false(
		_system.is_inside_store(),
		"Should remain outside store when exit requested while not inside"
	)
	assert_eq(
		_exited_stores.size(), 0,
		"No store_exited signal should be emitted"
	)


func test_enter_store_invalid_id_logs_error() -> void:
	_system.initialize(
		_store_state_manager,
		_hallway_node,
		_store_container,
		_hallway_camera,
		_ui_layer
	)
	EventBus.enter_store_requested.emit(&"nonexistent_store_xyz")
	assert_false(
		_system.is_inside_store(),
		"Should not enter store with invalid ID"
	)
	assert_eq(
		_entered_stores.size(), 0,
		"No store_entered signal for invalid store"
	)
	assert_eq(
		_active_store_changed_ids.size(), 0,
		"No active_store_changed signal for invalid store"
	)


func test_set_active_store_emits_active_store_changed() -> void:
	_store_state_manager.set_active_store(TEST_STORE_ID)
	assert_eq(
		_active_store_changed_ids.size(), 1,
		"active_store_changed should be emitted once"
	)
	assert_eq(
		_active_store_changed_ids[0], TEST_STORE_ID,
		"active_store_changed should carry the correct store_id"
	)


func test_set_active_store_emits_store_entered() -> void:
	_store_state_manager.set_active_store(TEST_STORE_ID)
	assert_eq(
		_entered_stores.size(), 1,
		"store_entered should be emitted"
	)
	assert_eq(_entered_stores[0], TEST_STORE_ID)


func test_get_active_store_id_returns_correct_id() -> void:
	_store_state_manager.set_active_store(TEST_STORE_ID)
	assert_eq(
		_store_state_manager.active_store_id, TEST_STORE_ID,
		"active_store_id should match the store that was set"
	)


func test_store_exited_clears_active_store_identity() -> void:
	_store_state_manager.set_active_store(TEST_STORE_ID)
	_active_store_changed_ids.clear()
	_exited_stores.clear()

	_store_state_manager.set_active_store(&"")
	assert_eq(
		_store_state_manager.active_store_id, &"",
		"active_store_id should be empty after clearing"
	)
	assert_eq(
		_exited_stores.size(), 1,
		"store_exited should be emitted when clearing active store"
	)
	assert_eq(
		_exited_stores[0], TEST_STORE_ID,
		"store_exited should carry the previous store_id"
	)
	assert_eq(
		_active_store_changed_ids.size(), 1,
		"active_store_changed should fire with empty id"
	)
	assert_eq(
		_active_store_changed_ids[0], &"",
		"active_store_changed should carry empty StringName"
	)


func test_scene_path_matches_content_registry() -> void:
	var path: String = ContentRegistry.get_scene_path(TEST_STORE_ID)
	assert_eq(
		path, TEST_SCENE_PATH,
		"Scene path from ContentRegistry should match definition"
	)


func test_scene_path_empty_for_unknown_id() -> void:
	var path: String = ContentRegistry.get_scene_path(
		&"totally_unknown_id"
	)
	assert_eq(
		path, "",
		"Scene path should be empty for unknown store ID"
	)


func test_hallway_visible_initially() -> void:
	assert_true(
		_hallway_node.visible,
		"Hallway should be visible initially"
	)


func _on_store_entered(store_id: StringName) -> void:
	_entered_stores.append(store_id)


func _on_store_exited(store_id: StringName) -> void:
	_exited_stores.append(store_id)


func _on_active_store_changed(store_id: StringName) -> void:
	_active_store_changed_ids.append(store_id)


func _on_storefront_entered(
	slot_index: int, store_id: String
) -> void:
	_storefront_entered_calls.append({
		"slot_index": slot_index,
		"store_id": store_id,
	})


func _on_storefront_exited() -> void:
	_storefront_exited_count += 1
