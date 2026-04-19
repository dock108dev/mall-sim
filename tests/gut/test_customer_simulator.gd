## ISSUE-017: CustomerSimulator — batch purchase decisions and traffic formula.
extends GutTest

const SEED: int = 42
const TRAFFIC: int = 20

var _inventory: Array[ItemInstance] = []


func before_each() -> void:
	# Inject known archetypes so tests are hermetic (no file I/O dependency).
	CustomerSimulator.inject_archetypes_for_testing([
		{
			"id": "always_buys",
			"name": "Always Buys",
			"wtp_multiplier": 2.0,
			"preferred_types": ["test_store"],
			"haggle_probability": 0.0,
		},
		{
			"id": "never_buys",
			"name": "Never Buys",
			"wtp_multiplier": 0.1,
			"preferred_types": ["test_store"],
			"haggle_probability": 0.0,
		},
	])
	_inventory = _make_inventory(5, 10.0, "good", 9.0)


func after_each() -> void:
	CustomerSimulator.reset_archetype_cache()


func test_seeded_simulate_day_returns_deterministic_accepted_count() -> void:
	seed(SEED)
	var r1: Array[Dictionary] = CustomerSimulator.simulate_day(
		&"test_store", TRAFFIC, _inventory
	)
	var count1: int = _accepted_count(r1)

	_inventory = _make_inventory(5, 10.0, "good", 9.0)
	seed(SEED)
	var r2: Array[Dictionary] = CustomerSimulator.simulate_day(
		&"test_store", TRAFFIC, _inventory
	)
	var count2: int = _accepted_count(r2)

	assert_eq(count1, count2, "Same seed must produce the same accepted count")
	assert_gt(count1, 0, "At least one sale should occur when wtp > ask for some archetypes")


func test_seeded_simulate_day_does_not_exceed_inventory_size() -> void:
	# With 5 items and always_buys archetype dominating, at most 5 can sell.
	CustomerSimulator.inject_archetypes_for_testing([{
		"id": "always_buys", "name": "Always Buys",
		"wtp_multiplier": 10.0, "preferred_types": ["test_store"], "haggle_probability": 0.0,
	}])
	seed(SEED)
	var results: Array[Dictionary] = CustomerSimulator.simulate_day(
		&"test_store", TRAFFIC, _inventory
	)
	assert_lte(
		_accepted_count(results), 5,
		"Cannot sell more items than the inventory snapshot contains"
	)


func test_no_sales_when_all_prices_above_wtp() -> void:
	CustomerSimulator.inject_archetypes_for_testing([{
		"id": "tight_buyer", "name": "Tight Buyer",
		"wtp_multiplier": 0.5, "preferred_types": ["test_store"], "haggle_probability": 0.0,
	}])
	# base_price=10, condition=good → market=10; wtp=5; ask=9 → rejected
	seed(SEED)
	var results: Array[Dictionary] = CustomerSimulator.simulate_day(
		&"test_store", TRAFFIC, _inventory
	)
	assert_eq(_accepted_count(results), 0, "No sales when ask > wtp for all archetypes")


func test_haggle_allows_sale_when_counter_price_meets_wtp() -> void:
	# ask=9, wtp=8.5 (0.85×10), counter=9×0.9=8.1 ≤ 8.5 → haggler accepts.
	CustomerSimulator.inject_archetypes_for_testing([{
		"id": "haggler", "name": "Haggler",
		"wtp_multiplier": 0.85, "preferred_types": ["test_store"], "haggle_probability": 1.0,
	}])
	seed(SEED)
	var results: Array[Dictionary] = CustomerSimulator.simulate_day(
		&"test_store", TRAFFIC, _inventory
	)
	assert_gt(
		_accepted_count(results), 0,
		"Haggler with haggle_probability=1.0 should produce sales when counter ≤ wtp"
	)


func test_backroom_items_are_excluded_from_simulation() -> void:
	CustomerSimulator.inject_archetypes_for_testing([{
		"id": "always_buys", "name": "Always Buys",
		"wtp_multiplier": 10.0, "preferred_types": ["test_store"], "haggle_probability": 0.0,
	}])
	var backroom_inventory: Array[ItemInstance] = _make_inventory(5, 10.0, "good", 5.0)
	for item: ItemInstance in backroom_inventory:
		item.current_location = "backroom"
	seed(SEED)
	var results: Array[Dictionary] = CustomerSimulator.simulate_day(
		&"test_store", TRAFFIC, backroom_inventory
	)
	assert_eq(
		_accepted_count(results), 0,
		"Backroom items must not be purchasable"
	)


func test_traffic_formula_base_times_rep_times_event() -> void:
	assert_eq(
		CustomerSimulator.calculate_traffic(10, 1.5, 2.0),
		30,
		"10 × 1.5 × 2.0 = 30"
	)
	assert_eq(
		CustomerSimulator.calculate_traffic(10, 1.0, 1.0),
		10,
		"Identity multipliers return base traffic"
	)
	assert_eq(
		CustomerSimulator.calculate_traffic(5, 2.0, 0.5),
		5,
		"5 × 2.0 × 0.5 = 5"
	)
	assert_eq(
		CustomerSimulator.calculate_traffic(20, 0.5, 1.0),
		10,
		"20 × 0.5 × 1.0 = 10"
	)


func test_simulate_day_returns_empty_with_zero_traffic() -> void:
	var results: Array[Dictionary] = CustomerSimulator.simulate_day(
		&"test_store", 0, _inventory
	)
	assert_eq(results.size(), 0, "Zero traffic returns empty results")


func test_simulate_day_returns_empty_with_empty_inventory() -> void:
	seed(SEED)
	var results: Array[Dictionary] = CustomerSimulator.simulate_day(
		&"test_store", TRAFFIC, []
	)
	assert_eq(results.size(), 0, "Empty inventory returns empty results")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_inventory(
	count: int,
	base_price: float,
	condition: String,
	player_price: float,
) -> Array[ItemInstance]:
	var items: Array[ItemInstance] = []
	for i: int in range(count):
		var def := ItemDefinition.new()
		def.id = "sim_item_%d" % i
		def.item_name = "Sim Item %d" % i
		def.category = &"test_cat"
		def.base_price = base_price
		def.rarity = "common"
		def.condition_range = PackedStringArray([condition])
		var inst: ItemInstance = ItemInstance.create_from_definition(def, condition)
		inst.player_set_price = player_price
		inst.current_location = "shelf"
		items.append(inst)
	return items


func _accepted_count(results: Array[Dictionary]) -> int:
	var n: int = 0
	for r: Dictionary in results:
		if r.get("accepted", false):
			n += 1
	return n
