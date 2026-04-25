## Tests for PocketCreaturesStoreController lifecycle and stub methods.
extends GutTest

var _controller: PocketCreaturesStoreController = null


func before_each() -> void:
	_controller = PocketCreaturesStoreController.new()
	add_child_autofree(_controller)


func after_each() -> void:
	_controller = null


func test_store_id_constant() -> void:
	assert_eq(
		PocketCreaturesStoreController.STORE_ID,
		&"pocket_creatures",
		"STORE_ID should be pocket_creatures"
	)


func test_store_type_constant() -> void:
	assert_eq(
		PocketCreaturesStoreController.STORE_TYPE,
		&"pocket_creatures",
		"STORE_TYPE should be pocket_creatures"
	)


func test_initialize_sets_pack_count_to_zero() -> void:
	_controller.initialize()
	assert_eq(
		_controller.get_pack_count(), 0,
		"Pack count should be 0 after initialize"
	)


func test_initialize_is_idempotent() -> void:
	_controller.initialize()
	_controller._pack_inventory_count = 5
	_controller.initialize()
	assert_eq(
		_controller.get_pack_count(), 5,
		"Second initialize should not reset state"
	)


func test_get_pack_count_returns_inventory_count() -> void:
	_controller._pack_inventory_count = 7
	assert_eq(
		_controller.get_pack_count(), 7,
		"get_pack_count should return _pack_inventory_count"
	)


func test_open_pack_returns_empty_without_system() -> void:
	var result: Array[StringName] = (
		_controller.open_pack(&"test_pack")
	)
	assert_eq(
		result.size(), 0,
		"open_pack should return empty array without pack system"
	)


func test_on_tournament_started_callable_without_error() -> void:
	_controller._on_tournament_started(&"tournament_spring")
	pass_test("_on_tournament_started should not error")


func test_save_data_includes_pack_count() -> void:
	_controller._pack_inventory_count = 3
	var data: Dictionary = _controller.get_save_data()
	assert_eq(
		data.get("pack_inventory_count"), 3,
		"Save data should include pack_inventory_count"
	)


func test_load_save_data_restores_pack_count() -> void:
	_controller.load_save_data({"pack_inventory_count": 12})
	assert_eq(
		_controller.get_pack_count(), 12,
		"load_save_data should restore pack count"
	)


func test_load_save_data_handles_missing_key() -> void:
	_controller.load_save_data({})
	assert_eq(
		_controller.get_pack_count(), 0,
		"Missing pack_inventory_count should default to 0"
	)


func test_extends_store_controller() -> void:
	assert_true(
		_controller is StoreController,
		"PocketCreaturesStoreController should extend StoreController"
	)


func test_open_pack_with_cards_returns_empty_without_system() -> void:
	var result: Array[ItemInstance] = (
		_controller.open_pack_with_cards(&"test_pack")
	)
	assert_eq(
		result.size(), 0,
		"open_pack_with_cards should return empty without pack system"
	)


func test_is_openable_pack_returns_false_without_system() -> void:
	var item := ItemInstance.new()
	assert_false(
		_controller.is_openable_pack(item),
		"is_openable_pack should return false without pack system"
	)


func test_can_afford_pack_returns_false_without_system() -> void:
	var item := ItemInstance.new()
	assert_false(
		_controller.can_afford_pack(item),
		"can_afford_pack should return false without pack system"
	)
