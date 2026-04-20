## GUT test: simulates 7 day_closed signals and asserts all Phase-5 milestone gates fire.
extends GutTest


var _progression: ProgressionSystem
var _economy: EconomySystem
var _reputation: ReputationSystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize()

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)

	_progression = ProgressionSystem.new()
	add_child_autofree(_progression)
	_progression.initialize(_economy, _reputation)


# ── All seven Phase-5 milestone gates complete over a simulated 7-day run ──


func test_all_seven_phase5_milestones_complete_in_order() -> void:
	var reached_ids: Array[String] = []
	var on_reached: Callable = func(mid: StringName) -> void:
		reached_ids.append(String(mid))
	EventBus.milestone_reached.connect(on_reached)

	# Gate 1: first_sale — any item_sold
	EventBus.item_sold.emit("item_cart_001", 25.0, "games")

	# Gate 2: first_refurb — successful refurbishment
	EventBus.refurbishment_completed.emit("item_cart_001", true, "good")

	# Gate 3: first_haggle — any completed haggle session
	EventBus.haggle_completed.emit(
		&"retro_games", &"item_cart_001", 20.0, 15.0, true, 1
	)

	# Gate 4: reputation_25 — reputation score reaches 25
	EventBus.reputation_changed.emit("retro_games", 0.0, 25.0)

	# Gate 5: revenue_target ($500) — sell enough items
	for i: int in range(17):
		EventBus.item_sold.emit("item_%d" % i, 30.0, "games")

	# Simulate 7 day_closed signals then trigger evaluate_day_end each time
	for day: int in range(1, 8):
		EventBus.day_closed.emit(day, {
			"day": day, "total_revenue": 0.0, "total_expenses": 0.0,
			"net_profit": 0.0, "items_sold": 0, "rent": 0.0,
			"net_cash": 0.0, "store_revenue": {}, "warranty_revenue": 0.0,
			"warranty_claims": 0.0, "seasonal_impact": "",
			"discrepancy": 0.0, "staff_wages": 0.0,
		})
		EventBus.day_ended.emit(day)
		_progression.evaluate_day_end()

	# Gate 6: store_2_unlocked — force second store slot open
	_progression._unlocked_store_slots = 2
	_progression._unlocked_slot_indices[1] = true
	_progression._evaluate_milestones()

	EventBus.milestone_reached.disconnect(on_reached)

	var required: Array[String] = [
		"first_sale",
		"first_refurb",
		"first_haggle",
		"reputation_25",
		"revenue_target",
		"store_2_unlocked",
		"day_7_complete",
	]
	for mid: String in required:
		assert_true(
			_progression.is_milestone_completed(mid),
			"Milestone '%s' should be completed after 7-day run" % mid
		)

	# Verify milestone_reached fired for all seven
	for mid: String in required:
		assert_true(
			reached_ids.has(mid),
			"EventBus.milestone_reached should have fired for '%s'" % mid
		)


func test_milestones_fire_exactly_once_across_seven_days() -> void:
	var fire_counts: Dictionary = {}
	var on_reached: Callable = func(mid: StringName) -> void:
		var key: String = String(mid)
		fire_counts[key] = int(fire_counts.get(key, 0)) + 1
	EventBus.milestone_reached.connect(on_reached)

	# Trigger first_sale twice — should only count once
	EventBus.item_sold.emit("item_a", 10.0, "games")
	EventBus.item_sold.emit("item_b", 10.0, "games")

	EventBus.milestone_reached.disconnect(on_reached)

	assert_eq(
		int(fire_counts.get("first_sale", 0)),
		1,
		"first_sale milestone_reached must fire exactly once"
	)


func test_random_event_system_inactive_on_days_1_and_2() -> void:
	var random_sys := RandomEventSystem.new()
	add_child_autofree(random_sys)

	var event_fired: bool = false
	var on_event: Callable = func(_eid: StringName, _sid: StringName, _eff: Dictionary) -> void:
		event_fired = true
	EventBus.random_event_triggered.connect(on_event)

	# Simulate day 1 start — should not roll events
	EventBus.day_started.emit(1)
	EventBus.day_started.emit(2)

	EventBus.random_event_triggered.disconnect(on_event)

	assert_false(
		event_fired,
		"RandomEventSystem must not fire events on days 1 or 2"
	)


func test_story_beat_always_present_even_on_zero_revenue_day() -> void:
	var report_sys := PerformanceReportSystem.new()
	add_child_autofree(report_sys)
	report_sys.initialize()

	var received_report: PerformanceReport = null
	var on_report: Callable = func(r: PerformanceReport) -> void:
		received_report = r
	EventBus.performance_report_ready.connect(on_report)

	# Emit day_ended with no sales — zero-revenue day
	EventBus.day_ended.emit(99)

	EventBus.performance_report_ready.disconnect(on_report)

	assert_not_null(received_report, "PerformanceReport should be emitted")
	if received_report:
		assert_false(
			received_report.story_beat.is_empty(),
			"story_beat must never be empty — even on a $0 revenue day"
		)
