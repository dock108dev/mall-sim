## Tests PackOpeningSystem: rarity weighting, pack reveal, and inventory population.
extends GutTest


var _system: PackOpeningSystem
var _inventory: InventorySystem
var _economy: EconomySystem
var _pack_opened_ids: Array[String] = []
var _pack_opened_cards: Array = []


func _make_card_definition(
	subcategory: String,
	set_tag: String = "base_set",
	id_suffix: String = "",
) -> ItemDefinition:
	var def := ItemDefinition.new()
	var suffix: String = id_suffix if id_suffix != "" else subcategory
	def.id = "pc_card_%s_%s" % [set_tag, suffix]
	def.item_name = "Test %s Card" % subcategory
	def.category = "singles"
	def.subcategory = subcategory
	def.store_type = "pocket_creatures"
	def.base_price = 1.0
	def.tags = PackedStringArray([set_tag])
	return def


func _make_pack_definition(
	set_tag: String = "base_set",
) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = "pc_booster_%s" % set_tag
	def.item_name = "Test Booster Pack"
	def.category = "booster_packs"
	def.subcategory = "sealed"
	def.store_type = "pocket_creatures"
	def.base_price = 3.99
	def.tags = PackedStringArray(["pack", "booster", "sealed", set_tag])
	return def


func _make_pack_instance(
	set_tag: String = "base_set",
) -> ItemInstance:
	var def: ItemDefinition = _make_pack_definition(set_tag)
	var inst: ItemInstance = ItemInstance.create_from_definition(def)
	_inventory._items[inst.instance_id] = inst
	return inst


func _seed_card_pool(dl: DataLoader) -> void:
	var defs: Array[ItemDefinition] = []
	for i: int in range(10):
		defs.append(
			_make_card_definition("common", "base_set", "common_%d" % i)
		)
	for i: int in range(5):
		defs.append(
			_make_card_definition("uncommon", "base_set", "uncommon_%d" % i)
		)
	for i: int in range(3):
		defs.append(
			_make_card_definition("rare", "base_set", "rare_%d" % i)
		)
	for i: int in range(2):
		defs.append(
			_make_card_definition("rare_holo", "base_set", "holo_%d" % i)
		)
	defs.append(
		_make_card_definition("secret_rare", "base_set", "secret_0")
	)
	for i: int in range(3):
		defs.append(
			_make_card_definition("energy", "base_set", "energy_%d" % i)
		)
	for def: ItemDefinition in defs:
		dl._items[def.id] = def


func _on_pack_opened(pack_id: String, cards: Array[String]) -> void:
	_pack_opened_ids.append(pack_id)
	_pack_opened_cards.append(cards)


func before_each() -> void:
	_pack_opened_ids = []
	_pack_opened_cards = []

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(10000.0)

	var dl := DataLoader.new()
	add_child_autofree(dl)
	_seed_card_pool(dl)

	_system = PackOpeningSystem.new()
	_system._set_tags = ["base_set"]
	_system._data_loader = dl
	_system._inventory_system = _inventory
	_system._economy_system = _economy
	_system._commons_per_pack = 6
	_system._uncommons_per_pack = 3
	_system._energy_per_pack = 1
	_system._rare_slot_rare_chance = 0.64
	_system._rare_slot_holo_chance = 0.33
	_system._pack_conditions = ["good", "near_mint", "mint"]

	EventBus.pack_opened.connect(_on_pack_opened)


func after_each() -> void:
	if EventBus.pack_opened.is_connected(_on_pack_opened):
		EventBus.pack_opened.disconnect(_on_pack_opened)


# --- test_open_pack_returns_correct_card_count ---


func test_open_pack_returns_correct_card_count() -> void:
	var pack: ItemInstance = _make_pack_instance()
	var expected_count: int = (
		_system._commons_per_pack
		+ _system._uncommons_per_pack
		+ 1  # rare slot
		+ 1  # energy slot
	)
	var cards: Array[ItemInstance] = _system.open_pack(
		pack.instance_id
	)
	assert_eq(
		cards.size(), expected_count,
		"Pack should contain %d cards (6c + 3u + 1r + 1e)" % expected_count
	)


# --- test_rarity_distribution_weighted ---


func test_rarity_distribution_weighted() -> void:
	var common_count: Array = [0]
	var rare_count: Array = [0]
	var packs_to_open: int = 100

	for i: int in range(packs_to_open):
		var pack: ItemInstance = _make_pack_instance()
		var cards: Array[ItemInstance] = _system.open_pack(
			pack.instance_id
		)
		for card: ItemInstance in cards:
			if not card.definition:
				continue
			match card.definition.subcategory:
				"common":
					common_count[0] += 1
				"rare", "rare_holo", "secret_rare":
					rare_count[0] += 1

	assert_gt(
		common_count[0], 0,
		"Should have generated at least one common card"
	)
	assert_gt(
		rare_count[0], 0,
		"Should have generated at least one rare card"
	)
	var ratio: float = float(common_count[0]) / float(rare_count[0])
	assert_gt(
		ratio, 5.0,
		"Commons should appear at least 5x more than rares (ratio: %.1f)"
		% ratio
	)


# --- test_opened_cards_added_to_inventory ---


func test_opened_cards_added_to_inventory() -> void:
	var pack: ItemInstance = _make_pack_instance()
	var cards: Array[ItemInstance] = _system.open_pack(
		pack.instance_id
	)
	assert_gt(
		cards.size(), 0,
		"Pack should produce cards"
	)
	for card: ItemInstance in cards:
		var found: ItemInstance = _inventory.get_item(card.instance_id)
		assert_not_null(
			found,
			"Card '%s' should be present in inventory" % card.instance_id
		)


# --- test_unknown_pack_id_returns_empty ---


func test_unknown_pack_id_returns_empty() -> void:
	var cards: Array[ItemInstance] = _system.open_pack("invalid_pack_id")
	assert_eq(
		cards.size(), 0,
		"Unknown pack ID should return empty array"
	)


# --- test_pack_opened_signal_fires ---


func test_pack_opened_signal_fires() -> void:
	var pack: ItemInstance = _make_pack_instance()
	var pack_id: String = pack.instance_id
	var cards: Array[ItemInstance] = _system.open_pack(pack_id)
	assert_eq(
		_pack_opened_ids.size(), 1,
		"pack_opened signal should fire exactly once"
	)
	assert_eq(
		_pack_opened_ids[0], pack_id,
		"Signal should carry the correct pack_id"
	)
	var signal_card_ids: Array = _pack_opened_cards[0]
	assert_eq(
		signal_card_ids.size(), cards.size(),
		"Signal card array should match returned card count"
	)
	for card: ItemInstance in cards:
		assert_true(
			signal_card_ids.has(card.instance_id),
			"Signal should include card '%s'" % card.instance_id
		)
