## GUT unit tests for StoreStateManager (referenced as StoreStateSystem in issue).
extends GutTest


var _manager: StoreStateManager
var _lease_results: Array[Dictionary] = []
var _store_changed: Array[StringName] = []
var _store_entered: Array[StringName] = []
var _store_exited: Array[StringName] = []


func before_each() -> void:
	_manager = StoreStateManager.new()
	add_child_autofree(_manager)
	_lease_results.clear()
	_store_changed.clear()
	_store_entered.clear()
	_store_exited.clear()
	EventBus.lease_completed.connect(_on_lease_completed)
	EventBus.active_store_changed.connect(_on_active_store_changed)
	EventBus.store_entered.connect(_on_store_entered)
	EventBus.store_exited.connect(_on_store_exited)


func after_each() -> void:
	if EventBus.lease_completed.is_connected(_on_lease_completed):
		EventBus.lease_completed.disconnect(_on_lease_completed)
	if EventBus.active_store_changed.is_connected(_on_active_store_changed):
		EventBus.active_store_changed.disconnect(_on_active_store_changed)
	if EventBus.store_entered.is_connected(_on_store_entered):
		EventBus.store_entered.disconnect(_on_store_entered)
	if EventBus.store_exited.is_connected(_on_store_exited):
		EventBus.store_exited.disconnect(_on_store_exited)


# ── 1. Initial state ────────────────────────────────────────────────────────


func test_initial_owned_slots_is_empty() -> void:
	assert_eq(
		_manager.owned_slots.size(), 0,
		"owned_slots should be empty on creation"
	)


func test_initial_active_store_id_is_empty() -> void:
	assert_eq(
		_manager.active_store_id, &"",
		"active_store_id should be empty StringName on creation"
	)


# ── 2. lease_store records ownership ────────────────────────────────────────


func test_lease_store_records_slot_ownership() -> void:
	_manager.lease_store(0, &"sports_memorabilia", &"sports_memorabilia")
	assert_true(
		_manager.owned_slots.has(0),
		"owned_slots should contain slot 0"
	)
	assert_eq(
		_manager.owned_slots[0], &"sports_memorabilia",
		"Slot 0 should map to sports_memorabilia"
	)


func test_lease_store_multiple_slots() -> void:
	_manager.lease_store(0, &"sports_memorabilia", &"sports_memorabilia")
	_manager.lease_store(1, &"retro_games", &"retro_games")
	assert_eq(
		_manager.owned_slots.size(), 2,
		"Should have two owned slots"
	)
	assert_eq(_manager.owned_slots[0], &"sports_memorabilia")
	assert_eq(_manager.owned_slots[1], &"retro_games")


func test_lease_store_emits_success_signal() -> void:
	_manager.lease_store(0, &"retro_games", &"retro_games")
	assert_eq(_lease_results.size(), 1)
	assert_eq(_lease_results[0]["store_id"], &"retro_games")
	assert_true(_lease_results[0]["success"] as bool)
	assert_eq(_lease_results[0]["message"], "")


# ── 3. Duplicate lease guard ────────────────────────────────────────────────


func test_duplicate_lease_rejects_and_does_not_overwrite() -> void:
	_manager.lease_store(0, &"sports_memorabilia", &"sports_memorabilia")
	_lease_results.clear()

	var result: bool = _manager.lease_store(
		0, &"retro_games", &"retro_games"
	)
	assert_false(result, "Should reject lease on already-owned slot")
	assert_eq(
		_manager.owned_slots[0], &"sports_memorabilia",
		"Original store should not be overwritten"
	)
	assert_eq(_lease_results.size(), 1)
	assert_false(_lease_results[0]["success"] as bool)
	assert_true(
		(_lease_results[0]["message"] as String).length() > 0,
		"Failure should include an error message"
	)


# ── 4. active_store_id update on set_active_store ───────────────────────────


func test_set_active_store_updates_id() -> void:
	_manager.set_active_store(&"retro_games")
	assert_eq(
		_manager.active_store_id, &"retro_games",
		"active_store_id should match the set store"
	)


func test_set_active_store_emits_store_entered() -> void:
	_manager.set_active_store(&"retro_games")
	assert_eq(_store_entered.size(), 1)
	assert_eq(_store_entered[0], &"retro_games")


func test_set_active_store_emits_active_store_changed() -> void:
	_manager.set_active_store(&"retro_games")
	assert_eq(_store_changed.size(), 1)
	assert_eq(_store_changed[0], &"retro_games")


# ── 5. active_store_id cleared on exit ──────────────────────────────────────


func test_set_active_store_empty_clears_id() -> void:
	_manager.set_active_store(&"retro_games")
	_manager.set_active_store(&"")
	assert_eq(
		_manager.active_store_id, &"",
		"active_store_id should be empty after clearing"
	)


func test_set_active_store_empty_emits_store_exited() -> void:
	_manager.set_active_store(&"retro_games")
	_store_exited.clear()
	_manager.set_active_store(&"")
	assert_eq(_store_exited.size(), 1)
	assert_eq(
		_store_exited[0], &"retro_games",
		"Should emit store_exited for the previous store"
	)


