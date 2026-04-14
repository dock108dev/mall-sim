## GUT unit tests for StoreSelectorSystem — state transitions, guard conditions,
## and signal emissions during store enter and exit flows.
extends GutTest

const _STORE_ID: StringName = &"retro_games"
const _STORE_SCENE_PATH: String = "res://game/scenes/stores/retro_games.tscn"
const _PlayerControllerScene: PackedScene = preload(
	"res://game/scenes/player/player_controller.tscn"
)

var _system: StoreSelectorSystem
var _store_state: StoreStateManager
var _hallway_node: Node3D
var _store_container: Node3D
var _hallway_camera: PlayerController
var _ui_layer: CanvasLayer

var _store_opened: Array[String] = []
var _store_closed: Array[String] = []
var _active_store_changed: Array[StringName] = []
var _store_entered: Array[StringName] = []
var _store_exited: Array[StringName] = []
var _cameras_changed: Array[Camera3D] = []

var _saved_game_store_id: StringName


func before_each() -> void:
	_saved_game_store_id = GameManager.current_store_id
	GameManager.current_store_id = &""

	_system = StoreSelectorSystem.new()
	add_child_autofree(_system)

	_store_opened.clear()
	_store_closed.clear()
	_active_store_changed.clear()
	_store_entered.clear()
	_store_exited.clear()
	_cameras_changed.clear()

	EventBus.store_opened.connect(_on_store_opened)
	EventBus.store_closed.connect(_on_store_closed)
	EventBus.active_store_changed.connect(_on_active_store_changed)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)
	EventBus.active_camera_changed.connect(_on_active_camera_changed)


func after_each() -> void:
	GameManager.current_store_id = _saved_game_store_id
	_safe_disconnect(EventBus.store_opened, _on_store_opened)
	_safe_disconnect(EventBus.store_closed, _on_store_closed)
	_safe_disconnect(EventBus.active_store_changed, _on_active_store_changed)
	_safe_disconnect(EventBus.store_entered, _on_store_entered)
	_safe_disconnect(EventBus.store_exited, _on_store_exited)
	_safe_disconnect(EventBus.active_camera_changed, _on_active_camera_changed)


# ── Helpers ───────────────────────────────────────────────────────────────────


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _init_system() -> void:
	_store_state = StoreStateManager.new()
	add_child_autofree(_store_state)
	_hallway_node = Node3D.new()
	add_child_autofree(_hallway_node)
	_store_container = Node3D.new()
	add_child_autofree(_store_container)
	_hallway_camera = _PlayerControllerScene.instantiate() as PlayerController
	add_child_autofree(_hallway_camera)
	_ui_layer = CanvasLayer.new()
	add_child_autofree(_ui_layer)
	_system.initialize(
		_store_state, _hallway_node, _store_container, _hallway_camera, _ui_layer
	)
	# Nullify the fade rect so fade helpers return immediately without tween
	# delays, making enter/exit transitions synchronous in tests.
	_system._fade_rect = null


func _ensure_store_registered() -> void:
	if not ContentRegistry.exists(String(_STORE_ID)):
		ContentRegistry.register_entry(
			{"id": String(_STORE_ID), "name": "Retro Games",
			"scene_path": _STORE_SCENE_PATH},
			"store"
		)


# ── 1. Initial state ──────────────────────────────────────────────────────────


func test_is_inside_store_returns_false_before_any_transition() -> void:
	assert_false(
		_system.is_inside_store(),
		"is_inside_store() must return false before any store is entered"
	)


func test_get_active_store_scene_returns_null_before_any_transition() -> void:
	assert_null(
		_system.get_active_store_scene(),
		"get_active_store_scene() must return null before any store is entered"
	)


# ── 2. enter_store — unknown store_id ────────────────────────────────────────


func test_enter_unknown_store_does_not_change_inside_state() -> void:
	_init_system()
	EventBus.enter_store_requested.emit(&"bad_store")
	assert_false(
		_system.is_inside_store(),
		"Unknown store_id must not set inside state to true"
	)


