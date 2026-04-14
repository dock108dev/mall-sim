## Unit tests for OnboardingSystem hint display, guard conditions, and persistence.
extends GutTest


var _onboarding: OnboardingSystem


func before_each() -> void:
	_onboarding = OnboardingSystem.new()
	add_child_autofree(_onboarding)


# --- Hint emission ---


func test_maybe_show_hint_day_start_emits_signal() -> void:
	var received_id: Array = [&""]
	var received_msg: Array = [""]
	var received_pos: Array = [""]
	var on_hint: Callable = func(
		id: StringName, msg: String, pos: String
	) -> void:
		received_id[0] = id
		received_msg[0] = msg
		received_pos[0] = pos
	EventBus.onboarding_hint_shown.connect(on_hint)

	_onboarding.maybe_show_hint(&"day_start")

	assert_eq(received_id[0], &"hint_day_start", "Should emit hint_id for day_start trigger")
	assert_false(received_msg[0].is_empty(), "Message should be non-empty")
	assert_false(received_pos[0].is_empty(), "Position hint should be non-empty")

	EventBus.onboarding_hint_shown.disconnect(on_hint)


func test_maybe_show_hint_emits_signal_for_known_trigger() -> void:
	var received_id: Array = [&""]
	var received_msg: Array = [""]
	var received_pos: Array = [""]
	var on_hint: Callable = func(
		id: StringName, msg: String, pos: String
	) -> void:
		received_id[0] = id
		received_msg[0] = msg
		received_pos[0] = pos
	EventBus.onboarding_hint_shown.connect(on_hint)

	_onboarding.maybe_show_hint(&"store_entered")

	assert_eq(received_id[0], &"hint_store_entered", "Should emit hint_id for store_entered trigger")
	assert_false(received_msg[0].is_empty(), "Message should be non-empty")
	assert_false(received_pos[0].is_empty(), "Position hint should be non-empty")

	EventBus.onboarding_hint_shown.disconnect(on_hint)


func test_maybe_show_hint_does_not_emit_for_unknown_trigger() -> void:
	var hint_emitted: Array = [false]
	var on_hint: Callable = func(
		_id: StringName, _msg: String, _pos: String
	) -> void:
		hint_emitted[0] = true
	EventBus.onboarding_hint_shown.connect(on_hint)

	_onboarding.maybe_show_hint(&"unknown_trigger")

	assert_false(hint_emitted[0], "Should not emit for unknown trigger")

	EventBus.onboarding_hint_shown.disconnect(on_hint)


# --- Idempotency ---


func test_maybe_show_hint_day_start_idempotent() -> void:
	var emit_count: Array = [0]
	var on_hint: Callable = func(
		_id: StringName, _msg: String, _pos: String
	) -> void:
		emit_count[0] += 1
	EventBus.onboarding_hint_shown.connect(on_hint)

	_onboarding.maybe_show_hint(&"day_start")
	_onboarding.maybe_show_hint(&"day_start")

	assert_eq(emit_count[0], 1, "day_start hint should emit only on first call")

	EventBus.onboarding_hint_shown.disconnect(on_hint)


func test_hint_not_re_emitted_after_first_showing() -> void:
	var emit_count: Array = [0]
	var on_hint: Callable = func(
		_id: StringName, _msg: String, _pos: String
	) -> void:
		emit_count[0] += 1
	EventBus.onboarding_hint_shown.connect(on_hint)

	_onboarding.maybe_show_hint(&"store_entered")
	_onboarding.maybe_show_hint(&"store_entered")

	assert_eq(emit_count[0], 1, "Hint should only emit once")

	EventBus.onboarding_hint_shown.disconnect(on_hint)


# --- Guard: all hints shown ---


func test_no_hint_emitted_when_all_shown() -> void:
	_onboarding.maybe_show_hint(&"day_start")
	_onboarding.maybe_show_hint(&"store_entered")
	_onboarding.maybe_show_hint(&"first_customer_spawned")
	_onboarding.maybe_show_hint(&"first_sale")
	_onboarding.maybe_show_hint(&"inventory_low")
	_onboarding.maybe_show_hint(&"day_ending_soon")
	_onboarding.maybe_show_hint(&"first_order_placed")
	_onboarding.maybe_show_hint(&"staff_hired")
	_onboarding.maybe_show_hint(&"reputation_changed")
	_onboarding.maybe_show_hint(&"checkout_queue_formed")
	_onboarding.maybe_show_hint(&"browse_timer_started")

	var hint_emitted: Array = [false]
	var on_hint: Callable = func(
		_id: StringName, _msg: String, _pos: String
	) -> void:
		hint_emitted[0] = true
	EventBus.onboarding_hint_shown.connect(on_hint)

	_onboarding.maybe_show_hint(&"store_entered")
	_onboarding.maybe_show_hint(&"day_start")

	assert_false(hint_emitted[0], "Should not emit when all hints have already been shown")

	EventBus.onboarding_hint_shown.disconnect(on_hint)


