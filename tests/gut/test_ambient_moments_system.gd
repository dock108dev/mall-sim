## Tests for AmbientMomentsSystem state machine, scheduling, and dispatch.
extends GutTest


var _sys: AmbientMomentsSystem


func _make_def(overrides: Dictionary = {}) -> AmbientMomentDefinition:
	var d := AmbientMomentDefinition.new()
	d.id = overrides.get("id", "test_moment")
	d.name = overrides.get("name", "Test Moment")
	d.trigger_category = overrides.get(
		"trigger_category", "time_of_day"
	)
	d.trigger_value = overrides.get("trigger_value", "9")
	d.display_type = StringName(
		overrides.get("display_type", "toast")
	)
	d.flavor_text = overrides.get("flavor_text", "Test flavor")
	d.audio_cue_id = StringName(
		overrides.get("audio_cue_id", "")
	)
	d.scheduling_weight = overrides.get("scheduling_weight", 1.0)
	d.cooldown_days = overrides.get("cooldown_days", 1)
	return d


func before_each() -> void:
	_sys = AmbientMomentsSystem.new()
	add_child_autofree(_sys)
	_sys._apply_state({})


# ── State Machine ────────────────────────────────────────────────────────────


func test_initial_state_is_idle() -> void:
	assert_eq(
		_sys.get_state(), AmbientMomentsSystem.State.IDLE,
		"System should start in IDLE"
	)


func test_transitions_to_monitoring_on_day_started() -> void:
	_sys._connect_signals()
	EventBus.day_started.emit(1)
	assert_eq(
		_sys.get_state(), AmbientMomentsSystem.State.MONITORING,
		"Should transition to MONITORING on first day_started"
	)


func test_suspend_on_haggle_started() -> void:
	_sys._connect_signals()
	EventBus.day_started.emit(1)
	EventBus.haggle_started.emit("item_a", 1)
	assert_eq(
		_sys.get_state(), AmbientMomentsSystem.State.SUSPENDED,
		"Should suspend on haggle_started"
	)


func test_resume_on_haggle_completed() -> void:
	_sys._connect_signals()
	EventBus.day_started.emit(1)
	EventBus.haggle_started.emit("item_a", 1)
	EventBus.haggle_completed.emit(
		&"store_a", &"item_a", 10.0, 12.0, true, 1
	)
	assert_eq(
		_sys.get_state(), AmbientMomentsSystem.State.MONITORING,
		"Should resume to MONITORING on haggle_completed"
	)


func test_suspend_on_build_mode_entered() -> void:
	_sys._connect_signals()
	EventBus.day_started.emit(1)
	EventBus.build_mode_entered.emit()
	assert_eq(
		_sys.get_state(), AmbientMomentsSystem.State.SUSPENDED,
		"Should suspend on build_mode_entered"
	)


func test_resume_on_build_mode_exited() -> void:
	_sys._connect_signals()
	EventBus.day_started.emit(1)
	EventBus.build_mode_entered.emit()
	EventBus.build_mode_exited.emit()
	assert_eq(
		_sys.get_state(), AmbientMomentsSystem.State.MONITORING,
		"Should resume on build_mode_exited"
	)


func test_nested_suspend_requires_all_resumes() -> void:
	_sys._connect_signals()
	EventBus.day_started.emit(1)
	EventBus.haggle_started.emit("item_a", 1)
	EventBus.build_mode_entered.emit()
	EventBus.haggle_completed.emit(
		&"store_a", &"item_a", 10.0, 12.0, true, 1
	)
	assert_eq(
		_sys.get_state(), AmbientMomentsSystem.State.SUSPENDED,
		"Should stay SUSPENDED when one suspend source remains"
	)
	EventBus.build_mode_exited.emit()
	assert_eq(
		_sys.get_state(), AmbientMomentsSystem.State.MONITORING,
		"Should resume after all suspend sources resolved"
	)


# ── Enqueue By ID ────────────────────────────────────────────────────────────


func test_enqueue_by_id_fires_delivered() -> void:
	_sys._state = AmbientMomentsSystem.State.MONITORING
	watch_signals(EventBus)
	_sys.enqueue_by_id(&"test_moment")
	assert_signal_emitted(
		EventBus, "ambient_moment_delivered"
	)


func test_enqueue_by_id_emits_queued_signal() -> void:
	_sys._state = AmbientMomentsSystem.State.MONITORING
	watch_signals(EventBus)
	_sys.enqueue_by_id(&"test_moment")
	assert_signal_emitted(EventBus, "ambient_moment_queued")


