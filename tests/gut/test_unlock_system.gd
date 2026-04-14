## GUT tests for UnlockSystem — grant, gate, idempotency, save/load.
extends GutTest


var _system: UnlockSystem
var _signal_watcher_ids: Array[StringName] = []


func before_each() -> void:
	_signal_watcher_ids = []
	_register_test_unlock_entries()

	_system = UnlockSystem.new()
	add_child_autofree(_system)
	_system.initialize()

	EventBus.unlock_granted.connect(_on_unlock_granted)


func after_each() -> void:
	if EventBus.unlock_granted.is_connected(_on_unlock_granted):
		EventBus.unlock_granted.disconnect(_on_unlock_granted)
	_cleanup_test_entries()


func _on_unlock_granted(unlock_id: StringName) -> void:
	_signal_watcher_ids.append(unlock_id)


func _register_test_unlock_entries() -> void:
	var ids: Array[String] = [
		"order_catalog_expansion_1",
		"extended_hours_unlock",
		"market_event_preview",
		"vip_customer_events",
		"prestige_nameplate",
		"prestige_bronze_badge",
	]
	for id: String in ids:
		if not ContentRegistry.exists(id):
			ContentRegistry.register_entry(
				{"id": id, "name": id.replace("_", " ").capitalize()},
				"unlock"
			)


func _cleanup_test_entries() -> void:
	pass


# --- grant_unlock adds to granted and emits signal ---


func test_grant_unlock_adds_to_granted() -> void:
	_system.grant_unlock(&"order_catalog_expansion_1")
	assert_true(
		_system.is_unlocked(&"order_catalog_expansion_1"),
		"Should be unlocked after grant"
	)


func test_grant_unlock_emits_signal() -> void:
	_system.grant_unlock(&"order_catalog_expansion_1")
	assert_eq(
		_signal_watcher_ids.size(), 1,
		"Should emit unlock_granted once"
	)
	assert_eq(
		_signal_watcher_ids[0], &"order_catalog_expansion_1",
		"Signal should carry the correct unlock_id"
	)


func test_duplicate_grant_is_noop() -> void:
	_system.grant_unlock(&"order_catalog_expansion_1")
	_system.grant_unlock(&"order_catalog_expansion_1")
	assert_eq(
		_signal_watcher_ids.size(), 1,
		"Duplicate grant should not emit a second signal"
	)


# --- is_unlocked returns correct state ---


func test_is_unlocked_false_before_grant() -> void:
	assert_false(
		_system.is_unlocked(&"extended_hours_unlock"),
		"Should be false before granting"
	)


func test_is_unlocked_unknown_id_returns_false() -> void:
	assert_false(
		_system.is_unlocked(&"nonexistent_unlock"),
		"Unknown ID should return false without error"
	)


# --- get_all_granted returns correct list ---


func test_get_all_granted_empty_initially() -> void:
	var granted: Array[StringName] = _system.get_all_granted()
	assert_eq(
		granted.size(), 0,
		"Should be empty before any grants"
	)


func test_get_all_granted_contains_granted_ids() -> void:
	_system.grant_unlock(&"order_catalog_expansion_1")
	_system.grant_unlock(&"extended_hours_unlock")
	var granted: Array[StringName] = _system.get_all_granted()
	assert_eq(granted.size(), 2, "Should contain 2 granted IDs")
	assert_has(granted, &"order_catalog_expansion_1")
	assert_has(granted, &"extended_hours_unlock")


# --- save/load ---


func test_get_save_data_format() -> void:
	_system.grant_unlock(&"order_catalog_expansion_1")
	_system.grant_unlock(&"prestige_nameplate")
	var data: Dictionary = _system.get_save_data()
	assert_true(data.has("granted"), "Save data should have 'granted' key")
	assert_eq(
		data["granted"].size(), 2,
		"Granted array should have 2 entries"
	)


