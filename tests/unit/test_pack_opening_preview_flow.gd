## Tests the staged preview/commit flow for PackOpeningSystem.
extends GutTest


const STORE_ID: StringName = &"pocket_creatures"

var _system: PackOpeningSystem
var _inventory: InventorySystem
var _data_loader: DataLoader
var _pack_opened_ids: Array[String] = []
var _pack_opened_cards: Array = []


func _ensure_store_registry_entry() -> void:
	if ContentRegistry.exists(String(STORE_ID)):
		return
	ContentRegistry.register_entry(
		{
			"id": String(STORE_ID),
			"store_type": String(STORE_ID),
			"item_name": "Pocket Creatures",
		},
		"store",
	)


func _make_card_definition(
	subcategory: String,
	set_tag: String,
	id_suffix: String,
) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.id = "pc_card_%s_%s" % [set_tag, id_suffix]
	definition.item_name = "Test %s Card" % subcategory
	definition.category = &"singles"
	definition.subcategory = subcategory
	definition.store_type = STORE_ID
	definition.base_price = 1.0
	definition.condition_range = PackedStringArray(["good"])
	definition.tags = [StringName(set_tag)]
	match subcategory:
		"uncommon":
			definition.rarity = "uncommon"
		"rare":
			definition.rarity = "rare"
		"rare_holo", "secret_rare":
			definition.rarity = "very_rare"
		_:
			definition.rarity = "common"
	return definition


func _make_pack_definition(set_tag: String = "base_set") -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.id = "pc_booster_%s" % set_tag
	definition.item_name = "Test Booster Pack"
	definition.category = &"booster_packs"
	definition.subcategory = "sealed"
	definition.store_type = STORE_ID
	definition.base_price = 3.99
	definition.condition_range = PackedStringArray(["good"])
	definition.tags = [
		&"pack",
		&"booster",
		&"sealed",
		StringName(set_tag),
	]
	return definition


func _seed_card_pool() -> void:
	var definitions: Array[ItemDefinition] = []
	for i: int in range(6):
		definitions.append(
			_make_card_definition("common", "base_set", "common_%d" % i)
		)
	for i: int in range(3):
		definitions.append(
			_make_card_definition("uncommon", "base_set", "uncommon_%d" % i)
		)
	definitions.append(
		_make_card_definition("rare", "base_set", "rare_0")
	)
	definitions.append(
		_make_card_definition("rare_holo", "base_set", "holo_0")
	)
	definitions.append(
		_make_card_definition("secret_rare", "base_set", "secret_0")
	)
	for i: int in range(2):
		definitions.append(
			_make_card_definition("energy", "base_set", "energy_%d" % i)
		)
	for definition: ItemDefinition in definitions:
		_data_loader._items[definition.id] = definition


func _make_pack_instance() -> ItemInstance:
	var pack: ItemInstance = ItemInstance.create_from_definition(
		_make_pack_definition(),
		"good",
	)
	_inventory._items[String(pack.instance_id)] = pack
	return pack


func _build_preview_cards(cards: Array[ItemInstance]) -> Array[Dictionary]:
	var preview_cards: Array[Dictionary] = []
	for i: int in range(mini(cards.size(), PackOpeningPanel.CARDS_PER_PACK)):
		var card: ItemInstance = cards[i]
		preview_cards.append(
			{
				"id": String(card.instance_id),
				"name": card.definition.item_name,
				"rarity": _system.get_preview_rarity(card),
				"value": card.get_current_value(),
			}
		)
	return preview_cards


func _on_pack_opened(pack_id: String, cards: Array[String]) -> void:
	_pack_opened_ids.append(pack_id)
	_pack_opened_cards.append(cards.duplicate())


func before_each() -> void:
	_pack_opened_ids.clear()
	_pack_opened_cards.clear()
	_ensure_store_registry_entry()

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_seed_card_pool()

	_system = PackOpeningSystem.new()
	_system._data_loader = _data_loader
	_system._inventory_system = _inventory
	_system._economy_system = null
	_system._set_tags = ["base_set"]
	_system._commons_per_pack = 1
	_system._uncommons_per_pack = 1
	_system._energy_per_pack = 1
	_system._rare_slot_rare_chance = 1.0
	_system._rare_slot_holo_chance = 0.0
	_system._pack_conditions = ["good"]

	EventBus.pack_opened.connect(_on_pack_opened)


func after_each() -> void:
	if EventBus.pack_opened.is_connected(_on_pack_opened):
		EventBus.pack_opened.disconnect(_on_pack_opened)


func test_open_pack_preview_stages_cards_until_commit() -> void:
	var pack: ItemInstance = _make_pack_instance()
	var cards: Array[ItemInstance] = _system.open_pack_preview(
		String(pack.instance_id)
	)

	assert_gt(cards.size(), 0, "Preview flow should generate cards")
	assert_true(
		_system.has_pending_pack_results(),
		"Preview flow should keep results pending until confirmation",
	)
	assert_null(
		_inventory.get_item(String(pack.instance_id)),
		"Pack should be removed before the reveal sequence starts",
	)
	for card: ItemInstance in cards:
		assert_null(
			_inventory.get_item(String(card.instance_id)),
			"Preview cards should not enter inventory before commit",
		)

	assert_true(
		_system.commit_pack_results(_build_preview_cards(cards)),
		"Commit should accept the revealed preview payload",
	)
	assert_false(
		_system.has_pending_pack_results(),
		"Commit should clear the pending preview state",
	)
	for card: ItemInstance in cards:
		assert_not_null(
			_inventory.get_item(String(card.instance_id)),
			"Committed cards should be registered in inventory",
		)


func test_pack_opened_signal_fires_only_on_commit() -> void:
	var pack: ItemInstance = _make_pack_instance()
	var cards: Array[ItemInstance] = _system.open_pack_preview(
		String(pack.instance_id)
	)
	var expected_card_count: int = cards.size()

	assert_eq(
		_pack_opened_ids.size(),
		0,
		"Preview should not emit pack_opened before confirmation",
	)

	_system.commit_pack_results(_build_preview_cards(cards))
	assert_eq(
		_pack_opened_ids.size(),
		1,
		"Commit should emit pack_opened exactly once",
	)
	assert_eq(
		_pack_opened_ids[0],
		String(pack.instance_id),
		"pack_opened should report the staged pack id",
	)
	assert_eq(
		_pack_opened_cards[0].size(),
		expected_card_count,
		"Commit should publish all staged card ids, not only the five preview cards",
	)


func test_commit_rejects_unknown_preview_payload() -> void:
	var pack: ItemInstance = _make_pack_instance()
	_system.open_pack_preview(String(pack.instance_id))

	var success: bool = _system.commit_pack_results(
		[
			{
				"id": "bogus_card",
				"name": "Bogus",
				"rarity": "common",
				"value": 0.0,
			}
		]
	)

	assert_false(success, "Unexpected preview cards should fail validation")
	assert_true(
		_system.has_pending_pack_results(),
		"Failed validation should keep the pending preview intact",
	)
	assert_eq(
		_pack_opened_ids.size(),
		0,
		"Failed validation must not emit pack_opened",
	)
