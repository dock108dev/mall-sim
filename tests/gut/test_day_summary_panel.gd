## Tests for ISSUE-109 DaySummaryPanel: haggle stats, milestones,
## tier change, review inventory, and next_day_confirmed signal.
extends GutTest


var _system: PerformanceReportSystem
var _economy: EconomySystem
var _saved_tier: StringName = &"normal"
var _saved_owned_stores: Array = []
var _saved_current_store_id: StringName = &""
var _saved_day_started_connections: Array[Callable] = []
var _saved_day_ended_connections: Array[Callable] = []


func before_each() -> void:
	_saved_tier = DifficultySystemSingleton.get_current_tier_id()
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_current_store_id = GameManager.current_store_id
	DifficultySystemSingleton.set_tier(&"normal")
	GameManager.owned_stores = []
	GameManager.current_store_id = &""
	_saved_day_started_connections = _disconnect_signal(EventBus.day_started)
	_saved_day_ended_connections = _disconnect_signal(EventBus.day_ended)
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize()

	_system = PerformanceReportSystem.new()
	add_child_autofree(_system)
	_system.initialize()


func after_each() -> void:
	if _system != null:
		_system.free()
		_system = null
	if _economy != null:
		_economy.free()
		_economy = null
	_restore_signal(EventBus.day_started, _saved_day_started_connections)
	_restore_signal(EventBus.day_ended, _saved_day_ended_connections)
	GameManager.owned_stores = _saved_owned_stores.duplicate()
	GameManager.current_store_id = _saved_current_store_id
	DifficultySystemSingleton.set_tier(_saved_tier)


func _disconnect_signal(signal_ref: Signal) -> Array[Callable]:
	var callables: Array[Callable] = []
	for connection: Dictionary in signal_ref.get_connections():
		var callable: Callable = connection.get("callable", Callable()) as Callable
		if callable.is_valid():
			callables.append(callable)
			signal_ref.disconnect(callable)
	return callables


func _restore_signal(signal_ref: Signal, callables: Array[Callable]) -> void:
	for callable: Callable in callables:
		if callable.is_valid() and not signal_ref.is_connected(callable):
			signal_ref.connect(callable)


func test_haggle_wins_tracked() -> void:
	EventBus.day_started.emit(1)
	EventBus.haggle_completed.emit(&"", &"item_a", 25.0, 30.0, true, 1)
	EventBus.haggle_completed.emit(&"", &"item_b", 30.0, 35.0, true, 1)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.haggle_wins, 2)


func test_haggle_losses_tracked() -> void:
	EventBus.day_started.emit(1)
	EventBus.haggle_failed.emit("item_a", 1)
	EventBus.haggle_failed.emit("item_b", 2)
	EventBus.haggle_failed.emit("item_c", 3)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.haggle_losses, 3)


func test_haggle_counts_reset_on_new_day() -> void:
	EventBus.day_started.emit(1)
	EventBus.haggle_completed.emit(&"", &"item_a", 25.0, 30.0, true, 1)
	EventBus.haggle_failed.emit("item_b", 1)
	EventBus.day_ended.emit(1)

	EventBus.day_started.emit(2)
	EventBus.day_ended.emit(2)
	var report: PerformanceReport = _system.get_history()[1]
	assert_eq(report.haggle_wins, 0)
	assert_eq(report.haggle_losses, 0)


func test_milestones_tracked() -> void:
	EventBus.day_started.emit(1)
	EventBus.milestone_completed.emit("first_sale", "First Sale", "$50")
	EventBus.milestone_completed.emit("big_day", "Big Day", "$100")
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.milestones_unlocked.size(), 2)
	assert_has(report.milestones_unlocked, "First Sale")
	assert_has(report.milestones_unlocked, "Big Day")


func test_milestones_reset_on_new_day() -> void:
	EventBus.day_started.emit(1)
	EventBus.milestone_completed.emit("first_sale", "First Sale", "$50")
	EventBus.day_ended.emit(1)

	EventBus.day_started.emit(2)
	EventBus.day_ended.emit(2)
	var report: PerformanceReport = _system.get_history()[1]
	assert_eq(report.milestones_unlocked.size(), 0)


func test_top_item_quantity_tracked() -> void:
	EventBus.day_started.emit(1)
	EventBus.item_sold.emit("card_a", 10.0, "cards")
	EventBus.item_sold.emit("card_a", 10.0, "cards")
	EventBus.item_sold.emit("card_a", 10.0, "cards")
	EventBus.item_sold.emit("card_b", 50.0, "cards")
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_eq(report.top_item_sold, "card_b")
	assert_eq(report.top_item_quantity, 1)


func test_tier_change_detected() -> void:
	EventBus.day_started.emit(1)
	EventBus.reputation_changed.emit("store_a", 0.0, 20.0)
	EventBus.reputation_changed.emit("store_a", 0.0, 55.0)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_true(report.tier_changed)
	assert_eq(report.new_tier_name, "Reputable")


