## GUT unit tests for StoreStateManager slot ownership, active store, and signals.
extends GutTest


var _manager: StoreStateManager
var _lease_results: Array[Dictionary] = []
var _store_changed: Array[StringName] = []
var _store_entered: Array[StringName] = []
var _store_exited: Array[StringName] = []
var _saved_owned_stores: Array[StringName] = []


func before_each() -> void:
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	GameManager.owned_stores = []
	ContentRegistry.clear_for_testing()
	_register_store_catalog()
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
	_manager.lease_store(0, &"sports_memorabilia", &"sports_memorabilia")
	_manager.lease_store(1, &"retro_games", &"retro_games")
	_lease_results.clear()


func after_each() -> void:
	if EventBus.lease_completed.is_connected(_on_lease_completed):
		EventBus.lease_completed.disconnect(_on_lease_completed)
	if EventBus.active_store_changed.is_connected(_on_active_store_changed):
		EventBus.active_store_changed.disconnect(_on_active_store_changed)
	if EventBus.store_entered.is_connected(_on_store_entered):
		EventBus.store_entered.disconnect(_on_store_entered)
	if EventBus.store_exited.is_connected(_on_store_exited):
		EventBus.store_exited.disconnect(_on_store_exited)
	GameManager.owned_stores = _saved_owned_stores


# ── 1. Slot assignment records ownership ───────────────────────────────────


func test_slot_assignment_records_ownership() -> void:
	assert_true(
		_manager.owned_slots.has(0),
		"Slot 0 should exist in owned_slots"
	)
	assert_eq(
		_manager.owned_slots[0], &"sports",
		"Slot 0 should map to the canonical sports ID"
	)


func test_slot_assignment_lookup_returns_correct_store() -> void:
	assert_true(_manager.is_owned(0))
	assert_true(_manager.is_owned(1))
	assert_eq(_manager.owned_slots[1], &"retro_games")


func test_lease_store_syncs_game_manager_owned_stores() -> void:
	assert_true(
		GameManager.owned_stores.has(&"sports"),
		"Leased stores should be reflected in GameManager.owned_stores"
	)
	assert_true(
		GameManager.owned_stores.has(&"retro_games"),
		"Each successful lease should sync the canonical store ID"
	)


func test_slot_assignment_emits_success_signal() -> void:
	_manager.lease_store(2, &"video_rental", &"video_rental")
	assert_eq(_lease_results.size(), 1)
	assert_eq(_lease_results[0]["store_id"], &"rentals")
	assert_true(_lease_results[0]["success"] as bool)
	assert_eq(_lease_results[0]["message"], "")


func test_lease_requested_signal_registers_slot_ownership() -> void:
	EventBus.lease_requested.emit(&"video_rental", 2, "Video Vault")
	assert_true(_manager.is_owned(2))
	assert_eq(_manager.owned_slots[2], &"rentals")
	assert_eq(_manager.get_store_name(&"rentals"), "Video Vault")
	assert_eq(_lease_results.size(), 1)
	assert_true(_lease_results[0]["success"] as bool)


# ── 2. Active store identity ──────────────────────────────────────────────


func test_active_store_matches_after_set() -> void:
	_manager.set_active_store(&"retro_games")
	assert_eq(
		_manager.active_store_id, &"retro_games",
		"active_store_id should match the store set via set_active_store"
	)


func test_active_store_updates_on_switch() -> void:
	_manager.set_active_store(&"sports_memorabilia")
	_manager.set_active_store(&"retro_games")
	assert_eq(
		_manager.active_store_id, &"retro_games",
		"active_store_id should reflect the most recent set_active_store call"
	)


# ── 3. Unregistered store_id handling ─────────────────────────────────────


func test_set_active_store_with_unregistered_id_rejects_change() -> void:
	_manager.set_active_store(&"nonexistent_store")
	assert_eq(
		_manager.active_store_id, &"",
		"set_active_store should reject unknown IDs"
	)


func test_set_active_store_empty_clears_active() -> void:
	_manager.set_active_store(&"retro_games")
	_manager.set_active_store(&"")
	assert_eq(
		_manager.active_store_id, &"",
		"active_store_id should be empty after clearing"
	)


# ── 4. Store entry transitions ────────────────────────────────────────────


