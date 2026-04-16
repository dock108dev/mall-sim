## GUT unit tests for StoreSelectorSystem.select_store — ownership guard and
## EventBus signal contracts.
extends GutTest


const STORE_A: StringName = &"sports"
const STORE_SLOT_A: int = 0


var _system: StoreSelectorSystem
var _state_manager: StoreStateManager
var _store_changed: Array[StringName] = []
var _saved_current_store_id: StringName = &""


func before_each() -> void:
	_saved_current_store_id = GameManager.current_store_id
	GameManager.current_store_id = &""
	ContentRegistry.clear_for_testing()
	ContentRegistry.register_entry(
		{
			"id": "sports",
			"name": "Sports",
		},
		"store"
	)
	_state_manager = StoreStateManager.new()
	add_child_autofree(_state_manager)
	_system = StoreSelectorSystem.new()
	_system._store_state_manager = _state_manager
	add_child_autofree(_system)
	_store_changed.clear()
	EventBus.active_store_changed.connect(_on_active_store_changed)


func after_each() -> void:
	if EventBus.active_store_changed.is_connected(_on_active_store_changed):
		EventBus.active_store_changed.disconnect(_on_active_store_changed)
	GameManager.current_store_id = _saved_current_store_id
	ContentRegistry.clear_for_testing()


## Owned store: active_store_changed fires with the correct store StringName.
func test_select_owned_store_emits_signal() -> void:
	_state_manager.owned_slots[STORE_SLOT_A] = STORE_A
	_system.select_store(STORE_A)
	assert_eq(
		_store_changed.size(), 1,
		"active_store_changed should fire once for an owned store"
	)
	assert_eq(
		_store_changed[0], STORE_A,
		"active_store_changed should carry the correct store_id"
	)


## Unowned store: signal does not fire; push_error is recorded.
func test_select_unowned_store_rejected() -> void:
	_system.select_store(STORE_A)
	assert_eq(
		_store_changed.size(), 0,
		"active_store_changed should not fire when store is not owned"
	)


## After a valid selection, StoreStateManager.active_store_id equals the
## selected id.
func test_active_store_id_updates_after_selection() -> void:
	_state_manager.owned_slots[STORE_SLOT_A] = STORE_A
	_system.select_store(STORE_A)
	assert_eq(
		_state_manager.active_store_id, STORE_A,
		"StoreStateManager.active_store_id should equal the selected store id"
	)


## Selecting the same owned store twice fires active_store_changed only once.
func test_selecting_same_store_is_no_op() -> void:
	_state_manager.owned_slots[STORE_SLOT_A] = STORE_A
	_system.select_store(STORE_A)
	_system.select_store(STORE_A)
	assert_eq(
		_store_changed.size(), 1,
		"active_store_changed should fire exactly once for duplicate selection"
	)


## An unrecognised id is rejected: push_error fires and no signal is emitted.
func test_select_invalid_id_is_rejected() -> void:
	_system.select_store(&"not_a_real_store")
	assert_eq(
		_store_changed.size(), 0,
		"active_store_changed should not fire for an unrecognised store id"
	)


func _on_active_store_changed(store_id: StringName) -> void:
	_store_changed.append(store_id)
