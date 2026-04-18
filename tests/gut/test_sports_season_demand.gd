## Tests for sports season demand modifiers via SeasonalEventSystem.
extends GutTest


var _system: MarketValueSystem
var _inventory: InventorySystem
var _trend: TrendSystem
var _market_event: MarketEventSystem
var _seasonal_event: SeasonalEventSystem


func _create_season(
	sport: String,
	start: int,
	end: int,
	in_mult: float,
	off_mult: float,
) -> SportsSeasonDefinition:
	var s := SportsSeasonDefinition.new()
	s.id = "%s_season" % sport
	s.sport_tag = sport
	s.start_day = start
	s.end_day = end
	s.in_season_multiplier = in_mult
	s.off_season_multiplier = off_mult
	return s


func _create_sports_item(
	tags: PackedStringArray,
	base_price: float = 10.0,
) -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_sports_item"
	def.item_name = "Test Sports Item"
	def.base_price = base_price
	def.rarity = "common"
	def.store_type = "sports"
	def.tags = tags
	return ItemInstance.create_from_definition(def, "mint")


func _create_non_sports_item() -> ItemInstance:
	var def := ItemDefinition.new()
	def.id = "test_other_item"
	def.item_name = "Test Other Item"
	def.base_price = 10.0
	def.rarity = "common"
	def.store_type = "retro_games"
	def.tags = PackedStringArray(["baseball"])
	return ItemInstance.create_from_definition(def, "mint")


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(null)

	_trend = TrendSystem.new()
	add_child_autofree(_trend)

	_market_event = MarketEventSystem.new()
	add_child_autofree(_market_event)

	_seasonal_event = SeasonalEventSystem.new()
	add_child_autofree(_seasonal_event)
	_seasonal_event._sports_seasons = [
		_create_season("baseball", 1, 90, 1.4, 0.7),
		_create_season("basketball", 60, 150, 1.35, 0.75),
		_create_season("football", 120, 200, 1.5, 0.65),
	]

	_system = MarketValueSystem.new()
	add_child_autofree(_system)
	_system.initialize(
		_inventory, _market_event, _seasonal_event
	)


func test_in_season_multiplier_applied() -> void:
	_seasonal_event._current_day = 50
	_seasonal_event._recalculate_sport_seasons()
	var item: ItemInstance = _create_sports_item(
		PackedStringArray(["baseball", "CBF"])
	)
	var mult: float = _seasonal_event.get_sport_season_multiplier(
		item
	)
	assert_almost_eq(mult, 1.4, 0.001)


func test_off_season_multiplier_applied() -> void:
	_seasonal_event._current_day = 100
	_seasonal_event._recalculate_sport_seasons()
	var item: ItemInstance = _create_sports_item(
		PackedStringArray(["baseball", "CBF"])
	)
	var mult: float = _seasonal_event.get_sport_season_multiplier(
		item
	)
	assert_almost_eq(mult, 0.7, 0.001)


func test_non_sports_item_returns_one() -> void:
	_seasonal_event._current_day = 50
	_seasonal_event._recalculate_sport_seasons()
	var item: ItemInstance = _create_non_sports_item()
	var mult: float = _seasonal_event.get_sport_season_multiplier(
		item
	)
	assert_almost_eq(mult, 1.0, 0.001)


func test_no_matching_tag_returns_one() -> void:
	_seasonal_event._current_day = 50
	_seasonal_event._recalculate_sport_seasons()
	var item: ItemInstance = _create_sports_item(
		PackedStringArray(["hockey", "XHL"])
	)
	var mult: float = _seasonal_event.get_sport_season_multiplier(
		item
	)
	assert_almost_eq(mult, 1.0, 0.001)


func test_null_item_returns_one() -> void:
	var mult: float = _seasonal_event.get_sport_season_multiplier(
		null
	)
	assert_almost_eq(mult, 1.0, 0.001)


