## Tests for calendar-based seasonal demand multipliers (ISSUE-113).
extends GutTest


var _seasonal: SeasonalEventSystem
var _market: MarketValueSystem
var _inventory: InventorySystem
var _trend: TrendSystem
var _market_event: MarketEventSystem

var _season_changed_calls: Array[Dictionary] = []
var _multiplier_update_calls: Array[Dictionary] = []


func before_each() -> void:
	_season_changed_calls.clear()
	_multiplier_update_calls.clear()

	_seasonal = SeasonalEventSystem.new()
	add_child_autofree(_seasonal)
	_seasonal._seasonal_config = _build_test_config()
	_seasonal._apply_state({})
	EventBus.day_started.connect(_seasonal._on_day_started)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(null)

	_trend = TrendSystem.new()
	add_child_autofree(_trend)

	_market_event = MarketEventSystem.new()
	add_child_autofree(_market_event)

	_market = MarketValueSystem.new()
	add_child_autofree(_market)
	_market.initialize(_inventory, _market_event, _seasonal)

	EventBus.season_changed.connect(_record_season_changed)
	EventBus.seasonal_multipliers_updated.connect(
		_record_multipliers_updated
	)


func after_each() -> void:
	if EventBus.day_started.is_connected(_seasonal._on_day_started):
		EventBus.day_started.disconnect(_seasonal._on_day_started)
	if EventBus.season_changed.is_connected(_record_season_changed):
		EventBus.season_changed.disconnect(_record_season_changed)
	if EventBus.seasonal_multipliers_updated.is_connected(
		_record_multipliers_updated
	):
		EventBus.seasonal_multipliers_updated.disconnect(
			_record_multipliers_updated
		)


func _record_season_changed(
	new_season: int, old_season: int
) -> void:
	_season_changed_calls.append({
		"new": new_season, "old": old_season,
	})


func _record_multipliers_updated(multipliers: Dictionary) -> void:
	_multiplier_update_calls.append(multipliers.duplicate())


func _build_test_config() -> Array[Dictionary]:
	return [
		{
			"index": 0, "name": "Spring",
			"store_multipliers": {
				"sports": 1.1, "retro_games": 0.95,
			},
		},
		{
			"index": 1, "name": "Summer",
			"store_multipliers": {
				"sports": 1.3, "retro_games": 0.9,
			},
		},
		{
			"index": 2, "name": "Fall",
			"store_multipliers": {
				"sports": 1.2, "retro_games": 1.1,
			},
		},
		{
			"index": 3, "name": "Winter",
			"store_multipliers": {
				"sports": 0.8, "retro_games": 1.25,
			},
		},
	]


