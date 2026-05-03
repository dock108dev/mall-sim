## Tests for StoreStateManager slot ownership, active store, and serialization.
extends GutTest


var _manager: StoreStateManager
var _lease_results: Array[Dictionary] = []
var _store_changed: Array[StringName] = []
var _store_entered: Array[StringName] = []
var _store_exited: Array[StringName] = []


func before_each() -> void:
	ContentRegistry.clear_for_testing()
	ContentRegistry.register_entry(
		{"id": "sports", "name": "Sports", "environment_id": "sports_memorabilia"},
		"store"
	)
	ContentRegistry.register_entry(
		{"id": "retro_games", "name": "Retro Games", "environment_id": "retro_games"},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "electronics",
			"name": "Electronics",
			"environment_id": "electronics",
		},
		"store"
	)
	_manager = StoreStateManager.new()
	_lease_results.clear()
	_store_changed.clear()
	_store_entered.clear()
	_store_exited.clear()
	EventBus.lease_completed.connect(_on_lease_completed)
	EventBus.active_store_changed.connect(_on_active_store_changed)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)


func after_each() -> void:
	EventBus.lease_completed.disconnect(_on_lease_completed)
	EventBus.active_store_changed.disconnect(_on_active_store_changed)
	EventBus.store_entered.disconnect(_on_store_entered)
	EventBus.store_exited.disconnect(_on_store_exited)
	ContentRegistry.clear_for_testing()
	_manager.free()


func test_lease_store_records_ownership() -> void:
	var result: bool = _manager.lease_store(0, &"sports", &"sports_memorabilia")
	assert_true(result, "lease_store should return true for new slot")
	assert_true(
		_manager.owned_slots.has(0),
		"Slot 0 should be in owned_slots"
	)
	assert_eq(
		_manager.owned_slots[0], &"sports",
		"Slot 0 should map to sports"
	)


func test_lease_store_emits_success() -> void:
	_manager.lease_store(0, &"sports", &"sports_memorabilia")
	assert_eq(
		_lease_results.size(), 1,
		"Should emit one lease_completed signal"
	)
	assert_eq(_lease_results[0]["store_id"], &"sports")
	assert_true(_lease_results[0]["success"] as bool)
	assert_eq(_lease_results[0]["message"], "")


func test_lease_store_rejects_owned_slot() -> void:
	_manager.lease_store(0, &"sports", &"sports_memorabilia")
	_lease_results.clear()

	var result: bool = _manager.lease_store(
		0, &"retro_games", &"retro_games"
	)
	assert_false(result, "lease_store should return false for owned slot")
	assert_eq(
		_lease_results.size(), 1,
		"Should emit failure lease_completed"
	)
	assert_false(_lease_results[0]["success"] as bool)
	assert_true(
		(_lease_results[0]["message"] as String).length() > 0,
		"Failure message should not be empty"
	)


func test_lease_store_records_store_type() -> void:
	_manager.lease_store(0, &"sports", &"sports_memorabilia")
	assert_eq(
		_manager.get_store_type(&"sports"), &"sports_memorabilia",
		"Store type should be recorded"
	)


func test_set_active_store_emits_changed() -> void:
	_manager.set_active_store(&"sports")
	assert_eq(
		_store_changed.size(), 1,
		"Should emit active_store_changed"
	)
	assert_eq(_store_changed[0], &"sports")
	assert_eq(
		_manager.active_store_id, &"sports",
		"active_store_id should be updated"
	)


func test_set_active_store_emits_entered() -> void:
	_manager.set_active_store(&"sports")
	assert_eq(
		_store_entered.size(), 1,
		"Should emit store_entered"
	)
	assert_eq(_store_entered[0], &"sports")


func test_set_active_store_emits_exited_on_switch() -> void:
	_manager.set_active_store(&"sports")
	_store_entered.clear()
	_store_exited.clear()

	_manager.set_active_store(&"retro_games")
	assert_eq(
		_store_exited.size(), 1,
		"Should emit store_exited for previous store"
	)
	assert_eq(_store_exited[0], &"sports")
	assert_eq(
		_store_entered.size(), 1,
		"Should emit store_entered for new store"
	)
	assert_eq(_store_entered[0], &"retro_games")


