## Tests electronics product depreciation curve via MarketValueSystem.get_time_modifier.
extends GutTest


var _system: MarketValueSystem
var _inventory: InventorySystem


func _create_electronics_def(overrides: Dictionary = {}) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = overrides.get("id", "elec_test")
	def.item_name = overrides.get("item_name", "Test Electronics")
	def.base_price = overrides.get("base_price", 100.0)
	def.rarity = overrides.get("rarity", "common")
	def.store_type = overrides.get("store_type", "electronics")
	def.depreciates = overrides.get("depreciates", true)
	def.launch_day = overrides.get("launch_day", 1)
	def.depreciation_rate = overrides.get("depreciation_rate", 0.02)
	def.min_value_ratio = overrides.get("min_value_ratio", 0.15)
	def.launch_demand_multiplier = overrides.get(
		"launch_demand_multiplier", 1.3
	)
	def.launch_spike_days = overrides.get("launch_spike_days", 5)
	def.tags = overrides.get("tags", PackedStringArray())
	return def


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(null)

	_system = MarketValueSystem.new()
	add_child_autofree(_system)
	_system.initialize(_inventory, null, null)


func test_no_depreciation_on_launch_day() -> void:
	var def: ItemDefinition = _create_electronics_def({"launch_day": 1})
	var mult: float = _system.get_time_modifier(def, 1)
	var expected: float = 1.0 * 1.3
	assert_almost_eq(mult, expected, 0.001)


func test_launch_spike_within_window() -> void:
	var def: ItemDefinition = _create_electronics_def({
		"launch_day": 1,
		"launch_spike_days": 5,
		"launch_demand_multiplier": 1.3,
		"depreciation_rate": 0.02,
	})
	var mult: float = _system.get_time_modifier(def, 3)
	var base_depreciation: float = 1.0 - 2.0 * 0.02
	var expected: float = base_depreciation * 1.3
	assert_almost_eq(mult, expected, 0.001)


func test_launch_spike_ends_after_window() -> void:
	var def: ItemDefinition = _create_electronics_def({
		"launch_day": 1,
		"launch_spike_days": 5,
		"launch_demand_multiplier": 1.3,
		"depreciation_rate": 0.02,
	})
	var mult_inside: float = _system.get_time_modifier(def, 6)
	var mult_outside: float = _system.get_time_modifier(def, 7)
	assert_true(
		mult_inside > mult_outside,
		"Multiplier should drop after launch spike ends"
	)


func test_depreciation_at_day_10() -> void:
	var def: ItemDefinition = _create_electronics_def({
		"launch_day": 1,
		"depreciation_rate": 0.02,
		"launch_spike_days": 5,
	})
	var mult: float = _system.get_time_modifier(def, 11)
	var expected: float = 1.0 - 10.0 * 0.02
	assert_almost_eq(mult, expected, 0.001)


func test_depreciation_at_day_30() -> void:
	var def: ItemDefinition = _create_electronics_def({
		"launch_day": 1,
		"depreciation_rate": 0.02,
		"min_value_ratio": 0.15,
		"launch_spike_days": 5,
	})
	var mult: float = _system.get_time_modifier(def, 31)
	var raw: float = 1.0 - 30.0 * 0.02
	var expected: float = maxf(0.15, raw)
	assert_almost_eq(mult, expected, 0.001)


func test_floor_at_min_value_ratio() -> void:
	var def: ItemDefinition = _create_electronics_def({
		"launch_day": 1,
		"depreciation_rate": 0.02,
		"min_value_ratio": 0.15,
		"launch_spike_days": 0,
	})
	var mult: float = _system.get_time_modifier(def, 100)
	assert_almost_eq(
		mult, 0.15, 0.001,
		"Multiplier must not go below min_value_ratio"
	)


func test_non_depreciating_item_returns_one() -> void:
	var def: ItemDefinition = _create_electronics_def({
		"depreciates": false,
	})
	var mult: float = _system.get_time_modifier(def, 50)
	assert_almost_eq(mult, 1.0, 0.001)


func test_before_launch_day_returns_one() -> void:
	var def: ItemDefinition = _create_electronics_def({
		"launch_day": 10,
	})
	var mult: float = _system.get_time_modifier(def, 5)
	assert_almost_eq(mult, 1.0, 0.001)


func test_zero_depreciation_rate_returns_one() -> void:
	var def: ItemDefinition = _create_electronics_def({
		"depreciation_rate": 0.0,
	})
	var mult: float = _system.get_time_modifier(def, 50)
	assert_almost_eq(mult, 1.0, 0.001)


func test_null_definition_returns_one() -> void:
	var mult: float = _system.get_time_modifier(null, 10)
	assert_almost_eq(mult, 1.0, 0.001)


func test_30_day_curve_follows_formula() -> void:
	var def: ItemDefinition = _create_electronics_def({
		"launch_day": 1,
		"depreciation_rate": 0.02,
		"min_value_ratio": 0.15,
		"launch_demand_multiplier": 1.3,
		"launch_spike_days": 5,
	})

	for day: int in range(1, 32):
		var mult: float = _system.get_time_modifier(def, day)
		var days_since: int = day - 1
		var base_dep: float = maxf(0.15, 1.0 - float(days_since) * 0.02)
		var expected: float = base_dep
		if days_since <= 5:
			expected *= 1.3
		assert_almost_eq(
			mult, expected, 0.001,
			"Day %d: expected %f, got %f" % [day, expected, mult]
		)


func test_time_modifier_integrated_into_value() -> void:
	var def: ItemDefinition = _create_electronics_def({
		"base_price": 100.0,
		"rarity": "common",
		"launch_day": 1,
		"depreciation_rate": 0.02,
		"min_value_ratio": 0.15,
		"launch_spike_days": 0,
	})
	var item: ItemInstance = ItemInstance.create_from_definition(
		def, "mint"
	)
	_system._current_day = 11
	var value: float = _system.calculate_item_value(item)
	var expected: float = 100.0 * 1.0 * 1.0 * (1.0 - 10.0 * 0.02)
	assert_almost_eq(value, expected, 0.01)


func test_different_min_value_ratios() -> void:
	var def_low: ItemDefinition = _create_electronics_def({
		"min_value_ratio": 0.1,
		"depreciation_rate": 0.05,
		"launch_spike_days": 0,
	})
	var def_high: ItemDefinition = _create_electronics_def({
		"min_value_ratio": 0.3,
		"depreciation_rate": 0.05,
		"launch_spike_days": 0,
	})
	var mult_low: float = _system.get_time_modifier(def_low, 100)
	var mult_high: float = _system.get_time_modifier(def_high, 100)
	assert_almost_eq(mult_low, 0.1, 0.001)
	assert_almost_eq(mult_high, 0.3, 0.001)
