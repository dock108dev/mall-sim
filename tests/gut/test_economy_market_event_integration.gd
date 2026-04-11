## Tests EconomySystem integration with MarketEventSystem multiplier.
extends GutTest


var _economy: EconomySystem
var _market_events: MarketEventSystem


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_market_events = MarketEventSystem.new()
	add_child_autofree(_market_events)


func _create_item(
	base_price: float = 10.0,
	tags: PackedStringArray = PackedStringArray(["rookie"]),
	category: String = "trading_cards",
) -> ItemInstance:
	var item_def := ItemDefinition.new()
	item_def.id = "test_card"
	item_def.base_price = base_price
	item_def.rarity = "common"
	item_def.tags = tags
	item_def.category = category
	return ItemInstance.create_from_definition(item_def, "good")


func test_market_value_without_market_event_system() -> void:
	_economy.initialize()
	var item: ItemInstance = _create_item()
	var value: float = _economy.calculate_market_value(item)
	assert_gt(value, 0.0, "Should calculate value without market events")


func test_market_value_with_market_event_system_no_events() -> void:
	_economy.initialize()
	_economy.set_market_event_system(_market_events)
	var item: ItemInstance = _create_item()
	var value: float = _economy.calculate_market_value(item)
	assert_gt(value, 0.0, "Value with no active events should be > 0")


func test_market_value_includes_boom_multiplier() -> void:
	_economy.initialize()
	_economy.set_market_event_system(_market_events)

	var item: ItemInstance = _create_item()
	var base_value: float = _economy.calculate_market_value(item)

	var boom_def := MarketEventDefinition.new()
	boom_def.id = "test_boom"
	boom_def.magnitude = 2.0
	boom_def.target_tags = PackedStringArray(["rookie"])
	boom_def.target_categories = PackedStringArray(["trading_cards"])
	boom_def.announcement_days = 0
	boom_def.duration_days = 10
	boom_def.ramp_up_days = 0
	boom_def.ramp_down_days = 0

	_market_events._active_events.append({
		"definition": boom_def,
		"announced_day": 0,
		"phase": MarketEventSystem.Phase.FULL_EFFECT,
	})

	var boosted_value: float = _economy.calculate_market_value(item)
	assert_almost_eq(
		boosted_value, base_value * 2.0, 0.01,
		"Boom event should double the market value"
	)


func test_market_value_includes_bust_multiplier() -> void:
	_economy.initialize()
	_economy.set_market_event_system(_market_events)

	var item: ItemInstance = _create_item()
	var base_value: float = _economy.calculate_market_value(item)

	var bust_def := MarketEventDefinition.new()
	bust_def.id = "test_bust"
	bust_def.magnitude = 0.5
	bust_def.target_tags = PackedStringArray(["rookie"])
	bust_def.target_categories = PackedStringArray(["trading_cards"])
	bust_def.announcement_days = 0
	bust_def.duration_days = 10
	bust_def.ramp_up_days = 0
	bust_def.ramp_down_days = 0

	_market_events._active_events.append({
		"definition": bust_def,
		"announced_day": 0,
		"phase": MarketEventSystem.Phase.FULL_EFFECT,
	})

	var busted_value: float = _economy.calculate_market_value(item)
	assert_almost_eq(
		busted_value, base_value * 0.5, 0.01,
		"Bust event should halve the market value"
	)


func test_null_market_event_system_returns_multiplier_one() -> void:
	_economy.initialize()
	_economy.set_market_event_system(null)
	var item: ItemInstance = _create_item()
	var value: float = _economy.calculate_market_value(item)
	assert_gt(value, 0.0, "Null market event system should not break pricing")


func test_set_market_event_system_setter() -> void:
	_economy.set_market_event_system(_market_events)
	assert_eq(
		_economy._market_event_system, _market_events,
		"Setter should store the reference"
	)