func test_set_active_store_with_emit_false_suppresses_entered() -> void:
	# Hub auto-enter path: GameWorld._on_store_entered calls
	# set_active_store(id, false) after the store_entered signal already
	# fired upstream. The flag must suppress a second store_entered emission
	# while still updating active_store_id and emitting active_store_changed.
	_manager.set_active_store(&"sports", false)
	assert_eq(
		_store_entered.size(), 0,
		"set_active_store(_, false) must not emit store_entered"
	)
	assert_eq(
		_store_changed.size(), 1,
		"set_active_store(_, false) must still emit active_store_changed once"
	)
	assert_eq(_store_changed[0], &"sports")
	assert_eq(
		_manager.active_store_id, &"sports",
		"active_store_id must be set even when transition events are suppressed"
	)


func test_set_active_store_with_emit_false_suppresses_exited_on_switch() -> void:
	_manager.set_active_store(&"sports")
	_store_entered.clear()
	_store_exited.clear()
	_store_changed.clear()

	_manager.set_active_store(&"retro_games", false)
	assert_eq(
		_store_exited.size(), 0,
		"set_active_store(_, false) must not emit store_exited on switch"
	)
	assert_eq(
		_store_entered.size(), 0,
		"set_active_store(_, false) must not emit store_entered on switch"
	)
	assert_eq(
		_manager.active_store_id, &"retro_games",
		"active_store_id must update to the new store"
	)


func test_set_active_store_empty_emits_exited() -> void:
	_manager.set_active_store(&"sports")
	_store_exited.clear()

	_manager.set_active_store(&"")
	assert_eq(
		_store_exited.size(), 1,
		"Should emit store_exited when returning to hallway"
	)
	assert_eq(_store_exited[0], &"sports")


func test_is_owned_returns_true_for_owned() -> void:
	_manager.lease_store(2, &"electronics", &"consumer_electronics")
	assert_true(
		_manager.is_owned(2),
		"is_owned should return true for leased slot"
	)


func test_is_owned_returns_false_for_unowned() -> void:
	assert_false(
		_manager.is_owned(5),
		"is_owned should return false for unleased slot"
	)


func test_get_store_type_returns_empty_for_unknown() -> void:
	assert_eq(
		_manager.get_store_type(&"nonexistent"), &"",
		"get_store_type should return empty for unknown store"
	)


func test_serialize_roundtrip() -> void:
	_manager.lease_store(0, &"sports", &"sports_memorabilia")
	_manager.lease_store(1, &"retro_games", &"retro_games")

	var saved: Dictionary = _manager.serialize()
	assert_true(saved.has("owned_slots"), "Should have owned_slots")
	assert_true(saved.has("store_types"), "Should have store_types")

	var new_manager: StoreStateManager = StoreStateManager.new()
	new_manager.deserialize(saved)
	assert_eq(
		new_manager.owned_slots.size(),
		_manager.owned_slots.size(),
		"Deserialized owned_slots should match"
	)
	assert_eq(
		new_manager.store_types.size(),
		_manager.store_types.size(),
		"Deserialized store_types should match"
	)
	new_manager.free()


func test_serialize_deserialize_roundtrip_preserves_state() -> void:
	_manager.lease_store(0, &"sports", &"sports_memorabilia")
	_manager.lease_store(2, &"electronics", &"consumer_electronics")

	var saved: Dictionary = _manager.serialize()

	var restored: StoreStateManager = StoreStateManager.new()
	restored.deserialize(saved)

	assert_true(restored.is_owned(0), "Slot 0 should be owned")
	assert_true(restored.is_owned(2), "Slot 2 should be owned")
	assert_false(restored.is_owned(1), "Slot 1 should not be owned")
	assert_eq(
		restored.get_store_type(&"sports"), &"sports_memorabilia"
	)
	assert_eq(
		restored.get_store_type(&"electronics"),
		&"consumer_electronics"
	)
	restored.free()


func _on_lease_completed(
	store_id: StringName, success: bool, message: String
) -> void:
	_lease_results.append({
		"store_id": store_id,
		"success": success,
		"message": message,
	})


func _on_active_store_changed(store_id: StringName) -> void:
	_store_changed.append(store_id)


func _on_store_entered(store_id: StringName) -> void:
	_store_entered.append(store_id)


func _on_store_exited(store_id: StringName) -> void:
	_store_exited.append(store_id)