func test_enter_unknown_store_does_not_emit_store_entered() -> void:
	_init_system()
	EventBus.enter_store_requested.emit(&"bad_store")
	assert_eq(
		_store_entered.size(), 0,
		"store_entered must not be emitted for unknown store_id"
	)


func test_enter_unknown_store_does_not_emit_active_store_changed() -> void:
	_init_system()
	EventBus.enter_store_requested.emit(&"bad_store")
	assert_eq(
		_active_store_changed.size(), 0,
		"active_store_changed must not be emitted for unknown store_id"
	)


# ── 3. Transitioning guard ────────────────────────────────────────────────────


func test_enter_while_transitioning_does_not_emit_store_entered() -> void:
	_init_system()
	_system._is_transitioning = true
	EventBus.enter_store_requested.emit(_STORE_ID)
	assert_eq(
		_store_entered.size(), 0,
		"enter_store_requested must be ignored while _is_transitioning is true"
	)
	_system._is_transitioning = false


func test_enter_while_transitioning_does_not_change_inside_state() -> void:
	_init_system()
	_system._is_transitioning = true
	EventBus.enter_store_requested.emit(_STORE_ID)
	assert_false(
		_system.is_inside_store(),
		"_inside_store must remain false when transition guard blocks entry"
	)
	_system._is_transitioning = false


# ── 4. exit_store — not inside guard ─────────────────────────────────────────


func test_exit_when_not_inside_store_does_not_emit_store_closed() -> void:
	_init_system()
	EventBus.exit_store_requested.emit()
	assert_eq(
		_store_closed.size(), 0,
		"exit_store_requested while not inside must not emit store_closed"
	)


func test_exit_when_not_inside_store_leaves_inside_state_false() -> void:
	_init_system()
	EventBus.exit_store_requested.emit()
	assert_false(
		_system.is_inside_store(),
		"_inside_store must remain false after exit while not inside"
	)


# ── 5. exit_store — transitioning guard ──────────────────────────────────────


func test_exit_while_transitioning_leaves_inside_state_unchanged() -> void:
	_init_system()
	_system._inside_store = true
	_system._is_transitioning = true
	EventBus.exit_store_requested.emit()
	assert_true(
		_system.is_inside_store(),
		"exit_store_requested while transitioning must not clear inside state"
	)
	_system._inside_store = false
	_system._is_transitioning = false


func test_exit_while_transitioning_does_not_emit_store_closed() -> void:
	_init_system()
	_system._inside_store = true
	_system._is_transitioning = true
	EventBus.exit_store_requested.emit()
	assert_eq(
		_store_closed.size(), 0,
		"exit_store_requested while transitioning must not emit store_closed"
	)
	_system._inside_store = false
	_system._is_transitioning = false


# ── 6. select_store — ownership and guard validation ─────────────────────────


func test_select_store_empty_id_is_noop() -> void:
	_init_system()
	_system.select_store(&"")
	assert_eq(
		_active_store_changed.size(), 0,
		"select_store with empty id must not emit active_store_changed"
	)


func test_select_store_unowned_store_is_noop() -> void:
	_init_system()
	_system.select_store(_STORE_ID)
	assert_eq(
		_active_store_changed.size(), 0,
		"select_store for unowned store must not emit active_store_changed"
	)


func test_select_owned_store_emits_active_store_changed() -> void:
	_init_system()
	_store_state.lease_store(0, _STORE_ID, _STORE_ID)
	_active_store_changed.clear()
	_system.select_store(_STORE_ID)
	assert_eq(
		_active_store_changed.size(), 1,
		"select_store must emit active_store_changed once for an owned store"
	)
	assert_eq(
		_active_store_changed[0], _STORE_ID,
		"active_store_changed must carry the selected store_id"
	)


