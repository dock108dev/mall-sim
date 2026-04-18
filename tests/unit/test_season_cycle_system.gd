## GUT unit tests for SeasonCycleSystem phase tracking, demand multipliers, and save/load.
extends GutTest


var _season: SeasonCycleSystem
var _shift_signals: Array[Dictionary]
var _announce_signals: Array[Dictionary]
var _on_shifted: Callable
var _on_announced: Callable


func before_each() -> void:
	_season = SeasonCycleSystem.new()
	_shift_signals = []
	_announce_signals = []
	_on_shifted = func(
		new_hot: String, old_hot: String
	) -> void:
		_shift_signals.append({
			"new_hot": new_hot, "old_hot": old_hot,
		})
	_on_announced = func(
		next_hot: String, days_until: int
	) -> void:
		_announce_signals.append({
			"next_hot": next_hot, "days_until": days_until,
		})
	EventBus.season_cycle_shifted.connect(_on_shifted)
	EventBus.season_cycle_announced.connect(_on_announced)


func after_each() -> void:
	if EventBus.season_cycle_shifted.is_connected(_on_shifted):
		EventBus.season_cycle_shifted.disconnect(_on_shifted)
	if EventBus.season_cycle_announced.is_connected(_on_announced):
		EventBus.season_cycle_announced.disconnect(_on_announced)


# --- test_initialize_sets_correct_phase ---


func test_initialize_sets_correct_phase() -> void:
	_season.initialize(1)
	var hot_league: String = _season.get_hot_league()
	assert_true(
		SeasonCycleSystem.LEAGUES.has(hot_league),
		"Hot league should be one of the known leagues"
	)
	var phase: SeasonCycleSystem.SeasonPhase = _season.get_league_phase(
		hot_league
	)
	assert_eq(
		phase,
		SeasonCycleSystem.SeasonPhase.HOT,
		"The hot league should have phase HOT after initialize"
	)
	assert_eq(
		_season.get_save_data()["current_day"],
		1,
		"Current day should match the starting day"
	)


# --- test_process_day_advances_phase ---


func test_process_day_advances_phase() -> void:
	_season.load_save_data({
		"hot_index": 0,
		"next_rotation_day": 5,
		"announced": false,
		"current_day": 1,
	})
	var initial_hot: String = _season.get_hot_league()
	assert_eq(
		initial_hot,
		SeasonCycleSystem.LEAGUES[0],
		"Hot league should be the first league"
	)

	for day: int in range(2, 6):
		_season.process_day(day)

	var new_hot: String = _season.get_hot_league()
	assert_ne(
		new_hot,
		initial_hot,
		"Hot league should change after crossing the rotation day"
	)
	assert_eq(
		new_hot,
		SeasonCycleSystem.LEAGUES[1],
		"Hot league should advance to the next league in order"
	)
	assert_eq(
		_shift_signals.size(),
		1,
		"Exactly one season_cycle_shifted signal should have fired"
	)
	assert_eq(
		_shift_signals[0]["old_hot"],
		initial_hot,
		"Shifted signal should report old hot league"
	)
	assert_eq(
		_shift_signals[0]["new_hot"],
		new_hot,
		"Shifted signal should report new hot league"
	)


# --- test_get_demand_multiplier_in_season ---


func test_get_demand_multiplier_in_season() -> void:
	_season.load_save_data({
		"hot_index": 0,
		"next_rotation_day": 20,
		"announced": false,
		"current_day": 1,
	})
	var item: ItemInstance = _make_sports_item(
		SeasonCycleSystem.LEAGUES[0]
	)
	var multiplier: float = _season.get_season_multiplier(item)
	assert_gt(
		multiplier,
		1.0,
		"Demand multiplier for the hot league should be > 1.0"
	)
	assert_almost_eq(
		multiplier,
		SeasonCycleSystem.PHASE_MULTIPLIERS[
			SeasonCycleSystem.SeasonPhase.HOT
		],
		0.001,
		"Multiplier should match the HOT phase multiplier"
	)


# --- test_get_demand_multiplier_off_season ---


func test_get_demand_multiplier_off_season() -> void:
	_season.load_save_data({
		"hot_index": 0,
		"next_rotation_day": 20,
		"announced": false,
		"current_day": 1,
	})
	var item: ItemInstance = _make_sports_item(
		"memorabilia"
	)
	var multiplier: float = _season.get_season_multiplier(item)
	assert_eq(
		multiplier,
		1.0,
		"Sports memorabilia without an active league tag should return 1.0"
	)

	var non_sports_def := ItemDefinition.new()
	non_sports_def.id = "test_generic"
	non_sports_def.store_type = "retro_games"
	non_sports_def.tags = PackedStringArray(["platformer"])
	var non_sports_item: ItemInstance = ItemInstance.new()
	non_sports_item.definition = non_sports_def
	var generic_mult: float = _season.get_season_multiplier(non_sports_item)
	assert_eq(
		generic_mult,
		1.0,
		"Non-sports items should always return 1.0"
	)


# --- test_save_load_round_trip ---


func test_save_load_round_trip() -> void:
	_season.load_save_data({
		"hot_index": 2,
		"next_rotation_day": 15,
		"announced": true,
		"current_day": 10,
	})
	var saved: Dictionary = _season.get_save_data()

	var restored := SeasonCycleSystem.new()
	restored.load_save_data(saved)

	var restored_data: Dictionary = restored.get_save_data()
	assert_eq(
		restored_data["hot_index"],
		2,
		"Hot index should survive round trip"
	)
	assert_eq(
		restored_data["next_rotation_day"],
		15,
		"Next rotation day should survive round trip"
	)
	assert_eq(
		restored_data["announced"],
		true,
		"Announced flag should survive round trip"
	)
	assert_eq(
		restored_data["current_day"],
		10,
		"Current day should survive round trip"
	)
	assert_eq(
		restored.get_hot_league(),
		_season.get_hot_league(),
		"Hot league should match after round trip"
	)
	assert_eq(
		restored.get_league_phase(SeasonCycleSystem.LEAGUES[0]),
		_season.get_league_phase(SeasonCycleSystem.LEAGUES[0]),
		"League phases should match after round trip"
	)


# --- Helpers ---


func _make_sports_item(league_tag: String) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_%s_item" % league_tag.to_lower()
	def.store_type = "sports_memorabilia"
	def.base_price = 10.0
	def.tags = PackedStringArray([league_tag])
	var item := ItemInstance.new()
	item.definition = def
	return item