func test_day_started_recalculates_seasons() -> void:
	EventBus.day_started.emit(50)
	var mults: Dictionary = (
		_seasonal_event.get_active_sport_multipliers()
	)
	assert_true(mults.has("baseball"))
	assert_almost_eq(float(mults["baseball"]), 1.4, 0.001)
	assert_true(mults.has("basketball"))
	assert_almost_eq(float(mults["basketball"]), 0.75, 0.001)


func test_market_value_includes_sport_season() -> void:
	_seasonal_event._current_day = 50
	_seasonal_event._recalculate_sport_seasons()
	var item: ItemInstance = _create_sports_item(
		PackedStringArray(["baseball", "CBF"]), 10.0
	)
	var value: float = _system.calculate_item_value(item)
	var expected: float = (
		10.0
		* DifficultySystemSingleton.get_modifier(
			&"rarity_scale_multiplier"
		)
		* 1.4
	)
	assert_almost_eq(value, expected, 0.001)


func test_off_season_reduces_market_value() -> void:
	_seasonal_event._current_day = 300
	_seasonal_event._recalculate_sport_seasons()
	var item: ItemInstance = _create_sports_item(
		PackedStringArray(["baseball", "CBF"]), 10.0
	)
	var value: float = _system.calculate_item_value(item)
	var expected: float = (
		10.0
		* DifficultySystemSingleton.get_modifier(
			&"rarity_scale_multiplier"
		)
		* 0.7
	)
	assert_almost_eq(value, expected, 0.001)


func test_cache_invalidated_on_day_started() -> void:
	_seasonal_event._current_day = 50
	_seasonal_event._recalculate_sport_seasons()
	var item: ItemInstance = _create_sports_item(
		PackedStringArray(["baseball", "CBF"]), 10.0
	)
	_inventory.register_item(item)
	var id: StringName = StringName(item.instance_id)
	_system.get_market_value(id)
	assert_true(_system._cache.has(id))
	EventBus.day_started.emit(100)
	assert_true(_system._cache.is_empty())


func test_season_boundary_start_day() -> void:
	_seasonal_event._current_day = 1
	_seasonal_event._recalculate_sport_seasons()
	var item: ItemInstance = _create_sports_item(
		PackedStringArray(["baseball", "CBF"])
	)
	var mult: float = _seasonal_event.get_sport_season_multiplier(
		item
	)
	assert_almost_eq(mult, 1.4, 0.001)


func test_season_boundary_end_day() -> void:
	_seasonal_event._current_day = 90
	_seasonal_event._recalculate_sport_seasons()
	var item: ItemInstance = _create_sports_item(
		PackedStringArray(["baseball", "CBF"])
	)
	var mult: float = _seasonal_event.get_sport_season_multiplier(
		item
	)
	assert_almost_eq(mult, 1.4, 0.001)


func test_season_boundary_day_after_end() -> void:
	_seasonal_event._current_day = 91
	_seasonal_event._recalculate_sport_seasons()
	var item: ItemInstance = _create_sports_item(
		PackedStringArray(["baseball", "CBF"])
	)
	var mult: float = _seasonal_event.get_sport_season_multiplier(
		item
	)
	assert_almost_eq(mult, 0.7, 0.001)


func test_sports_season_definition_cycle() -> void:
	var season: SportsSeasonDefinition = _create_season(
		"baseball", 1, 90, 1.4, 0.7
	)
	assert_true(season.is_in_season(1))
	assert_true(season.is_in_season(90))
	assert_false(season.is_in_season(91))
	assert_true(season.is_in_season(366))
	assert_false(season.is_in_season(456))


func test_overlapping_seasons() -> void:
	_seasonal_event._current_day = 70
	_seasonal_event._recalculate_sport_seasons()
	var mults: Dictionary = (
		_seasonal_event.get_active_sport_multipliers()
	)
	assert_almost_eq(float(mults["baseball"]), 1.4, 0.001)
	assert_almost_eq(float(mults["basketball"]), 1.35, 0.001)
	assert_almost_eq(float(mults["football"]), 0.65, 0.001)
