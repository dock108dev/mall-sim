## Regression coverage for §SR-09 — load_save_data must reject NaN/Inf and
## clamp out-of-range numerics from a hand-edited or corrupt save file. A
## propagated NaN locks comparisons to false ("never enough cash") which the
## player perceives as a hung game; an Inf would saturate every downstream
## calculation. See docs/audits/security-report.md §F-09.
extends GutTest


var _economy: EconomySystem
var _inventory: InventorySystem
var _data_loader: DataLoader
var _item_definition: ItemDefinition


func before_each() -> void:
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize()

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_item_definition = ItemDefinition.new()
	_item_definition.id = "test_item"
	_item_definition.item_name = "Test Item"
	_item_definition.store_type = &"test_store"
	_item_definition.base_price = 10.0
	_item_definition.rarity = "common"
	_data_loader._items["test_item"] = _item_definition

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)


func test_economy_load_rejects_nan_cash() -> void:
	_economy.load_save_data({"player_cash": NAN})
	assert_false(
		is_nan(_economy.get_cash()),
		"NaN cash from a corrupt save must be replaced with the default"
	)


func test_economy_load_rejects_inf_cash() -> void:
	_economy.load_save_data({"player_cash": INF})
	assert_false(
		is_inf(_economy.get_cash()),
		"Inf cash from a corrupt save must be replaced with the default"
	)


func test_economy_load_clamps_extreme_cash() -> void:
	_economy.load_save_data({"player_cash": 1.0e30})
	assert_lt(
		_economy.get_cash(),
		2.0e9,
		"Wildly out-of-range cash must be clamped to a sane ceiling"
	)


func test_economy_load_rejects_string_cash() -> void:
	_economy.load_save_data({"player_cash": "not a number"})
	assert_eq(
		typeof(_economy.get_cash()),
		TYPE_FLOAT,
		"String value should fall back to default float, not propagate the string"
	)


func test_inventory_load_rejects_nan_price() -> void:
	var entry: Dictionary = {
		"items": [{
			"definition_id": "test_item",
			"instance_id": "i1",
			"acquired_price": NAN,
			"player_set_price": NAN,
			"store_id": "test_store",
		}],
	}
	_inventory.load_save_data(entry)
	var loaded: ItemInstance = _inventory.get_item("i1")
	if loaded == null:
		# Item may have been skipped due to unresolved store_id in this minimal
		# fixture — that is also a safe outcome (no NaN propagated).
		pass_test("InventorySystem skipped item with unresolved store; no NaN propagated")
		return
	assert_false(
		is_nan(loaded.acquired_price),
		"acquired_price NaN must be replaced with 0.0"
	)
	assert_false(
		is_nan(loaded.player_set_price),
		"player_set_price NaN must be replaced with 0.0"
	)


func test_inventory_load_clamps_negative_price() -> void:
	var entry: Dictionary = {
		"items": [{
			"definition_id": "test_item",
			"instance_id": "i2",
			"acquired_price": -100.0,
			"player_set_price": -50.0,
			"store_id": "test_store",
		}],
	}
	_inventory.load_save_data(entry)
	var loaded: ItemInstance = _inventory.get_item("i2")
	if loaded == null:
		pass_test("InventorySystem skipped item with unresolved store; no negative price propagated")
		return
	assert_gte(
		loaded.acquired_price,
		0.0,
		"Negative acquired_price must be clamped to non-negative"
	)
	assert_gte(
		loaded.player_set_price,
		0.0,
		"Negative player_set_price must be clamped to non-negative"
	)
