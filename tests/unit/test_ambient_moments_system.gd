## GUT unit tests for AmbientMomentsSystem — trigger evaluation, cooldown, and signal contracts.
extends GutTest


var _sys: AmbientMomentsSystem


func _make_def(overrides: Dictionary = {}) -> AmbientMomentDefinition:
	var d := AmbientMomentDefinition.new()
	d.id = overrides.get("id", "test_moment")
	d.category = overrides.get("category", "any")
	d.trigger_category = overrides.get("trigger_category", "time_of_day")
	d.trigger_value = overrides.get("trigger_value", "9")
	d.display_type = StringName(overrides.get("display_type", "toast"))
	d.flavor_text = overrides.get("flavor_text", "Test flavor")
	d.audio_cue_id = StringName(overrides.get("audio_cue_id", ""))
	d.scheduling_weight = overrides.get("scheduling_weight", 1.0)
	d.cooldown_days = overrides.get("cooldown_days", 1)
	return d


func before_each() -> void:
	_sys = AmbientMomentsSystem.new()
	add_child_autofree(_sys)
	_sys._apply_state({})
	_sys._state = AmbientMomentsSystem.State.MONITORING
	GameManager.current_store_id = &""


func after_each() -> void:
	GameManager.current_store_id = &""


# ── Time-of-Day Trigger ──────────────────────────────────────────────────────


func test_time_of_day_trigger_fires_at_correct_hour() -> void:
	var def := _make_def({
		"id": "hour_14",
		"category": "hallway",
		"trigger_category": "time_of_day",
		"trigger_value": "14",
	})
	_sys._moment_definitions = [def]

	var delivered: Array[StringName] = []
	var cb := func(id: StringName, _dt: StringName, _ft: String, _ac: StringName) -> void:
		delivered.append(id)
	EventBus.ambient_moment_delivered.connect(cb)
	_sys._evaluate_moments(14)
	EventBus.ambient_moment_delivered.disconnect(cb)

	assert_eq(delivered.size(), 1, "Should deliver moment at the matching hour")
	assert_eq(delivered[0], &"hour_14", "Delivered id must match the registered moment")


func test_time_of_day_trigger_does_not_fire_at_wrong_hour() -> void:
	var def := _make_def({
		"id": "hour_14",
		"category": "hallway",
		"trigger_category": "time_of_day",
		"trigger_value": "14",
	})
	_sys._moment_definitions = [def]

	var delivered: Array[StringName] = []
	var cb := func(id: StringName, _dt: StringName, _ft: String, _ac: StringName) -> void:
		delivered.append(id)
	EventBus.ambient_moment_delivered.connect(cb)
	_sys._evaluate_moments(13)
	EventBus.ambient_moment_delivered.disconnect(cb)

	assert_eq(delivered.size(), 0, "Should not deliver moment at the wrong hour")


# ── Reputation Tier Trigger ──────────────────────────────────────────────────


func test_reputation_tier_trigger_fires_on_tier_reached() -> void:
	# With no reputation system present, _get_current_reputation returns 0.0.
	# tier=0 passes because int(0.0 / 25.0) = 0 >= 0.
	var def := _make_def({
		"id": "rep_tier_0",
		"category": "hallway",
		"trigger_category": "reputation_tier",
		"trigger_value": "0",
	})
	assert_true(
		_sys._check_trigger(def, 0),
		"reputation_tier trigger should fire when required tier is met"
	)


func test_reputation_tier_trigger_does_not_fire_on_lower_tier() -> void:
	# With no reputation system, score is 0.0, which is below tier=2 threshold (score >= 50).
	var def := _make_def({
		"id": "rep_tier_2",
		"category": "hallway",
		"trigger_category": "reputation_tier",
		"trigger_value": "2",
	})
	assert_false(
		_sys._check_trigger(def, 0),
		"reputation_tier trigger should not fire when current tier is below required"
	)


# ── Item Type Trigger ────────────────────────────────────────────────────────


func test_item_type_trigger_fires_on_matching_sale() -> void:
	GameManager.current_store_id = &"sports_memorabilia"
	_sys._on_active_store_changed(&"sports_memorabilia")
	_sys._on_item_sold("item_a", 10.0, "sports_card")
	var def := _make_def({
		"id": "sports_card_moment",
		"category": "store",
		"trigger_category": "item_type",
		"trigger_value": "sports_card",
	})
	assert_true(
		_sys._check_trigger(def, 0),
		"item_type trigger should fire when an active store is set and category matches"
	)