# --- Guard: day > 1 ---


func test_maybe_show_hint_silent_when_day_greater_than_one() -> void:
	var hint_emitted: Array = [false]
	var on_hint: Callable = func(
		_id: StringName, _msg: String, _pos: String
	) -> void:
		hint_emitted[0] = true
	EventBus.onboarding_hint_shown.connect(on_hint)

	EventBus.day_started.emit(2)
	_onboarding.maybe_show_hint(&"store_entered")

	assert_false(hint_emitted[0], "Should not emit hints after Day 1")

	EventBus.onboarding_hint_shown.disconnect(on_hint)


# --- Guard: disabled ---


func test_maybe_show_hint_silent_when_disabled() -> void:
	var hint_emitted: Array = [false]
	var on_hint: Callable = func(
		_id: StringName, _msg: String, _pos: String
	) -> void:
		hint_emitted[0] = true
	EventBus.onboarding_hint_shown.connect(on_hint)

	_onboarding.disable()
	_onboarding.maybe_show_hint(&"store_entered")

	assert_false(hint_emitted[0], "Should not emit hints when disabled")

	EventBus.onboarding_hint_shown.disconnect(on_hint)


# --- disable() and is_active() ---


func test_disable_sets_is_active_to_false() -> void:
	assert_true(_onboarding.is_active(), "Should be active by default")
	_onboarding.disable()
	assert_false(_onboarding.is_active(), "Should be inactive after disable()")


# --- Position hint ---


func test_hint_bottom_left_position_emitted_correctly() -> void:
	var received_pos: Array = [""]
	var on_hint: Callable = func(
		_id: StringName, _msg: String, pos: String
	) -> void:
		received_pos[0] = pos
	EventBus.onboarding_hint_shown.connect(on_hint)

	_onboarding.maybe_show_hint(&"day_start")

	assert_eq(received_pos[0], "bottom_left", "Signal should carry correct position_hint")

	EventBus.onboarding_hint_shown.disconnect(on_hint)


# --- Save / Load ---


func test_save_data_contains_shown_hints() -> void:
	_onboarding.maybe_show_hint(&"store_entered")
	var data: Dictionary = _onboarding.get_save_data()

	assert_true(data.has("shown_hints"), "Save data should have shown_hints key")
	var hints: Dictionary = data["shown_hints"]
	assert_true(hints.has("hint_store_entered"), "shown_hints should contain triggered hint id")


func test_load_state_with_empty_dict_behaves_as_fresh_start() -> void:
	_onboarding.load_save_data({})

	var hint_emitted: Array = [false]
	var on_hint: Callable = func(
		_id: StringName, _msg: String, _pos: String
	) -> void:
		hint_emitted[0] = true
	EventBus.onboarding_hint_shown.connect(on_hint)

	_onboarding.maybe_show_hint(&"store_entered")

	assert_true(hint_emitted[0], "Should emit hint after loading empty state (fresh start)")

	EventBus.onboarding_hint_shown.disconnect(on_hint)


func test_load_data_restores_shown_hints() -> void:
	var save_data: Dictionary = {
		"shown_hints": {"hint_store_entered": true},
		"active": true,
	}
	_onboarding.load_save_data(save_data)

	var hint_emitted: Array = [false]
	var on_hint: Callable = func(
		_id: StringName, _msg: String, _pos: String
	) -> void:
		hint_emitted[0] = true
	EventBus.onboarding_hint_shown.connect(on_hint)

	_onboarding.maybe_show_hint(&"store_entered")

	assert_false(hint_emitted[0], "Hint should not re-emit after loading shown state")

	EventBus.onboarding_hint_shown.disconnect(on_hint)


func test_load_data_restores_active_state() -> void:
	var save_data: Dictionary = {
		"shown_hints": {},
		"active": false,
	}
	_onboarding.load_save_data(save_data)

	assert_false(_onboarding.is_active(), "Should restore inactive state from save data")


# --- Day boundary ---


func test_day_ended_disables_system() -> void:
	assert_true(_onboarding.is_active(), "Active on Day 1")
	EventBus.day_ended.emit(1)
	assert_false(_onboarding.is_active(), "Should disable after Day 1 ends")