func test_enqueue_by_id_with_empty_id_errors() -> void:
	_sys._state = AmbientMomentsSystem.State.MONITORING
	watch_signals(EventBus)
	_sys.enqueue_by_id(&"")
	assert_signal_not_emitted(
		EventBus, "ambient_moment_queued"
	)


func test_enqueue_by_id_queue_overflow_cancels() -> void:
	_sys._state = AmbientMomentsSystem.State.SUSPENDED
	for i: int in range(AmbientMomentsSystem.MAX_QUEUE_SIZE):
		_sys._delivery_queue.append(
			StringName("moment_%d" % i)
		)
	watch_signals(EventBus)
	_sys.enqueue_by_id(&"overflow_moment")
	assert_signal_emitted(
		EventBus, "ambient_moment_cancelled"
	)


# ── Delivery Queue ───────────────────────────────────────────────────────────


func test_max_queue_size_is_three() -> void:
	assert_eq(
		AmbientMomentsSystem.MAX_QUEUE_SIZE, 3,
		"Queue should be capped at 3"
	)


func test_dispatch_blocked_when_suspended() -> void:
	_sys._state = AmbientMomentsSystem.State.SUSPENDED
	_sys._delivery_queue.append(&"pending_moment")
	watch_signals(EventBus)
	_sys._dispatch_next()
	assert_signal_not_emitted(
		EventBus, "ambient_moment_delivered"
	)


# ── Cooldowns ────────────────────────────────────────────────────────────────


func test_cooldown_ticks_down() -> void:
	_sys._cooldowns["test_moment"] = 3
	_sys._tick_cooldowns()
	assert_eq(
		int(_sys._cooldowns["test_moment"]), 2,
		"Cooldown should decrement by 1"
	)


func test_cooldown_removes_at_zero() -> void:
	_sys._cooldowns["test_moment"] = 1
	_sys._tick_cooldowns()
	assert_false(
		_sys._cooldowns.has("test_moment"),
		"Cooldown entry should be removed when it reaches zero"
	)


# ── Trigger Categories ──────────────────────────────────────────────────────


func test_time_trigger_matches_hour() -> void:
	var def := AmbientMomentDefinition.new()
	def.trigger_category = "time_of_day"
	def.trigger_value = "9"
	assert_true(
		_sys._check_trigger(def, 9),
		"time_of_day trigger should match the target hour"
	)
	assert_false(
		_sys._check_trigger(def, 10),
		"time_of_day trigger should not match a different hour"
	)


func test_random_chance_trigger() -> void:
	var def := AmbientMomentDefinition.new()
	def.category = "hallway"
	def.trigger_category = "random_chance"
	def.trigger_value = "1.0"
	assert_true(
		_sys._check_trigger(def, 0),
		"random_chance with 1.0 should always trigger"
	)


func test_unknown_trigger_returns_false() -> void:
	var def := AmbientMomentDefinition.new()
	def.trigger_category = "unknown_category"
	def.trigger_value = "anything"
	assert_false(
		_sys._check_trigger(def, 0),
		"Unknown trigger category should return false"
	)


# ── Weighted Pick ────────────────────────────────────────────────────────────


func test_weighted_pick_returns_only_candidate() -> void:
	var def := AmbientMomentDefinition.new()
	def.id = "solo"
	def.scheduling_weight = 1.0
	var candidates: Array[AmbientMomentDefinition] = [def]
	var result: AmbientMomentDefinition = (
		_sys._weighted_pick(candidates)
	)
	assert_eq(
		result.id, "solo",
		"Weighted pick with one candidate should return it"
	)


func test_weighted_pick_empty_returns_null() -> void:
	var candidates: Array[AmbientMomentDefinition] = []
	var result: AmbientMomentDefinition = (
		_sys._weighted_pick(candidates)
	)
	assert_null(
		result,
		"Weighted pick with empty list should return null"
	)


# ── Save / Load ──────────────────────────────────────────────────────────────


func test_save_load_round_trip_cooldowns() -> void:
	_sys._cooldowns["moment_a"] = 3
	_sys._cooldowns["moment_b"] = 1
	_sys._state = AmbientMomentsSystem.State.MONITORING
	var save_data: Dictionary = _sys.get_save_data()
	var sys2 := AmbientMomentsSystem.new()
	add_child_autofree(sys2)
	sys2.load_save_data(save_data)
	assert_eq(
		int(sys2._cooldowns["moment_a"]), 3,
		"Cooldown should survive save/load"
	)
	assert_eq(
		int(sys2._cooldowns["moment_b"]), 1,
		"All cooldowns should persist"
	)
	assert_eq(
		sys2.get_state(), AmbientMomentsSystem.State.MONITORING,
		"State should survive save/load"
	)