func test_item_type_trigger_does_not_fire_without_active_store() -> void:
	GameManager.current_store_id = &""
	var def := _make_def({
		"id": "sports_card_moment",
		"category": "store",
		"trigger_category": "item_type",
		"trigger_value": "sports_card",
	})
	assert_false(
		_sys._check_trigger(def, 0),
		"item_type trigger should not fire when no store is active"
	)


# ── Store Type Trigger ───────────────────────────────────────────────────────


func test_store_type_trigger_fires_on_first_entry_only() -> void:
	GameManager.current_store_id = &"retro_games"
	_sys._on_store_entered(&"retro_games")
	var def := _make_def({
		"id": "retro_entry",
		"category": "store",
		"trigger_category": "store_type",
		"trigger_value": "retro_games",
		"cooldown_days": 0,
	})
	_sys._moment_definitions = [def]

	var delivered: Array[StringName] = []
	var cb := func(id: StringName, _dt: StringName, _ft: String, _ac: StringName) -> void:
		delivered.append(id)
	EventBus.ambient_moment_delivered.connect(cb)

	_sys._evaluate_moments(10)
	assert_eq(delivered.size(), 1, "Should deliver on first store entry")

	_sys._on_day_started(2)
	_sys._evaluate_moments(11)
	assert_eq(
		delivered.size(), 1,
		"Should not deliver again after one-shot store entry fires"
	)

	EventBus.ambient_moment_delivered.disconnect(cb)


# ── Cooldown ─────────────────────────────────────────────────────────────────


func test_cooldown_prevents_repeat_trigger() -> void:
	var def := _make_def({
		"id": "cd_moment",
		"category": "hallway",
		"trigger_category": "time_of_day",
		"trigger_value": "9",
		"cooldown_days": 3,
	})
	_sys._moment_definitions = [def]

	var delivered: Array[StringName] = []
	var cb := func(id: StringName, _dt: StringName, _ft: String, _ac: StringName) -> void:
		delivered.append(id)
	EventBus.ambient_moment_delivered.connect(cb)

	# First trigger — should fire.
	_sys._evaluate_moments(9)
	assert_eq(delivered.size(), 1, "Should deliver on first trigger")

	# Second trigger same day — cooldown active, should not fire.
	_sys._evaluate_moments(9)
	assert_eq(delivered.size(), 1, "Cooldown should prevent immediate repeat trigger")

	# Advance 3 days to expire the cooldown.
	_sys._tick_cooldowns()
	_sys._tick_cooldowns()
	_sys._tick_cooldowns()

	# Third trigger — cooldown expired, should fire again.
	_sys._evaluate_moments(9)
	assert_eq(delivered.size(), 2, "Should deliver again after cooldown expires")

	EventBus.ambient_moment_delivered.disconnect(cb)


# ── Random Chance Trigger ────────────────────────────────────────────────────


func test_random_chance_trigger_never_fires_at_zero() -> void:
	var def := _make_def({
		"id": "chance_zero",
		"category": "hallway",
		"trigger_category": "random_chance",
		"trigger_value": "0.0",
	})
	# With probability 0.0, randf() < 0.0 is always false.
	assert_false(
		_sys._check_trigger(def, 0),
		"random_chance with 0.0 should never trigger"
	)


func test_random_chance_trigger_always_fires_at_one() -> void:
	var def := _make_def({
		"id": "chance_one",
		"category": "hallway",
		"trigger_category": "random_chance",
		"trigger_value": "1.0",
	})
	# With probability 1.0, randf() < 1.0 is always true.
	assert_true(
		_sys._check_trigger(def, 0),
		"random_chance with 1.0 should always trigger"
	)


func test_random_chance_evaluates_full_pipeline_at_probability_one() -> void:
	var def := _make_def({
		"id": "chance_full",
		"category": "hallway",
		"trigger_category": "random_chance",
		"trigger_value": "1.0",
	})
	_sys._moment_definitions = [def]

	var delivered: Array[StringName] = []
	var cb := func(id: StringName, _dt: StringName, _ft: String, _ac: StringName) -> void:
		delivered.append(id)
	EventBus.ambient_moment_delivered.connect(cb)
	_sys._evaluate_moments(0)
	EventBus.ambient_moment_delivered.disconnect(cb)

	assert_eq(delivered.size(), 1, "random_chance=1.0 should produce a delivered signal")
	assert_eq(delivered[0], &"chance_full")


# ── Initial State ─────────────────────────────────────────────────────────────


