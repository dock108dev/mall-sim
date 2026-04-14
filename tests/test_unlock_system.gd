## GUT unit tests for UnlockSystem — grant, is_unlocked, duplicate guard,
## persistence, and EventBus contract.
extends GutTest


var _system: UnlockSystem
var _signal_count: int = 0
var _last_signal_id: StringName = &""


func before_each() -> void:
	_signal_count = 0
	_last_signal_id = &""
	_register_test_unlock_entries()

	_system = UnlockSystem.new()
	add_child_autofree(_system)
	_system.initialize()

	EventBus.unlock_granted.connect(_on_unlock_granted)


func after_each() -> void:
	if EventBus.unlock_granted.is_connected(_on_unlock_granted):
		EventBus.unlock_granted.disconnect(_on_unlock_granted)


func _on_unlock_granted(unlock_id: StringName) -> void:
	_signal_count += 1
	_last_signal_id = unlock_id


func _register_test_unlock_entries() -> void:
	var ids: Array[String] = [
		"order_catalog_expansion_1",
		"extended_hours_unlock",
		"market_event_preview",
	]
	for id: String in ids:
		if not ContentRegistry.exists(id):
			ContentRegistry.register_entry(
				{"id": id, "name": id.replace("_", " ").capitalize()},
				"unlock"
			)


# ── Tests ─────────────────────────────────────────────────────────────────────


func test_is_unlocked_returns_false_for_unknown_id() -> void:
	var result: bool = _system.is_unlocked(&"nonexistent")
	assert_false(result, "is_unlocked should return false for an unknown ID")


func test_grant_unlock_sets_granted() -> void:
	_system.grant_unlock(&"order_catalog_expansion_1")
	assert_true(
		_system.is_unlocked(&"order_catalog_expansion_1"),
		"is_unlocked should return true after grant_unlock"
	)


func test_duplicate_grant_is_noop() -> void:
	_system.grant_unlock(&"order_catalog_expansion_1")
	_system.grant_unlock(&"order_catalog_expansion_1")
	assert_eq(
		_signal_count, 1,
		"EventBus.unlock_granted should be emitted exactly once for a duplicate grant"
	)


func test_unlock_granted_signal_fires_with_correct_id() -> void:
	_system.grant_unlock(&"extended_hours_unlock")
	assert_eq(
		_signal_count, 1,
		"unlock_granted should fire exactly once"
	)
	assert_eq(
		_last_signal_id, &"extended_hours_unlock",
		"unlock_granted should carry the correct unlock_id"
	)


func test_get_all_granted_returns_all() -> void:
	_system.grant_unlock(&"order_catalog_expansion_1")
	_system.grant_unlock(&"extended_hours_unlock")
	_system.grant_unlock(&"market_event_preview")
	var granted: Array[StringName] = _system.get_all_granted()
	assert_eq(granted.size(), 3, "get_all_granted should return all 3 granted IDs")
	assert_has(granted, &"order_catalog_expansion_1")
	assert_has(granted, &"extended_hours_unlock")
	assert_has(granted, &"market_event_preview")


func test_get_save_data_structure() -> void:
	_system.grant_unlock(&"order_catalog_expansion_1")
	var data: Dictionary = _system.get_save_data()
	assert_true(data.has("granted"), "get_save_data should return a Dictionary with 'granted' key")
	assert_true(
		data["granted"] is Array,
		"'granted' value should be an Array"
	)


func test_load_state_restores_without_signal() -> void:
	var data: Dictionary = {
		"granted": ["order_catalog_expansion_1", "extended_hours_unlock"]
	}
	_system.load_state(data)
	assert_true(_system.is_unlocked(&"order_catalog_expansion_1"))
	assert_true(_system.is_unlocked(&"extended_hours_unlock"))
	assert_eq(
		_signal_count, 0,
		"load_state should not emit unlock_granted signals"
	)


func test_load_state_discards_unknown_ids() -> void:
	var data: Dictionary = {
		"granted": ["order_catalog_expansion_1", "totally_unknown_unlock_xyz"]
	}
	_system.load_state(data)
	assert_true(
		_system.is_unlocked(&"order_catalog_expansion_1"),
		"Valid ID should be restored"
	)
	assert_false(
		_system.is_unlocked(&"totally_unknown_unlock_xyz"),
		"Unknown ID should not be stored"
	)
	var granted: Array[StringName] = _system.get_all_granted()
	assert_false(
		granted.has(&"totally_unknown_unlock_xyz"),
		"Unknown ID should not appear in get_all_granted"
	)