func test_save_load_round_trip_delivery_queue() -> void:
	_sys._delivery_queue = [&"m1", &"m2"]
	var save_data: Dictionary = _sys.get_save_data()
	var sys2 := AmbientMomentsSystem.new()
	add_child_autofree(sys2)
	sys2.load_state(save_data)
	assert_eq(
		sys2._delivery_queue.size(), 2,
		"Delivery queue should survive save/load"
	)


# ── Discrepancy Legacy ──────────────────────────────────────────────────────


func test_discrepancy_default_inactive() -> void:
	assert_false(
		_sys.is_discrepancy_active(),
		"Discrepancy should be inactive by default"
	)
	assert_eq(
		_sys.get_active_discrepancy(), 0.0,
		"Discrepancy amount should be 0 when inactive"
	)


# ── Eligible Moments Filtering ──────────────────────────────────────────────


func test_get_eligible_returns_only_non_cooldown() -> void:
	var a: AmbientMomentDefinition = _make_def({
		"id": "a", "trigger_value": "12",
	})
	var b: AmbientMomentDefinition = _make_def({
		"id": "b", "trigger_value": "12",
	})
	var c: AmbientMomentDefinition = _make_def({
		"id": "c", "trigger_value": "12",
	})
	_sys._moment_definitions = [a, b, c]
	_sys._cooldowns["b"] = 2

	var eligible: Array[AmbientMomentDefinition] = (
		_sys._get_eligible_moments(12)
	)
	var ids: PackedStringArray = []
	for d: AmbientMomentDefinition in eligible:
		ids.append(d.id)

	assert_true("a" in ids, "a should be eligible")
	assert_false("b" in ids, "b on cooldown should be filtered")
	assert_true("c" in ids, "c should be eligible")
	assert_eq(eligible.size(), 2)


func test_empty_eligible_pool_no_signal_emission() -> void:
	var def: AmbientMomentDefinition = _make_def({
		"id": "only_one", "trigger_value": "9",
	})
	_sys._moment_definitions = [def]
	_sys._cooldowns["only_one"] = 5
	_sys._state = AmbientMomentsSystem.State.MONITORING

	var fired: Array = [false]
	var cb_q: Callable = func(_id: StringName) -> void:
		fired[0] = true
	var cb_d: Callable = func(
		_id: StringName, _dt: StringName,
		_ft: String, _ac: StringName,
	) -> void:
		fired[0] = true
	EventBus.ambient_moment_queued.connect(cb_q)
	EventBus.ambient_moment_delivered.connect(cb_d)

	_sys._evaluate_moments(9)

	assert_false(
		fired[0],
		"No signal when all moments are on cooldown"
	)
	EventBus.ambient_moment_queued.disconnect(cb_q)
	EventBus.ambient_moment_delivered.disconnect(cb_d)


# ── Cooldown Lifecycle ──────────────────────────────────────────────────────


func test_triggered_moment_not_eligible_until_cooldown_expires() -> void:
	var def: AmbientMomentDefinition = _make_def({
		"id": "cd_full", "trigger_value": "9", "cooldown_days": 2,
	})
	def.category = "hallway"
	_sys._moment_definitions = [def]
	_sys._state = AmbientMomentsSystem.State.MONITORING

	_sys._evaluate_moments(9)
	assert_true(
		_sys._cooldowns.has("cd_full"),
		"Cooldown should be set after trigger"
	)
	assert_eq(_sys._cooldowns["cd_full"], 2)

	var eligible: Array[AmbientMomentDefinition] = (
		_sys._get_eligible_moments(9)
	)
	assert_eq(eligible.size(), 0, "Should be ineligible right after trigger")

	_sys._tick_cooldowns()
	eligible = _sys._get_eligible_moments(9)
	assert_eq(eligible.size(), 0, "Still ineligible after 1 tick (cd=1)")

	_sys._tick_cooldowns()
	eligible = _sys._get_eligible_moments(9)
	assert_eq(eligible.size(), 1, "Eligible after cooldown fully expires")
	assert_eq(eligible[0].id, "cd_full")


# ── Weighted Selection ──────────────────────────────────────────────────────


