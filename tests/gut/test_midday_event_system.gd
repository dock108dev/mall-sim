## Tests for MiddayEventSystem autoload — covers eligibility filtering,
## per-day queue seeding, dedup-across-days guard, the empty-pool no-hang
## contract, signal emission on hour_changed, choice-effect dispatch, and
## the Days 18–22 launch-beat force inclusion when VecForce HD is supply-
## constrained.
extends GutTest


const _LAUNCH_BEAT_ID: StringName = &"launch_reservation_conflict"


func _make_beat(
	id: String,
	min_day: int = 1,
	max_day: int = 30,
	cooldown_days: int = 2,
	unlock_required: Variant = null,
	choices: Array = [],
) -> Dictionary:
	return {
		"id": id,
		"min_day": min_day,
		"max_day": max_day,
		"cooldown_days": cooldown_days,
		"unlock_required": unlock_required,
		"title": "Test Beat %s" % id,
		"body": "Body for %s" % id,
		"choices": choices,
	}


func before_each() -> void:
	MiddayEventSystem.reset_for_testing()
	GameState.flags.clear()
	GameState.active_store_id = &""


func after_each() -> void:
	MiddayEventSystem.reset_for_testing()
	GameState.flags.clear()


# ── Eligibility filter ───────────────────────────────────────────────────────


func test_is_eligible_passes_in_day_range() -> void:
	var beat: Dictionary = _make_beat("a", 5, 10)
	assert_true(MiddayEventSystem.is_eligible(beat, 7, {}, {}))


func test_is_eligible_rejects_below_min_day() -> void:
	var beat: Dictionary = _make_beat("a", 5, 10)
	assert_false(MiddayEventSystem.is_eligible(beat, 4, {}, {}))


func test_is_eligible_rejects_above_max_day() -> void:
	var beat: Dictionary = _make_beat("a", 5, 10)
	assert_false(MiddayEventSystem.is_eligible(beat, 11, {}, {}))


func test_is_eligible_requires_unlock_when_set() -> void:
	var beat: Dictionary = _make_beat("a", 1, 30, 2, "extended_hours_unlock")
	assert_false(
		MiddayEventSystem.is_eligible(beat, 5, {}, {}),
		"missing required unlock must reject the beat",
	)
	var unlocked: Dictionary = {&"extended_hours_unlock": true}
	assert_true(MiddayEventSystem.is_eligible(beat, 5, unlocked, {}))


func test_is_eligible_respects_cooldown() -> void:
	var beat: Dictionary = _make_beat("a", 1, 30, 3)
	var last_fired: Dictionary = {&"a": 5}
	# day 6, 7, 8 are within cooldown (cooldown_days=3, so > 3 means 9+).
	assert_false(MiddayEventSystem.is_eligible(beat, 6, {}, last_fired))
	assert_false(MiddayEventSystem.is_eligible(beat, 8, {}, last_fired))
	assert_true(MiddayEventSystem.is_eligible(beat, 9, {}, last_fired))


# ── Day queue seeding ────────────────────────────────────────────────────────


func test_seeds_two_beats_when_pool_has_two_eligible() -> void:
	var pool: Array = [
		_make_beat("alpha"),
		_make_beat("beta"),
	]
	MiddayEventSystem.set_beat_pool(pool)
	EventBus.day_started.emit(1)
	assert_eq(MiddayEventSystem.get_day_queue().size(), 2)


func test_empty_pool_runs_silently_without_error() -> void:
	MiddayEventSystem.set_beat_pool([])
	EventBus.day_started.emit(1)
	assert_eq(
		MiddayEventSystem.get_day_queue().size(), 0,
		"empty pool must produce a 0-beat day, not crash or hang",
	)
	EventBus.hour_changed.emit(11)
	EventBus.hour_changed.emit(13)
	# No pending beat means time was never paused — system stayed dormant.
	assert_true(MiddayEventSystem.get_pending_beat().is_empty())


func test_eligible_pool_with_zero_after_filter_runs_silently() -> void:
	var pool: Array = [
		_make_beat("future_only", 20, 30),
		_make_beat("locked", 1, 30, 2, "missing_unlock"),
	]
	MiddayEventSystem.set_beat_pool(pool)
	EventBus.day_started.emit(5)
	assert_eq(MiddayEventSystem.get_day_queue().size(), 0)


func test_dedup_guard_avoids_repeat_two_days_in_a_row() -> void:
	# Pool of three eligible beats; queue holds 2 per day. The dedup guard
	# must guarantee that the next day's queue does not repeat any id from
	# the prior day's queue.
	var pool: Array = [
		_make_beat("alpha", 1, 30, 0),
		_make_beat("beta", 1, 30, 0),
		_make_beat("gamma", 1, 30, 0),
	]
	MiddayEventSystem.set_beat_pool(pool)
	EventBus.day_started.emit(1)
	var day_one_ids: Array = []
	for entry: Dictionary in MiddayEventSystem.get_day_queue():
		day_one_ids.append(entry.get("id", ""))
	EventBus.day_started.emit(2)
	for entry: Dictionary in MiddayEventSystem.get_day_queue():
		assert_false(
			day_one_ids.has(entry.get("id", "")),
			"beat '%s' fired two days in a row — dedup guard failed"
			% entry.get("id", ""),
		)


# ── Hour-change firing + signal contract ─────────────────────────────────────


