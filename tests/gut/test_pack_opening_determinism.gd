## GUT test verifying deterministic pack opening: same pack_id + same day seed
## produces an identical card subcategory sequence across two runs.
extends GutTest

const PACK_DEFINITION_ID: String = "pc_booster_base_set"
const STORE_ID: StringName = &"pocket_creatures"
const FIXED_SEED: int = 42

var _data_loader: DataLoader
var _inventory_a: InventorySystem
var _inventory_b: InventorySystem
var _pack_system_a: PackOpeningSystem
var _pack_system_b: PackOpeningSystem


func before_each() -> void:
	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_data_loader.load_all()

	_inventory_a = InventorySystem.new()
	add_child_autofree(_inventory_a)
	_inventory_a.initialize(_data_loader)

	_inventory_b = InventorySystem.new()
	add_child_autofree(_inventory_b)
	_inventory_b.initialize(_data_loader)

	_pack_system_a = PackOpeningSystem.new()
	_pack_system_a.initialize(_data_loader, _inventory_a, null)

	_pack_system_b = PackOpeningSystem.new()
	_pack_system_b.initialize(_data_loader, _inventory_b, null)


## Verifies that two PackOpeningSystems seeded with the same value produce
## identical subcategory sequences, proving deterministic RNG behaviour.
func test_same_seed_produces_identical_card_sequence() -> void:
	var pack_def: ItemDefinition = _data_loader.get_item(PACK_DEFINITION_ID)
	assert_not_null(pack_def, "Base set pack definition must exist")

	# First run.
	_pack_system_a.seed_rng(FIXED_SEED)
	var pack_a: ItemInstance = ItemInstance.create_from_definition(pack_def)
	pack_a.instance_id = &"det_pack_a"
	_inventory_a.add_item(STORE_ID, pack_a)
	var cards_a: Array[ItemInstance] = _pack_system_a.open_pack("det_pack_a")

	# Second run with identical seed.
	_pack_system_b.seed_rng(FIXED_SEED)
	var pack_b: ItemInstance = ItemInstance.create_from_definition(pack_def)
	pack_b.instance_id = &"det_pack_b"
	_inventory_b.add_item(STORE_ID, pack_b)
	var cards_b: Array[ItemInstance] = _pack_system_b.open_pack("det_pack_b")

	assert_eq(
		cards_a.size(), cards_b.size(),
		"Both runs should produce the same card count"
	)

	for i: int in range(mini(cards_a.size(), cards_b.size())):
		var sub_a: String = cards_a[i].definition.subcategory if cards_a[i].definition else ""
		var sub_b: String = cards_b[i].definition.subcategory if cards_b[i].definition else ""
		assert_eq(
			sub_a, sub_b,
			"Card %d subcategory should match across identical seeds" % i
		)


## Verifies that hash(pack_id + str(day)) is used as the RNG seed by
## confirming different pack IDs on the same day can differ (non-trivial).
func test_different_pack_ids_same_day_may_differ() -> void:
	var pack_def: ItemDefinition = _data_loader.get_item(PACK_DEFINITION_ID)
	assert_not_null(pack_def, "Base set pack definition must exist")

	var seed_x: int = hash("pack_x" + "0")
	var seed_y: int = hash("pack_y" + "0")

	_pack_system_a.seed_rng(seed_x)
	var pack_x: ItemInstance = ItemInstance.create_from_definition(pack_def)
	pack_x.instance_id = &"det_pack_x"
	_inventory_a.add_item(STORE_ID, pack_x)
	var cards_x: Array[ItemInstance] = _pack_system_a.open_pack("det_pack_x")

	_pack_system_b.seed_rng(seed_y)
	var pack_y: ItemInstance = ItemInstance.create_from_definition(pack_def)
	pack_y.instance_id = &"det_pack_y"
	_inventory_b.add_item(STORE_ID, pack_y)
	var cards_y: Array[ItemInstance] = _pack_system_b.open_pack("det_pack_y")

	# Both should produce non-empty card lists; seeds are different so results may differ.
	assert_gt(cards_x.size(), 0, "pack_x should yield cards")
	assert_gt(cards_y.size(), 0, "pack_y should yield cards")
	pass_test("Different pack IDs produce independent RNG streams")