func test_initial_state_cooldowns_and_queue_empty() -> void:
	var fresh := AmbientMomentsSystem.new()
	add_child_autofree(fresh)
	fresh._apply_state({})
	assert_eq(
		fresh._cooldowns.size(), 0,
		"Cooldown tracking must be empty on fresh boot"
	)
	assert_eq(
		fresh._delivery_queue.size(), 0,
		"Delivery queue must be empty on fresh boot"
	)
	assert_eq(
		fresh._state, AmbientMomentsSystem.State.IDLE,
		"State must be IDLE before first day_started"
	)


# ── Day Started Routing ───────────────────────────────────────────────────────


func test_day_started_transitions_state_from_idle_to_monitoring() -> void:
	_sys._state = AmbientMomentsSystem.State.IDLE
	_sys._on_day_started(1)
	assert_eq(
		_sys._state, AmbientMomentsSystem.State.MONITORING,
		"day_started handler should transition state from IDLE to MONITORING"
	)


func test_day_started_does_not_change_state_when_already_monitoring() -> void:
	_sys._state = AmbientMomentsSystem.State.MONITORING
	_sys._on_day_started(7)
	assert_eq(
		_sys._state, AmbientMomentsSystem.State.MONITORING,
		"day_started handler should not alter state when already MONITORING"
	)


func test_day_started_ticks_cooldowns() -> void:
	_sys._cooldowns["tracked_moment"] = 2
	_sys._on_day_started(3)
	assert_eq(
		int(_sys._cooldowns.get("tracked_moment", 0)),
		1,
		"day_started handler should decrement cooldowns by one"
	)


# ── Deduplication Guard ───────────────────────────────────────────────────────


func test_deduplication_guard_blocks_second_delivery_for_same_moment() -> void:
	var def := _make_def({
		"id": "first_sale",
		"category": "hallway",
		"trigger_category": "time_of_day",
		"trigger_value": "10",
		"cooldown_days": 3,
	})
	_sys._moment_definitions = [def]

	var delivered: Array[StringName] = []
	var cb := func(id: StringName, _dt: StringName, _ft: String, _ac: StringName) -> void:
		delivered.append(id)
	EventBus.ambient_moment_delivered.connect(cb)

	_sys._evaluate_moments(10)
	assert_eq(delivered.size(), 1, "first_sale should be delivered on first trigger")

	_sys._evaluate_moments(10)
	assert_eq(
		delivered.size(), 1,
		"Deduplication guard: second trigger for first_sale must be skipped"
	)

	EventBus.ambient_moment_delivered.disconnect(cb)


func test_enqueue_by_id_cancelled_when_moment_on_cooldown() -> void:
	_sys._cooldowns["first_sale"] = 2

	var cancelled: Array[StringName] = []
	var cb := func(id: StringName, _reason: StringName) -> void:
		cancelled.append(id)
	EventBus.ambient_moment_cancelled.connect(cb)
	_sys.enqueue_by_id(&"first_sale")
	EventBus.ambient_moment_cancelled.disconnect(cb)

	assert_eq(cancelled.size(), 1, "enqueue_by_id should cancel when moment is on cooldown")
	assert_eq(cancelled[0], &"first_sale")


# ── Pool Exhaustion ───────────────────────────────────────────────────────────


func test_pool_exhaustion_no_delivery_when_all_moments_on_cooldown() -> void:
	var def_a := _make_def({
		"id": "moment_alpha",
		"category": "hallway",
		"trigger_category": "time_of_day",
		"trigger_value": "12",
		"cooldown_days": 5,
	})
	var def_b := _make_def({
		"id": "moment_beta",
		"category": "hallway",
		"trigger_category": "time_of_day",
		"trigger_value": "12",
		"cooldown_days": 5,
	})
	_sys._moment_definitions = [def_a, def_b]
	_sys._cooldowns["moment_alpha"] = 5
	_sys._cooldowns["moment_beta"] = 5

	var delivered: Array[StringName] = []
	var cb := func(id: StringName, _dt: StringName, _ft: String, _ac: StringName) -> void:
		delivered.append(id)
	EventBus.ambient_moment_delivered.connect(cb)
	_sys._evaluate_moments(12)
	EventBus.ambient_moment_delivered.disconnect(cb)

	assert_eq(
		delivered.size(), 0,
		"Pool exhaustion: moment_delivered must not fire when all pool moments are on cooldown"
	)


# ── Moment Selection Determinism ─────────────────────────────────────────────