func test_switching_stores_emits_exit_then_enter() -> void:
	_manager.set_active_store(&"retro_games")
	_store_entered.clear()
	_store_exited.clear()

	_manager.set_active_store(&"video_rental")
	assert_eq(_store_exited.size(), 1)
	assert_eq(_store_exited[0], &"retro_games")
	assert_eq(_store_entered.size(), 1)
	assert_eq(_store_entered[0], &"video_rental")


# ── 6. Store name and type helpers ──────────────────────────────────────────


func test_set_store_name_records_custom_name() -> void:
	_manager.set_store_name(&"retro_games", "Mike's Retro Emporium")
	var name: String = _manager.store_names.get("retro_games", "")
	assert_eq(name, "Mike's Retro Emporium")


func test_get_store_type_returns_empty_for_unknown() -> void:
	assert_eq(
		_manager.get_store_type(&"nonexistent"), &"",
		"Unknown store should return empty StringName"
	)


func test_is_owned_true_for_leased_slot() -> void:
	_manager.lease_store(3, &"video_rental", &"video_rental")
	assert_true(_manager.is_owned(3))


func test_is_owned_false_for_unleased_slot() -> void:
	assert_false(_manager.is_owned(99))


# ── 7. serialize() shape ────────────────────────────────────────────────────


func test_serialize_contains_owned_slots_and_store_types() -> void:
	_manager.lease_store(0, &"retro_games", &"retro_games")
	var data: Dictionary = _manager.serialize()
	assert_true(
		data.has("owned_slots"),
		"Serialized data must contain 'owned_slots'"
	)
	assert_true(
		data.has("store_types"),
		"Serialized data must contain 'store_types'"
	)


func test_serialize_owned_slots_values_match_live_data() -> void:
	_manager.lease_store(0, &"sports_memorabilia", &"sports_memorabilia")
	_manager.lease_store(2, &"retro_games", &"retro_games")
	var data: Dictionary = _manager.serialize()
	var slots: Dictionary = data["owned_slots"]
	assert_eq(slots.size(), 2)
	assert_eq(str(slots[0]), "sports_memorabilia")
	assert_eq(str(slots[2]), "retro_games")


func test_get_save_data_contains_full_state() -> void:
	_manager.lease_store(0, &"retro_games", &"retro_games")
	_manager.set_store_name(&"retro_games", "Custom Name")
	_manager.record_store_revenue("retro_games", 150.0)
	var data: Dictionary = _manager.get_save_data()
	assert_true(data.has("owned_slots"))
	assert_true(data.has("store_types"))
	assert_true(data.has("store_states"))
	assert_true(data.has("store_revenue"))
	assert_true(data.has("store_names"))


# ── 8. load_state() round-trip ──────────────────────────────────────────────


func test_serialize_deserialize_roundtrip_preserves_ownership() -> void:
	_manager.lease_store(0, &"sports_memorabilia", &"sports_memorabilia")
	_manager.lease_store(1, &"retro_games", &"retro_games")

	var saved: Dictionary = _manager.serialize()
	var restored: StoreStateManager = StoreStateManager.new()
	add_child_autofree(restored)
	restored.deserialize(saved)

	assert_true(restored.is_owned(0), "Slot 0 should be owned")
	assert_true(restored.is_owned(1), "Slot 1 should be owned")
	assert_false(restored.is_owned(2), "Slot 2 should not be owned")
	assert_eq(
		restored.get_store_type(&"sports_memorabilia"),
		&"sports_memorabilia"
	)
	assert_eq(
		restored.get_store_type(&"retro_games"), &"retro_games"
	)


func test_get_save_data_load_save_data_roundtrip() -> void:
	_manager.lease_store(0, &"retro_games", &"retro_games")
	_manager.set_store_name(&"retro_games", "My Store")
	_manager.record_store_revenue("retro_games", 250.0)

	var saved: Dictionary = _manager.get_save_data()
	var restored: StoreStateManager = StoreStateManager.new()
	add_child_autofree(restored)
	restored.load_save_data(saved)

	assert_true(restored.is_owned(0))
	assert_eq(restored.store_names.get("retro_games", ""), "My Store")
	assert_almost_eq(
		restored.get_store_revenue("retro_games"), 250.0, 0.01,
		"Revenue should survive round-trip"
	)


func test_deserialize_empty_data_produces_clean_state() -> void:
	_manager.lease_store(0, &"retro_games", &"retro_games")
	_manager.deserialize({})
	assert_eq(
		_manager.owned_slots.size(), 0,
		"Deserializing empty data should clear owned_slots"
	)
	assert_eq(
		_manager.store_types.size(), 0,
		"Deserializing empty data should clear store_types"
	)


# ── 9. Revenue tracking ────────────────────────────────────────────────────


func test_record_and_get_store_revenue() -> void:
	_manager.record_store_revenue("retro_games", 100.0)
	_manager.record_store_revenue("retro_games", 50.0)
	assert_almost_eq(
		_manager.get_store_revenue("retro_games"), 150.0, 0.01,
		"Revenue should accumulate"
	)


func test_reset_daily_revenue_clears_all() -> void:
	_manager.record_store_revenue("retro_games", 200.0)
	_manager.reset_daily_revenue()
	assert_almost_eq(
		_manager.get_store_revenue("retro_games"), 0.0, 0.01,
		"Revenue should be zero after reset"
	)


# ── Signal callbacks ────────────────────────────────────────────────────────


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