func test_higher_weight_selected_more_often() -> void:
	var heavy: AmbientMomentDefinition = _make_def({
		"id": "heavy", "scheduling_weight": 9.0,
	})
	var light: AmbientMomentDefinition = _make_def({
		"id": "light", "scheduling_weight": 1.0,
	})
	var pool: Array[AmbientMomentDefinition] = [heavy, light]
	var counts: Dictionary = {"heavy": 0, "light": 0}

	seed(42)
	for i: int in range(200):
		var chosen: AmbientMomentDefinition = (
			_sys._weighted_pick(pool)
		)
		if chosen:
			counts[chosen.id] = int(counts[chosen.id]) + 1

	assert_gt(
		int(counts["heavy"]), int(counts["light"]),
		"Heavy (w=9) should appear more than light (w=1). "
		+ "heavy=%d light=%d" % [counts["heavy"], counts["light"]]
	)


# ── Moment Pool Replacement ─────────────────────────────────────────────────


func test_replacing_moment_pool_changes_eligible() -> void:
	_sys._moment_definitions = [
		_make_def({"id": "old_a", "trigger_value": "10"}),
		_make_def({"id": "old_b", "trigger_value": "10"}),
	]
	assert_eq(_sys._moment_definitions.size(), 2)

	var new_pool: Array[AmbientMomentDefinition] = [
		_make_def({"id": "new_x", "trigger_value": "14"}),
	]
	_sys._moment_definitions = new_pool

	assert_eq(_sys._moment_definitions.size(), 1)
	assert_eq(_sys._moment_definitions[0].id, "new_x")

	var eligible_old: Array[AmbientMomentDefinition] = (
		_sys._get_eligible_moments(10)
	)
	assert_eq(
		eligible_old.size(), 0,
		"Old moments should no longer be eligible"
	)

	var eligible_new: Array[AmbientMomentDefinition] = (
		_sys._get_eligible_moments(14)
	)
	assert_eq(eligible_new.size(), 1)
	assert_eq(eligible_new[0].id, "new_x")


# ── Evaluate Moments Signal Emission ────────────────────────────────────────


func test_evaluate_emits_queued_and_delivered() -> void:
	var def: AmbientMomentDefinition = _make_def({
		"id": "morning_pa", "trigger_value": "9",
	})
	def.category = "hallway"
	_sys._moment_definitions = [def]
	_sys._state = AmbientMomentsSystem.State.MONITORING

	var queued_ids: Array[StringName] = []
	var delivered_ids: Array[StringName] = []
	var cb_q: Callable = func(id: StringName) -> void:
		queued_ids.append(id)
	var cb_d: Callable = func(
		id: StringName, _dt: StringName,
		_ft: String, _ac: StringName,
	) -> void:
		delivered_ids.append(id)

	EventBus.ambient_moment_queued.connect(cb_q)
	EventBus.ambient_moment_delivered.connect(cb_d)

	_sys._evaluate_moments(9)

	assert_eq(queued_ids.size(), 1)
	assert_eq(queued_ids[0], &"morning_pa")
	assert_eq(delivered_ids.size(), 1)
	assert_eq(delivered_ids[0], &"morning_pa")

	EventBus.ambient_moment_queued.disconnect(cb_q)
	EventBus.ambient_moment_delivered.disconnect(cb_d)


func test_load_definitions_uses_content_registry() -> void:
	ContentRegistry.clear_for_testing()
	ContentRegistry.register_entry({
		"id": "registry_moment",
		"category": "any",
		"display_type": "toast",
		"trigger_category": "time_of_day",
		"trigger_value": "9",
		"scheduling_weight": 1.0,
		"flavor_text": "Registry-backed moment",
		"audio_cue_id": "",
		"cooldown_days": 1,
	}, "ambient_moment")

	_sys._load_definitions()

	assert_eq(_sys._moment_definitions.size(), 1)
	assert_eq(_sys._moment_definitions[0].id, "registry_moment")
	assert_eq(_sys._moment_definitions[0].category, "any")


func test_secret_thread_category_is_not_auto_scheduled() -> void:
	var def: AmbientMomentDefinition = _make_def({
		"id": "secret_only",
		"trigger_category": "random_chance",
		"trigger_value": "1.0",
	})
	def.category = "secret_thread"
	_sys._moment_definitions = [def]
	_sys._state = AmbientMomentsSystem.State.MONITORING
	watch_signals(EventBus)

	_sys._evaluate_moments(9)

	assert_signal_not_emitted(EventBus, "ambient_moment_queued")
	assert_signal_not_emitted(EventBus, "ambient_moment_delivered")
