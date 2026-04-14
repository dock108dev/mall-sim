## Unit tests for UnlockSystem — grant, duplicate guard, is_unlocked gate, and save/load round-trip.
class_name TestUnlockSystem
extends GutTest


var _sys: UnlockSystem


func before_each() -> void:
	_sys = UnlockSystem.new()
	add_child_autofree(_sys)
	_sys._valid_ids = {}
	_sys._granted = {}
	_sys._valid_ids[&"test_unlock_a"] = true
	_sys._valid_ids[&"test_unlock_b"] = true
	_sys._valid_ids[&"test_unlock_c"] = true


func test_grant_unlock_makes_is_unlocked_return_true() -> void:
	_sys.grant_unlock(&"test_unlock_a")
	assert_true(
		_sys.is_unlocked(&"test_unlock_a"),
		"is_unlocked should return true after grant_unlock"
	)


func test_duplicate_grant_emits_signal_exactly_once() -> void:
	watch_signals(EventBus)
	_sys.grant_unlock(&"test_unlock_a")
	_sys.grant_unlock(&"test_unlock_a")
	assert_signal_emit_count(
		EventBus, "unlock_granted", 1,
		"unlock_granted should emit exactly once for duplicate grant_unlock calls"
	)


func test_is_unlocked_returns_false_for_never_granted_id() -> void:
	assert_false(
		_sys.is_unlocked(&"test_unlock_a"),
		"is_unlocked should return false for an ID that was never granted"
	)


func test_get_all_granted_returns_only_granted_ids() -> void:
	_sys.grant_unlock(&"test_unlock_a")
	_sys.grant_unlock(&"test_unlock_c")
	var granted: Array[StringName] = _sys.get_all_granted()
	assert_eq(granted.size(), 2, "get_all_granted should return exactly 2 entries")
	assert_has(granted, &"test_unlock_a", "granted should contain test_unlock_a")
	assert_has(granted, &"test_unlock_c", "granted should contain test_unlock_c")
	assert_does_not_have(
		granted, &"test_unlock_b",
		"granted should not contain test_unlock_b which was never granted"
	)


func test_grant_unknown_id_warns_and_discards() -> void:
	watch_signals(EventBus)
	_sys.grant_unlock(&"nonexistent_unlock")
	assert_false(
		_sys.is_unlocked(&"nonexistent_unlock"),
		"is_unlocked should return false for an unknown unlock ID"
	)
	assert_signal_not_emitted(
		EventBus, "unlock_granted",
		"unlock_granted should not emit for an unknown unlock ID"
	)


func test_save_load_round_trip_preserves_granted_unlocks() -> void:
	_sys.grant_unlock(&"test_unlock_a")
	_sys.grant_unlock(&"test_unlock_b")
	var data: Dictionary = _sys.get_save_data()

	var fresh: UnlockSystem = UnlockSystem.new()
	add_child_autofree(fresh)
	fresh._valid_ids = {}
	fresh._valid_ids[&"test_unlock_a"] = true
	fresh._valid_ids[&"test_unlock_b"] = true
	fresh._valid_ids[&"test_unlock_c"] = true
	fresh.load_state(data)

	assert_true(
		fresh.is_unlocked(&"test_unlock_a"),
		"test_unlock_a should be unlocked after load_state"
	)
	assert_true(
		fresh.is_unlocked(&"test_unlock_b"),
		"test_unlock_b should be unlocked after load_state"
	)
	assert_false(
		fresh.is_unlocked(&"test_unlock_c"),
		"test_unlock_c should remain locked after load_state"
	)


func test_load_state_does_not_emit_unlock_granted() -> void:
	_sys.grant_unlock(&"test_unlock_a")
	var data: Dictionary = _sys.get_save_data()

	var fresh: UnlockSystem = UnlockSystem.new()
	add_child_autofree(fresh)
	fresh._valid_ids = {}
	fresh._valid_ids[&"test_unlock_a"] = true

	watch_signals(EventBus)
	fresh.load_state(data)
	assert_signal_not_emitted(
		EventBus, "unlock_granted",
		"load_state must not re-emit unlock_granted for loaded IDs"
	)


func test_fresh_system_get_all_granted_returns_empty_array() -> void:
	var granted: Array[StringName] = _sys.get_all_granted()
	assert_eq(
		granted.size(), 0,
		"Fresh UnlockSystem get_all_granted should return empty array"
	)
	assert_true(
		granted is Array[StringName],
		"get_all_granted return type should be Array[StringName]"
	)


func test_grant_unlock_emits_toast_with_unlock_category() -> void:
	var toasts: Array[Dictionary] = []
	var capture: Callable = func(msg: String, cat: StringName, dur: float) -> void:
		toasts.append({"message": msg, "category": cat, "duration": dur})
	EventBus.toast_requested.connect(capture)
	_sys.grant_unlock(&"test_unlock_a")
	EventBus.toast_requested.disconnect(capture)

	assert_eq(toasts.size(), 1, "Exactly one toast should be emitted on grant")
	assert_eq(
		toasts[0].get("category") as StringName, &"unlock",
		"Toast category must be 'unlock'"
	)
	assert_almost_eq(
		toasts[0].get("duration") as float, 5.0, 0.01,
		"Toast duration must be 5.0"
	)


func test_grant_unlock_toast_message_contains_unlock_id_as_fallback() -> void:
	var messages: Array[String] = []
	var capture: Callable = func(msg: String, _cat: StringName, _dur: float) -> void:
		messages.append(msg)
	EventBus.toast_requested.connect(capture)
	_sys.grant_unlock(&"test_unlock_b")
	EventBus.toast_requested.disconnect(capture)

	assert_eq(messages.size(), 1, "One toast message must be emitted")
	assert_true(
		messages[0].begins_with("Unlocked:"),
		"Toast message must begin with 'Unlocked:'"
	)


func test_duplicate_grant_does_not_emit_toast() -> void:
	var toast_count: int = 0
	var capture: Callable = func(_msg: String, _cat: StringName, _dur: float) -> void:
		toast_count += 1
	EventBus.toast_requested.connect(capture)
	_sys.grant_unlock(&"test_unlock_a")
	_sys.grant_unlock(&"test_unlock_a")
	EventBus.toast_requested.disconnect(capture)

	assert_eq(toast_count, 1, "Duplicate grant must not emit a second toast")


func test_grant_unlock_with_registry_entry_uses_display_name() -> void:
	const REGISTRY_ID: StringName = &"test_unlock_display"
	const DISPLAY_NAME: String = "Display Name Unlock"
	if not ContentRegistry.exists(String(REGISTRY_ID)):
		ContentRegistry.register_entry(
			{"id": String(REGISTRY_ID), "name": DISPLAY_NAME},
			"unlock"
		)
	_sys._valid_ids[REGISTRY_ID] = true

	var messages: Array[String] = []
	var capture: Callable = func(msg: String, _cat: StringName, _dur: float) -> void:
		messages.append(msg)
	EventBus.toast_requested.connect(capture)
	_sys.grant_unlock(REGISTRY_ID)
	EventBus.toast_requested.disconnect(capture)

	assert_eq(messages.size(), 1, "One toast must be emitted for registry-resolved unlock")
	assert_true(
		messages[0].contains(DISPLAY_NAME),
		"Toast message must contain the display name from ContentRegistry"
	)