func test_select_same_owned_store_twice_does_not_re_emit() -> void:
	_init_system()
	_store_state.lease_store(0, _STORE_ID, _STORE_ID)
	_system.select_store(_STORE_ID)
	_active_store_changed.clear()
	_system.select_store(_STORE_ID)
	assert_eq(
		_active_store_changed.size(), 0,
		"Selecting the already-active store must not re-emit active_store_changed"
	)


# ── 7. Full enter transition (requires ContentRegistry) ───────────────────────


func test_enter_valid_store_sets_inside_state() -> void:
	_ensure_store_registered()
	_init_system()
	EventBus.enter_store_requested.emit(_STORE_ID)
	# Two frames: one for each await (_fade_in, _fade_out) in the coroutine.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(
		_system.is_inside_store(),
		"is_inside_store() must return true after a successful enter transition"
	)


func test_enter_valid_store_emits_store_entered() -> void:
	_ensure_store_registered()
	_init_system()
	EventBus.enter_store_requested.emit(_STORE_ID)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(
		_store_entered.size() > 0,
		"store_entered must be emitted after a successful enter transition"
	)
	if _store_entered.size() > 0:
		assert_eq(
			_store_entered[0], _STORE_ID,
			"store_entered must carry the entered store_id"
		)


func test_enter_valid_store_emits_active_store_changed() -> void:
	_ensure_store_registered()
	_init_system()
	EventBus.enter_store_requested.emit(_STORE_ID)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(
		_active_store_changed.size() > 0,
		"active_store_changed must be emitted after a successful enter transition"
	)
	if _active_store_changed.size() > 0:
		assert_eq(
			_active_store_changed[0], _STORE_ID,
			"active_store_changed must carry the entered store_id"
		)


# ── 8. Full exit transition (requires ContentRegistry) ────────────────────────


func test_exit_after_enter_clears_inside_state() -> void:
	_ensure_store_registered()
	_init_system()
	EventBus.enter_store_requested.emit(_STORE_ID)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _system.is_inside_store():
		pending("Enter transition did not complete — skipping exit test")
		return
	EventBus.exit_store_requested.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(
		_system.is_inside_store(),
		"is_inside_store() must return false after exiting a store"
	)


func test_exit_after_enter_emits_store_closed() -> void:
	_ensure_store_registered()
	_init_system()
	EventBus.enter_store_requested.emit(_STORE_ID)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _system.is_inside_store():
		pending("Enter transition did not complete — skipping exit test")
		return
	_store_closed.clear()
	EventBus.exit_store_requested.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(
		_store_closed.size() > 0,
		"store_closed must be emitted after exiting a store"
	)
	if _store_closed.size() > 0:
		assert_eq(
			_store_closed[0], String(_STORE_ID),
			"store_closed must carry the exited store_id"
		)


func test_exit_after_enter_emits_active_store_changed_empty() -> void:
	_ensure_store_registered()
	_init_system()
	EventBus.enter_store_requested.emit(_STORE_ID)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _system.is_inside_store():
		pending("Enter transition did not complete — skipping exit test")
		return
	_active_store_changed.clear()
	EventBus.exit_store_requested.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(
		_active_store_changed.size() > 0,
		"active_store_changed must be emitted after exiting a store"
	)
	if _active_store_changed.size() > 0:
		assert_eq(
			_active_store_changed[0], &"",
			"active_store_changed must carry empty StringName after store exit"
		)


# ── Signal callbacks ──────────────────────────────────────────────────────────


func _on_store_opened(store_id: String) -> void:
	_store_opened.append(store_id)


func _on_store_closed(store_id: String) -> void:
	_store_closed.append(store_id)


func _on_active_store_changed(store_id: StringName) -> void:
	_active_store_changed.append(store_id)


func _on_store_entered(store_id: StringName) -> void:
	_store_entered.append(store_id)


func _on_store_exited(store_id: StringName) -> void:
	_store_exited.append(store_id)


func _on_active_camera_changed(camera: Camera3D) -> void:
	_cameras_changed.append(camera)
