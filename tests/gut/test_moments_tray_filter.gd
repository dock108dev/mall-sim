## Tests for AmbientMomentsSystem: draw filter axes and 3-slot concurrency.
extends GutTest


var _sys: AmbientMomentsSystem


func _make_def(overrides: Dictionary = {}) -> AmbientMomentDefinition:
	var d := AmbientMomentDefinition.new()
	d.id = overrides.get("id", "test_moment")
	d.category = overrides.get("category", "any")
	d.trigger_category = overrides.get("trigger_category", "random_chance")
	d.trigger_value = overrides.get("trigger_value", "1.0")
	d.scheduling_weight = overrides.get("scheduling_weight", 1.0)
	d.cooldown_days = overrides.get("cooldown_days", 0)
	d.duration_seconds = overrides.get("duration_seconds", 9999.0)
	d.store_id = overrides.get("store_id", "")
	d.season_id = overrides.get("season_id", "")
	d.min_day = overrides.get("min_day", 0)
	d.max_day = overrides.get("max_day", 0)
	return d


func before_each() -> void:
	_sys = AmbientMomentsSystem.new()
	add_child_autofree(_sys)
	_sys._apply_state({})
	_sys._active_store_id = &"retro_games"


# ── store_id filter ──────────────────────────────────────────────────────────


func test_store_filter_passes_when_store_matches() -> void:
	var def := _make_def({"store_id": "retro_games"})
	assert_true(
		_sys._matches_extended_filter(def),
		"Moment should be eligible when active store matches store_id"
	)


func test_store_filter_blocks_when_store_differs() -> void:
	var def := _make_def({"store_id": "sports_memorabilia"})
	assert_false(
		_sys._matches_extended_filter(def),
		"Moment should not be eligible when active store differs from store_id"
	)


func test_store_filter_passes_when_store_id_empty() -> void:
	var def := _make_def({"store_id": ""})
	assert_true(
		_sys._matches_extended_filter(def),
		"Moment with empty store_id is eligible in any store"
	)


# ── season_id filter ─────────────────────────────────────────────────────────


func test_season_filter_passes_when_season_matches() -> void:
	_sys.set_current_season_id("winter")
	var def := _make_def({"season_id": "winter"})
	assert_true(
		_sys._matches_extended_filter(def),
		"Moment should be eligible when current season matches season_id"
	)


func test_season_filter_blocks_when_season_differs() -> void:
	_sys.set_current_season_id("summer")
	var def := _make_def({"season_id": "winter"})
	assert_false(
		_sys._matches_extended_filter(def),
		"Moment should not be eligible when season differs"
	)


func test_season_filter_passes_when_season_id_empty() -> void:
	_sys.set_current_season_id("summer")
	var def := _make_def({"season_id": ""})
	assert_true(
		_sys._matches_extended_filter(def),
		"Moment with empty season_id is eligible in any season"
	)


# ── min_day filter ───────────────────────────────────────────────────────────


func test_min_day_blocks_before_threshold() -> void:
	# GameManager.current_day defaults to 0 in headless test context.
	var def := _make_def({"min_day": 5})
	assert_false(
		_sys._matches_extended_filter(def),
		"Moment should not be eligible before min_day"
	)


func test_min_day_passes_when_zero() -> void:
	var def := _make_def({"min_day": 0})
	assert_true(
		_sys._matches_extended_filter(def),
		"min_day of 0 means no minimum constraint"
	)


# ── max_day filter ───────────────────────────────────────────────────────────


func test_max_day_passes_when_zero() -> void:
	var def := _make_def({"max_day": 0})
	assert_true(
		_sys._matches_extended_filter(def),
		"max_day of 0 means no maximum constraint"
	)


func test_max_day_passes_on_exact_day() -> void:
	# current_day is 0 in test context; max_day=0 means unconstrained; use large value.
	var def := _make_def({"max_day": 999})
	assert_true(
		_sys._matches_extended_filter(def),
		"Moment should be eligible when current day is within max_day"
	)