func test_weighted_pick_same_result_with_same_seed() -> void:
	var def_a := _make_def({"id": "pick_a", "scheduling_weight": 1.0})
	var def_b := _make_def({"id": "pick_b", "scheduling_weight": 1.0})
	var candidates: Array[AmbientMomentDefinition] = [def_a, def_b]

	seed(42)
	var first_pick: AmbientMomentDefinition = _sys._weighted_pick(candidates)

	seed(42)
	var second_pick: AmbientMomentDefinition = _sys._weighted_pick(candidates)

	assert_not_null(first_pick, "_weighted_pick should return a candidate from the pool")
	assert_not_null(second_pick, "_weighted_pick should return a candidate from the pool")
	assert_eq(
		first_pick.id,
		second_pick.id,
		"Same RNG seed must produce the same _weighted_pick result"
	)


# ── Save / Load Round-Trip ────────────────────────────────────────────────────


func test_save_load_roundtrip_preserves_cooldowns() -> void:
	_sys._cooldowns["first_sale"] = 3
	_sys._cooldowns["week_moment"] = 2
	_sys._delivery_history["first_sale"] = {
		"last_delivered_day": 4,
		"last_delivered_hour": 9,
		"total_deliveries": 1,
	}

	var saved: Dictionary = _sys.get_save_data()

	var fresh := AmbientMomentsSystem.new()
	add_child_autofree(fresh)
	fresh._apply_state({})
	fresh.load_save_data(saved)

	assert_eq(
		int(fresh._cooldowns.get("first_sale", 0)),
		3,
		"load_save_data should restore first_sale cooldown value"
	)
	assert_eq(
		int(fresh._cooldowns.get("week_moment", 0)),
		2,
		"load_save_data should restore week_moment cooldown value"
	)
	assert_eq(
		fresh.get_last_delivered_day(&"first_sale"),
		4,
		"load_save_data should restore delivery history"
	)


func test_save_load_roundtrip_preserves_delivery_queue() -> void:
	_sys._delivery_queue.append(&"queued_moment")

	var saved: Dictionary = _sys.get_save_data()

	var fresh := AmbientMomentsSystem.new()
	add_child_autofree(fresh)
	fresh._apply_state({})
	fresh.load_save_data(saved)

	assert_eq(
		fresh._delivery_queue.size(),
		1,
		"load_save_data should restore the delivery queue length"
	)
	assert_eq(
		fresh._delivery_queue[0],
		&"queued_moment",
		"load_save_data should restore the correct moment id in the queue"
	)


# ── Witnessed Log ─────────────────────────────────────────────────────────────


func test_witnessed_log_appended_on_dispatch() -> void:
	_sys._state = AmbientMomentsSystem.State.MONITORING
	var def := _make_def({
		"id": "log_test",
		"category": "hallway",
		"trigger_category": "time_of_day",
		"trigger_value": "9",
		"flavor_text": "A moment occurred.",
	})
	_sys._moment_definitions = [def]
	_sys._evaluate_moments(9)

	var log: Array[Dictionary] = _sys.get_witnessed_log()
	assert_eq(log.size(), 1, "Witnessed log should have one entry after dispatch")
	assert_eq(
		log[0].get("moment_id", ""),
		"log_test",
		"Log entry moment_id should match dispatched moment"
	)
	assert_eq(
		log[0].get("flavor_text", ""),
		"A moment occurred.",
		"Log entry flavor_text should match moment definition"
	)


func test_witnessed_log_capped_at_max_entries() -> void:
	_sys._state = AmbientMomentsSystem.State.MONITORING
	var total: int = AmbientMomentsSystem.MAX_WITNESSED_LOG + 5
	for i: int in range(total):
		_sys._append_witnessed_log(
			StringName("moment_%d" % i), "Flavor %d" % i
		)

	var log: Array[Dictionary] = _sys.get_witnessed_log()
	assert_eq(
		log.size(),
		AmbientMomentsSystem.MAX_WITNESSED_LOG,
		"Witnessed log must not exceed MAX_WITNESSED_LOG entries"
	)
	assert_eq(
		log[0].get("moment_id", ""),
		"moment_%d" % 5,
		"Oldest entries should be evicted when cap is reached"
	)


func test_save_load_roundtrip_preserves_witnessed_log() -> void:
	_sys._append_witnessed_log(&"persisted_moment", "Saved flavor text.")

	var saved: Dictionary = _sys.get_save_data()

	var fresh := AmbientMomentsSystem.new()
	add_child_autofree(fresh)
	fresh._apply_state({})
	fresh.load_save_data(saved)

	var log: Array[Dictionary] = fresh.get_witnessed_log()
	assert_eq(log.size(), 1, "Witnessed log should survive save/load round-trip")
	assert_eq(
		log[0].get("moment_id", ""),
		"persisted_moment",
		"moment_id should be preserved after load"
	)
	assert_eq(
		log[0].get("flavor_text", ""),
		"Saved flavor text.",
		"flavor_text should be preserved after load"
	)