func test_load_state_restores_granted() -> void:
	var data: Dictionary = {
		"granted": [
			"order_catalog_expansion_1",
			"extended_hours_unlock",
		]
	}
	_system.load_state(data)
	assert_true(_system.is_unlocked(&"order_catalog_expansion_1"))
	assert_true(_system.is_unlocked(&"extended_hours_unlock"))
	assert_false(_system.is_unlocked(&"prestige_nameplate"))


func test_load_state_does_not_emit_signals() -> void:
	var data: Dictionary = {
		"granted": ["order_catalog_expansion_1"]
	}
	_system.load_state(data)
	assert_eq(
		_signal_watcher_ids.size(), 0,
		"load_state should not emit unlock_granted signals"
	)


func test_load_state_discards_unknown_ids() -> void:
	var data: Dictionary = {
		"granted": [
			"order_catalog_expansion_1",
			"totally_fake_unlock",
		]
	}
	_system.load_state(data)
	assert_true(_system.is_unlocked(&"order_catalog_expansion_1"))
	assert_false(
		_system.is_unlocked(&"totally_fake_unlock"),
		"Unknown ID should be discarded"
	)


func test_save_load_round_trip() -> void:
	_system.grant_unlock(&"order_catalog_expansion_1")
	_system.grant_unlock(&"vip_customer_events")
	var saved: Dictionary = _system.get_save_data()

	var new_system: UnlockSystem = UnlockSystem.new()
	add_child_autofree(new_system)
	new_system.initialize()
	new_system.load_state(saved)

	assert_true(new_system.is_unlocked(&"order_catalog_expansion_1"))
	assert_true(new_system.is_unlocked(&"vip_customer_events"))
	assert_false(new_system.is_unlocked(&"prestige_nameplate"))


# --- milestone_unlocked signal wiring ---


func test_milestone_unlock_reward_grants_unlock() -> void:
	var reward: Dictionary = {
		"reward_type": "unlock",
		"reward_value": "order_catalog_expansion_1",
	}
	EventBus.milestone_unlocked.emit(&"test_milestone", reward)
	assert_true(
		_system.is_unlocked(&"order_catalog_expansion_1"),
		"unlock reward should grant via milestone_unlocked signal"
	)


func test_milestone_fixture_unlock_reward_grants_unlock() -> void:
	var reward: Dictionary = {
		"reward_type": "fixture_unlock",
		"reward_value": "extended_hours_unlock",
	}
	EventBus.milestone_unlocked.emit(&"test_fixture_ms", reward)
	assert_true(
		_system.is_unlocked(&"extended_hours_unlock"),
		"fixture_unlock reward should grant via milestone_unlocked signal"
	)


func test_milestone_cash_reward_does_not_grant_unlock() -> void:
	var reward: Dictionary = {
		"reward_type": "cash",
		"reward_value": 100.0,
	}
	EventBus.milestone_unlocked.emit(&"cash_milestone", reward)
	assert_eq(
		_system.get_all_granted().size(), 0,
		"cash reward should not trigger any unlock grant"
	)


func test_milestone_no_unlock_entry_no_grant() -> void:
	var reward: Dictionary = {
		"reward_type": "supplier_tier",
		"reward_value": 2,
	}
	EventBus.milestone_unlocked.emit(&"tier_ms", reward)
	assert_eq(
		_system.get_all_granted().size(), 0,
		"non-unlock reward should not trigger any unlock grant"
	)


func test_milestone_duplicate_unlock_no_error() -> void:
	_system.grant_unlock(&"order_catalog_expansion_1")
	_signal_watcher_ids.clear()
	var reward: Dictionary = {
		"reward_type": "unlock",
		"reward_value": "order_catalog_expansion_1",
	}
	EventBus.milestone_unlocked.emit(&"dupe_ms", reward)
	assert_eq(
		_signal_watcher_ids.size(), 0,
		"duplicate grant via milestone signal should not re-emit"
	)