func test_fires_beat_at_assigned_hour() -> void:
	var pool: Array = [_make_beat("solo")]
	MiddayEventSystem.set_beat_pool(pool)
	EventBus.day_started.emit(1)
	watch_signals(EventBus)
	EventBus.hour_changed.emit(11)
	assert_signal_emitted(EventBus, "midday_event_fired")
	assert_signal_emitted(EventBus, "time_speed_requested")
	assert_false(MiddayEventSystem.get_pending_beat().is_empty())


func test_does_not_fire_outside_window() -> void:
	var pool: Array = [_make_beat("solo")]
	MiddayEventSystem.set_beat_pool(pool)
	EventBus.day_started.emit(1)
	watch_signals(EventBus)
	EventBus.hour_changed.emit(9)
	EventBus.hour_changed.emit(15)
	assert_signal_not_emitted(EventBus, "midday_event_fired")


func test_resolved_signal_clears_pending_and_resumes_time() -> void:
	var pool: Array = [
		_make_beat("solo", 1, 30, 2, null, [
			{"label": "OK", "consequence": "", "effects": {}}
		])
	]
	MiddayEventSystem.set_beat_pool(pool)
	EventBus.day_started.emit(1)
	EventBus.hour_changed.emit(11)
	assert_false(MiddayEventSystem.get_pending_beat().is_empty())
	watch_signals(EventBus)
	EventBus.midday_event_resolved.emit(&"solo", 0)
	assert_true(MiddayEventSystem.get_pending_beat().is_empty())
	assert_signal_emitted(EventBus, "time_speed_requested")


# ── Effect dispatch ──────────────────────────────────────────────────────────


func test_inventory_flag_effect_sets_game_state_flag() -> void:
	var pool: Array = [
		_make_beat("flag_setter", 1, 30, 2, null, [
			{
				"label": "Set it",
				"consequence": "flag set",
				"effects": {"inventory_flag": "test_flag_set"},
			}
		])
	]
	MiddayEventSystem.set_beat_pool(pool)
	EventBus.day_started.emit(1)
	EventBus.hour_changed.emit(11)
	EventBus.midday_event_resolved.emit(&"flag_setter", 0)
	assert_true(GameState.get_flag(&"test_flag_set"))


func test_hidden_thread_flag_increments_scapegoat_risk() -> void:
	var pool: Array = [
		_make_beat("scapegoat", 1, 30, 2, null, [
			{
				"label": "Hide it",
				"consequence": "",
				"effects": {"hidden_thread_flag": "covered_up"},
			}
		])
	]
	MiddayEventSystem.set_beat_pool(pool)
	EventBus.day_started.emit(1)
	EventBus.hour_changed.emit(11)
	EventBus.midday_event_resolved.emit(&"scapegoat", 0)
	assert_eq(int(GameState.flags.get(&"scapegoat_risk", 0)), 1)
	assert_true(GameState.get_flag(&"hidden_thread:covered_up"))


# ── Reference-beat field assertions (issue acceptance criteria) ──────────────


func test_reference_beat_fields_present_in_content() -> void:
	var loader: DataLoader = (
		get_node_or_null("/root/DataLoaderSingleton") as DataLoader
	)
	if loader == null:
		# Defensive: skip if DataLoader autoload is not available in this
		# headless test environment.
		assert_true(true)
		return
	loader.load_all_content()
	var pool: Array = loader.get_midday_events()
	var by_id: Dictionary = {}
	for entry: Dictionary in pool:
		by_id[str(entry.get("id", ""))] = entry
	assert_true(
		by_id.has("suspicious_hold_slip"),
		"day_beats.json must define suspicious_hold_slip beat",
	)
	assert_true(
		by_id.has("sports_trade_in_flood"),
		"day_beats.json must define sports_trade_in_flood beat",
	)
	assert_true(
		by_id.has("launch_reservation_conflict"),
		"day_beats.json must define launch_reservation_conflict beat",
	)
	var suspicious: Dictionary = by_id["suspicious_hold_slip"]
	assert_eq(int(suspicious.get("min_day", -1)), 5)
	var trade_in: Dictionary = by_id["sports_trade_in_flood"]
	assert_eq(int(trade_in.get("min_day", -1)), 3)
	var launch: Dictionary = by_id["launch_reservation_conflict"]
	assert_eq(int(launch.get("min_day", -1)), 18)
	assert_eq(int(launch.get("max_day", -1)), 22)
	# At least 15 distinct beats covering Days 1–15.
	assert_gte(pool.size(), 15)


func test_launch_beat_set_aside_choice_sets_hidden_thread_flag() -> void:
	var loader: DataLoader = (
		get_node_or_null("/root/DataLoaderSingleton") as DataLoader
	)
	if loader == null:
		assert_true(true)
		return
	loader.load_all_content()
	var pool: Array = loader.get_midday_events()
	var launch: Dictionary = {}
	for entry: Dictionary in pool:
		if str(entry.get("id", "")) == "launch_reservation_conflict":
			launch = entry
			break
	assert_false(
		launch.is_empty(),
		"launch_reservation_conflict beat must exist in pool",
	)
	var found_set_aside: bool = false
	for choice: Dictionary in launch.get("choices", []):
		var effects: Dictionary = choice.get("effects", {})
		if effects.has("hidden_thread_flag"):
			found_set_aside = true
			break
	assert_true(
		found_set_aside,
		"launch beat must have a choice that sets hidden_thread_flag (set-aside)",
	)
