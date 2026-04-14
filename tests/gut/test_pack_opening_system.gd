## Tests for PackOpeningSystem — category matching, RNG, economy integration.
extends GutTest

var _system: PackOpeningSystem = null


func before_each() -> void:
	_system = PackOpeningSystem.new()


func after_each() -> void:
	_system = null


func test_is_booster_pack_with_correct_category() -> void:
	var def := ItemDefinition.new()
	def.category = "booster_packs"
	def.subcategory = "sealed"
	var item := ItemInstance.new()
	item.definition = def
	assert_true(
		_system.is_booster_pack(item),
		"Should recognize booster_packs/sealed as a pack"
	)


func test_is_booster_pack_rejects_wrong_category() -> void:
	var def := ItemDefinition.new()
	def.category = "singles"
	def.subcategory = "common"
	var item := ItemInstance.new()
	item.definition = def
	assert_false(
		_system.is_booster_pack(item),
		"Should reject non-pack items"
	)


func test_is_booster_pack_rejects_sealed_product() -> void:
	var def := ItemDefinition.new()
	def.category = "sealed_product"
	def.subcategory = "booster_box"
	var item := ItemInstance.new()
	item.definition = def
	assert_false(
		_system.is_booster_pack(item),
		"Should reject sealed_product/booster_box"
	)


func test_is_booster_pack_rejects_null_item() -> void:
	assert_false(
		_system.is_booster_pack(null),
		"Should reject null item"
	)


func test_is_booster_pack_rejects_null_definition() -> void:
	var item := ItemInstance.new()
	item.definition = null
	assert_false(
		_system.is_booster_pack(item),
		"Should reject item with null definition"
	)


func test_get_pack_cost_returns_base_price() -> void:
	var def := ItemDefinition.new()
	def.base_price = 3.99
	var item := ItemInstance.new()
	item.definition = def
	assert_almost_eq(
		_system.get_pack_cost(item), 3.99, 0.001,
		"Pack cost should be the definition's base_price"
	)


func test_get_pack_cost_returns_zero_for_null() -> void:
	assert_eq(
		_system.get_pack_cost(null), 0.0,
		"Pack cost should be 0.0 for null item"
	)


func test_open_pack_returns_empty_without_init() -> void:
	var result: Array[ItemInstance] = _system.open_pack("fake_id")
	assert_eq(
		result.size(), 0,
		"open_pack should return empty without initialization"
	)


func test_can_afford_pack_returns_true_without_economy() -> void:
	var def := ItemDefinition.new()
	def.base_price = 3.99
	var item := ItemInstance.new()
	item.definition = def
	assert_true(
		_system.can_afford_pack(item),
		"Should return true when no economy system is set"
	)


func test_category_constants_match_json() -> void:
	assert_eq(
		PackOpeningSystem.PACK_CATEGORY, "booster_packs",
		"PACK_CATEGORY should match pocket_creatures.json"
	)
	assert_eq(
		PackOpeningSystem.PACK_SUBCATEGORY, "sealed",
		"PACK_SUBCATEGORY should match pocket_creatures.json"
	)


func test_card_category_matches_json() -> void:
	assert_eq(
		PackOpeningSystem.CARD_CATEGORY, "singles",
		"CARD_CATEGORY should match pocket_creatures.json singles"
	)