func _create_item(
	store_type: String, base_price: float = 10.0
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_%s_item" % store_type
	def.item_name = "Test Item"
	def.base_price = base_price
	def.rarity = "common"
	def.store_type = store_type
	return ItemInstance.create_from_definition(def, "mint")


# ── compute_season static tests ─────────────────────────────────────


func test_compute_season_spring() -> void:
	assert_eq(SeasonalEventSystem.compute_season(1), 0)
	assert_eq(SeasonalEventSystem.compute_season(30), 0)


func test_compute_season_summer() -> void:
	assert_eq(SeasonalEventSystem.compute_season(31), 1)
	assert_eq(SeasonalEventSystem.compute_season(60), 1)


func test_compute_season_fall() -> void:
	assert_eq(SeasonalEventSystem.compute_season(61), 2)
	assert_eq(SeasonalEventSystem.compute_season(90), 2)


func test_compute_season_winter() -> void:
	assert_eq(SeasonalEventSystem.compute_season(91), 3)
	assert_eq(SeasonalEventSystem.compute_season(120), 3)


func test_compute_season_wraps_after_120() -> void:
	assert_eq(SeasonalEventSystem.compute_season(121), 0)
	assert_eq(SeasonalEventSystem.compute_season(150), 0)
	assert_eq(SeasonalEventSystem.compute_season(151), 1)
	assert_eq(SeasonalEventSystem.compute_season(240), 3)
	assert_eq(SeasonalEventSystem.compute_season(241), 0)


# ── season_changed signal ────────────────────────────────────────────


func test_season_changed_fires_on_transition() -> void:
	EventBus.day_started.emit(1)
	_season_changed_calls.clear()
	EventBus.day_started.emit(31)
	assert_eq(_season_changed_calls.size(), 1)
	assert_eq(_season_changed_calls[0]["new"], 1)
	assert_eq(_season_changed_calls[0]["old"], 0)


func test_season_changed_does_not_fire_within_same_season() -> void:
	EventBus.day_started.emit(1)
	_season_changed_calls.clear()
	EventBus.day_started.emit(2)
	assert_eq(_season_changed_calls.size(), 0)


func test_season_changed_fires_at_all_boundaries() -> void:
	EventBus.day_started.emit(1)
	_season_changed_calls.clear()
	for day: int in [31, 61, 91, 121]:
		EventBus.day_started.emit(day)
	assert_eq(_season_changed_calls.size(), 4)
	assert_eq(_season_changed_calls[0]["new"], 1)
	assert_eq(_season_changed_calls[1]["new"], 2)
	assert_eq(_season_changed_calls[2]["new"], 3)
	assert_eq(_season_changed_calls[3]["new"], 0)


# ── seasonal_multipliers_updated signal ──────────────────────────────


func test_multipliers_emitted_every_day() -> void:
	EventBus.day_started.emit(1)
	EventBus.day_started.emit(2)
	EventBus.day_started.emit(3)
	assert_eq(_multiplier_update_calls.size(), 3)


func test_multipliers_contain_store_ids() -> void:
	EventBus.day_started.emit(1)
	assert_true(_multiplier_update_calls.size() > 0)
	var mults: Dictionary = _multiplier_update_calls[0]
	assert_true(mults.has("sports"))
	assert_true(mults.has("retro_games"))


func test_spring_multipliers_correct() -> void:
	EventBus.day_started.emit(15)
	var mults: Dictionary = _multiplier_update_calls.back()
	assert_almost_eq(float(mults["sports"]), 1.1, 0.001)
	assert_almost_eq(float(mults["retro_games"]), 0.95, 0.001)


func test_summer_multipliers_correct() -> void:
	EventBus.day_started.emit(45)
	var mults: Dictionary = _multiplier_update_calls.back()
	assert_almost_eq(float(mults["sports"]), 1.3, 0.001)
	assert_almost_eq(float(mults["retro_games"]), 0.9, 0.001)


# ── MarketValueSystem integration ────────────────────────────────────


func test_market_value_applies_calendar_seasonal() -> void:
	EventBus.day_started.emit(45)
	var item: ItemInstance = _create_item("sports", 10.0)
	var value: float = _market.calculate_item_value(item)
	var expected: float = 10.0 * 1.3
	assert_almost_eq(value, expected, 0.001)


func test_market_value_retro_games_winter_boost() -> void:
	EventBus.day_started.emit(100)
	var item: ItemInstance = _create_item("retro_games", 10.0)
	var value: float = _market.calculate_item_value(item)
	var expected: float = 10.0 * 1.25
	assert_almost_eq(value, expected, 0.001)


func test_unknown_store_type_returns_one() -> void:
	EventBus.day_started.emit(45)
	var item: ItemInstance = _create_item("unknown_store", 10.0)
	var value: float = _market.calculate_item_value(item)
	assert_almost_eq(value, 10.0, 0.001)


# ── get_store_seasonal_multiplier ────────────────────────────────────


func test_get_store_seasonal_multiplier() -> void:
	EventBus.day_started.emit(45)
	var mult: float = _seasonal.get_store_seasonal_multiplier(
		"sports"
	)
	assert_almost_eq(mult, 1.3, 0.001)


func test_get_store_seasonal_multiplier_missing_store() -> void:
	EventBus.day_started.emit(45)
	var mult: float = _seasonal.get_store_seasonal_multiplier(
		"nonexistent"
	)
	assert_almost_eq(mult, 1.0, 0.001)


# ── Save/load symmetry ──────────────────────────────────────────────


func test_save_load_preserves_season() -> void:
	EventBus.day_started.emit(45)
	var save_data: Dictionary = _seasonal.get_save_data()
	assert_eq(save_data["current_season"], 1)

	var fresh: SeasonalEventSystem = SeasonalEventSystem.new()
	add_child_autofree(fresh)
	fresh._seasonal_config = _build_test_config()
	fresh.load_save_data(save_data)
	assert_eq(fresh.get_calendar_season_index(), 1)


# ── No direct references ────────────────────────────────────────────


func test_seasonal_system_has_no_market_value_reference() -> void:
	var props: Array[Dictionary] = _seasonal.get_property_list()
	for prop: Dictionary in props:
		var name: String = prop["name"]
		assert_false(
			name.contains("market_value"),
			"SeasonalEventSystem should not reference MarketValueSystem"
		)


func test_seasonal_system_has_no_customer_system_reference() -> void:
	var props: Array[Dictionary] = _seasonal.get_property_list()
	for prop: Dictionary in props:
		var name: String = prop["name"]
		assert_false(
			name.contains("customer_system"),
			"SeasonalEventSystem should not reference CustomerSystem"
		)