func test_no_tier_change_within_same_tier() -> void:
	EventBus.day_started.emit(1)
	EventBus.reputation_changed.emit("store_a", 0.0, 30.0)
	EventBus.reputation_changed.emit("store_a", 0.0, 40.0)
	EventBus.day_ended.emit(1)
	var report: PerformanceReport = _system.get_history()[0]
	assert_false(report.tier_changed)


func test_report_serialization_round_trip_new_fields() -> void:
	var report := PerformanceReport.new()
	report.day = 3
	report.haggle_wins = 5
	report.haggle_losses = 2
	report.tier_changed = true
	report.new_tier_name = "Legendary"
	report.top_item_quantity = 8
	report.milestones_unlocked = ["First Sale", "Big Day"]

	var data: Dictionary = report.to_dict()
	var restored: PerformanceReport = PerformanceReport.from_dict(data)

	assert_eq(restored.haggle_wins, 5)
	assert_eq(restored.haggle_losses, 2)
	assert_true(restored.tier_changed)
	assert_eq(restored.new_tier_name, "Legendary")
	assert_eq(restored.top_item_quantity, 8)
	assert_eq(restored.milestones_unlocked.size(), 2)
	assert_has(restored.milestones_unlocked, "First Sale")


func test_save_load_preserves_haggle_counts() -> void:
	EventBus.day_started.emit(1)
	EventBus.haggle_completed.emit(&"", &"item_a", 25.0, 30.0, true, 1)
	EventBus.haggle_failed.emit("item_b", 1)
	var save_data: Dictionary = _system.get_save_data()

	var loaded: PerformanceReportSystem = (
		PerformanceReportSystem.new()
	)
	add_child_autofree(loaded)
	loaded.initialize()
	loaded.load_save_data(save_data)

	EventBus.day_ended.emit(1)
	var history: Array[PerformanceReport] = loaded.get_history()
	assert_eq(history.size(), 1)


func test_next_day_confirmed_signal_exists() -> void:
	assert_true(
		EventBus.has_signal("next_day_confirmed"),
		"EventBus must have next_day_confirmed signal"
	)


func test_day_summary_emits_next_day_confirmed() -> void:
	var summary: DaySummary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(summary)

	var signal_fired: Array = [false]
	EventBus.next_day_confirmed.connect(
		func() -> void: signal_fired[0] = true
	)
	summary._on_continue_pressed()
	assert_true(signal_fired[0], "next_day_confirmed should fire")


func test_net_profit_positive_shows_green() -> void:
	var summary: DaySummary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(summary)
	summary.show_summary(1, 100.0, 50.0, 50.0, 5)
	var profit_label: Label = summary._profit_label
	assert_eq(profit_label.text, "NET PROFIT: +$50.00")
	var color: Color = profit_label.get_theme_color("font_color")
	assert_eq(color, UIThemeConstants.get_positive_color())


func test_net_profit_negative_shows_red() -> void:
	var summary: DaySummary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(summary)
	summary.show_summary(1, 50.0, 100.0, -50.0, 3)
	var profit_label: Label = summary._profit_label
	assert_eq(profit_label.text, "NET LOSS: -$50.00")
	var color: Color = profit_label.get_theme_color("font_color")
	assert_eq(color, DaySummary.NET_PROFIT_NEGATIVE_COLOR)


func test_net_profit_zero_shows_white() -> void:
	var summary: DaySummary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(summary)
	summary.show_summary(1, 100.0, 100.0, 0.0, 2)
	var profit_label: Label = summary._profit_label
	assert_eq(profit_label.text, "NET PROFIT: $0.00")
	var color: Color = profit_label.get_theme_color("font_color")
	assert_eq(color, DaySummary.NET_PROFIT_ZERO_COLOR)


func test_net_profit_updates_on_new_report() -> void:
	var summary: DaySummary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(summary)
	summary.show_summary(1, 50.0, 100.0, -50.0, 1)
	assert_eq(summary._profit_label.text, "NET LOSS: -$50.00")
	var report := PerformanceReport.new()
	report.profit = 200.0
	summary._on_performance_report_ready(report)
	assert_eq(summary._profit_label.text, "NET PROFIT: +$200.00")
	var color: Color = summary._profit_label.get_theme_color(
		"font_color"
	)
	assert_eq(color, UIThemeConstants.get_positive_color())


func test_day_summary_review_inventory_signal() -> void:
	var summary: DaySummary = preload(
		"res://game/scenes/ui/day_summary.tscn"
	).instantiate() as DaySummary
	add_child_autofree(summary)

	var signal_fired: Array = [false]
	summary.review_inventory_requested.connect(
		func() -> void: signal_fired[0] = true
	)
	summary._on_review_inventory_pressed()
	assert_true(
		signal_fired[0],
		"review_inventory_requested should fire"
	)