# ── combined filters ─────────────────────────────────────────────────────────


func test_all_filters_pass_together() -> void:
	_sys.set_current_season_id("spring")
	var def := _make_def({
		"store_id": "retro_games",
		"season_id": "spring",
		"min_day": 0,
		"max_day": 999,
	})
	assert_true(
		_sys._matches_extended_filter(def),
		"Moment should pass when all filter fields match"
	)


func test_single_failing_filter_blocks_moment() -> void:
	_sys.set_current_season_id("spring")
	var def := _make_def({
		"store_id": "retro_games",
		"season_id": "winter",
	})
	assert_false(
		_sys._matches_extended_filter(def),
		"Moment blocked when any filter fails (season mismatch)"
	)


# ── 3-slot concurrency cap ────────────────────────────────────────────────────


func test_three_slots_active_simultaneously() -> void:
	_sys._state = AmbientMomentsSystem.State.MONITORING
	_sys.enqueue_by_id(&"m1")
	_sys.enqueue_by_id(&"m2")
	_sys.enqueue_by_id(&"m3")
	assert_eq(
		_sys.get_active_moment_count(), 3,
		"Three moments should be simultaneously active"
	)


func test_fourth_moment_waits_in_queue() -> void:
	_sys._state = AmbientMomentsSystem.State.MONITORING
	_sys.enqueue_by_id(&"m1")
	_sys.enqueue_by_id(&"m2")
	_sys.enqueue_by_id(&"m3")
	_sys.enqueue_by_id(&"m4")
	assert_eq(
		_sys.get_active_moment_count(), 3,
		"Active slot cap should not exceed 3"
	)
	assert_eq(
		_sys.get_queue_size(), 1,
		"Fourth moment should wait in the delivery queue"
	)


func test_moment_displayed_signal_emitted() -> void:
	_sys._state = AmbientMomentsSystem.State.MONITORING
	watch_signals(EventBus)
	_sys.enqueue_by_id(&"signal_test")
	assert_signal_emitted(
		EventBus, "moment_displayed",
		"moment_displayed should fire when a moment becomes active"
	)


func test_moment_expired_signal_emitted_after_tick() -> void:
	_sys._state = AmbientMomentsSystem.State.MONITORING
	_sys._delivery_queue.append(&"expiry_test")
	_sys._active_moments[&"expiry_test"] = 0.01
	watch_signals(EventBus)
	_sys._tick_active_moments(1.0)
	assert_signal_emitted(
		EventBus, "moment_expired",
		"moment_expired should fire when a moment's timer runs out"
	)


func test_moment_queue_empty_emitted_when_all_expire() -> void:
	_sys._state = AmbientMomentsSystem.State.MONITORING
	_sys._active_moments[&"only_moment"] = 0.01
	watch_signals(EventBus)
	_sys._tick_active_moments(1.0)
	assert_signal_emitted(
		EventBus, "moment_queue_empty",
		"moment_queue_empty should fire when tray and queue both empty"
	)


func test_slot_freed_when_moment_expires() -> void:
	_sys._state = AmbientMomentsSystem.State.MONITORING
	_sys.enqueue_by_id(&"s1")
	_sys.enqueue_by_id(&"s2")
	_sys.enqueue_by_id(&"s3")
	_sys.enqueue_by_id(&"s4")
	assert_eq(_sys.get_active_moment_count(), 3)
	assert_eq(_sys.get_queue_size(), 1)
	_sys._active_moments[&"s1"] = 0.01
	_sys._tick_active_moments(1.0)
	assert_eq(
		_sys.get_active_moment_count(), 3,
		"Freed slot should be filled by queued moment"
	)
	assert_eq(
		_sys.get_queue_size(), 0,
		"Waiting queue should be empty after slot freed"
	)