func test_entering_store_from_hallway() -> void:
	_manager.set_active_store(&"retro_games")
	assert_eq(
		_manager.active_store_id, &"retro_games",
		"Store should be active after entry"
	)
	assert_eq(
		_store_entered.size(), 1,
		"store_entered should fire once"
	)


func test_exiting_store_to_hallway() -> void:
	_manager.set_active_store(&"retro_games")
	_store_exited.clear()
	_manager.set_active_store(&"")
	assert_eq(
		_manager.active_store_id, &"",
		"Store should be inactive after exit"
	)
	assert_eq(
		_store_exited.size(), 1,
		"store_exited should fire once"
	)


# ── 5. EventBus.store_entered signal ─────────────────────────────────────


func test_store_entered_fires_with_correct_id() -> void:
	_manager.set_active_store(&"sports_memorabilia")
	assert_eq(_store_entered.size(), 1)
	assert_eq(
		_store_entered[0], &"sports",
		"store_entered payload should use the canonical store_id"
	)


func test_store_entered_does_not_fire_on_empty() -> void:
	_manager.set_active_store(&"")
	assert_eq(
		_store_entered.size(), 0,
		"store_entered should not fire when setting empty store_id"
	)


# ── 6. EventBus.store_exited signal ──────────────────────────────────────


func test_store_exited_fires_with_correct_id() -> void:
	_manager.set_active_store(&"retro_games")
	_store_exited.clear()
	_manager.set_active_store(&"sports_memorabilia")
	assert_eq(_store_exited.size(), 1)
	assert_eq(
		_store_exited[0], &"retro_games",
		"store_exited payload should carry the previous store_id"
	)


func test_store_exited_fires_on_clear() -> void:
	_manager.set_active_store(&"retro_games")
	_store_exited.clear()
	_manager.set_active_store(&"")
	assert_eq(_store_exited.size(), 1)
	assert_eq(_store_exited[0], &"retro_games")


func test_switching_stores_emits_both_signals() -> void:
	_manager.set_active_store(&"retro_games")
	_store_entered.clear()
	_store_exited.clear()

	_manager.set_active_store(&"sports_memorabilia")
	assert_eq(_store_exited.size(), 1)
	assert_eq(_store_exited[0], &"retro_games")
	assert_eq(_store_entered.size(), 1)
	assert_eq(_store_entered[0], &"sports")


# ── 7. Duplicate slot assignment ─────────────────────────────────────────


func test_duplicate_slot_returns_false() -> void:
	var result: bool = _manager.lease_store(
		0, &"video_rental", &"video_rental"
	)
	assert_false(
		result,
		"Leasing an already-occupied slot should return false"
	)


func test_duplicate_slot_does_not_overwrite() -> void:
	_manager.lease_store(0, &"video_rental", &"video_rental")
	assert_eq(
		_manager.owned_slots[0], &"sports",
		"Original store should remain after rejected duplicate lease"
	)


func test_duplicate_slot_emits_failure_signal() -> void:
	_manager.lease_store(0, &"video_rental", &"video_rental")
	assert_eq(_lease_results.size(), 1)
	assert_false(_lease_results[0]["success"] as bool)
	assert_true(
		(_lease_results[0]["message"] as String).length() > 0,
		"Failure signal should include an error message"
	)


# ── 8. active_store_changed signal ───────────────────────────────────────


func test_active_store_changed_fires_on_set() -> void:
	_manager.set_active_store(&"retro_games")
	assert_eq(_store_changed.size(), 1)
	assert_eq(_store_changed[0], &"retro_games")


# ── 9. Store type tracking ───────────────────────────────────────────────


func test_store_type_recorded_on_lease() -> void:
	assert_eq(
		_manager.get_store_type(&"sports_memorabilia"),
		&"sports"
	)
	assert_eq(
		_manager.get_store_type(&"retro_games"), &"retro_games"
	)


func test_store_type_unknown_returns_empty() -> void:
	assert_eq(_manager.get_store_type(&"nonexistent"), &"")


# ── Signal callbacks ─────────────────────────────────────────────────────


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


func _register_store_catalog() -> void:
	ContentRegistry.register_entry(
		{
			"id": "sports",
			"aliases": ["sports_memorabilia"],
			"name": "Sports Memorabilia",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "retro_games",
			"name": "Retro Game Store",
		},
		"store"
	)
	ContentRegistry.register_entry(
		{
			"id": "rentals",
			"aliases": ["video_rental"],
			"name": "Video Rental",
		},
		"store"
	)
