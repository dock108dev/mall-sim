## Tests CardPackSystem: rarity weighted draw, opening guard, cost deduction,
## and inventory population.
extends GutTest


var _system: PackOpeningSystem
var _inventory: InventorySystem
var _economy: EconomySystem


func _make_card_definition(
	subcategory: String,
	rarity: String = "common",
	base_price: float = 1.0,
	set_tag: String = "base_set",
	id_suffix: String = "",
) -> ItemDefinition:
	var def := ItemDefinition.new()
	var suffix: String = id_suffix if id_suffix != "" else subcategory
	def.id = "pc_card_%s_%s" % [set_tag, suffix]
	def.item_name = "Test %s Card" % subcategory
	def.category = "singles"
	def.subcategory = subcategory
	def.rarity = rarity
	def.store_type = "pocket_creatures"
	def.base_price = base_price
	def.tags = PackedStringArray([set_tag])
	return def


func _make_pack_definition(set_tag: String = "base_set") -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = "pc_booster_%s" % set_tag
	def.item_name = "Test Booster Pack"
	def.category = "booster_packs"
	def.subcategory = "sealed"
	def.store_type = "pocket_creatures"
	def.base_price = 3.99
	def.tags = PackedStringArray(["pack", "booster", "sealed", set_tag])
	return def


func _make_pack_instance(set_tag: String = "base_set") -> ItemInstance:
	var def: ItemDefinition = _make_pack_definition(set_tag)
	var inst: ItemInstance = ItemInstance.create_from_definition(def)
	_inventory._items[inst.instance_id] = inst
	return inst


func _seed_full_card_pool(dl: DataLoader) -> void:
	var defs: Array[ItemDefinition] = []
	for i: int in range(10):
		defs.append(
			_make_card_definition(
				"common", "common", 0.25, "base_set", "common_%d" % i
			)
		)
	for i: int in range(5):
		defs.append(
			_make_card_definition(
				"uncommon", "uncommon", 1.0, "base_set", "uncommon_%d" % i
			)
		)
	for i: int in range(3):
		defs.append(
			_make_card_definition(
				"rare", "rare", 5.0, "base_set", "rare_%d" % i
			)
		)
	for i: int in range(2):
		defs.append(
			_make_card_definition(
				"rare_holo", "very_rare", 15.0, "base_set", "holo_%d" % i
			)
		)
	defs.append(
		_make_card_definition(
			"secret_rare", "legendary", 50.0, "base_set", "secret_0"
		)
	)
	for i: int in range(3):
		defs.append(
			_make_card_definition(
				"energy", "common", 0.10, "base_set", "energy_%d" % i
			)
		)
	for def: ItemDefinition in defs:
		dl._items[def.id] = def


func before_each() -> void:
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(10000.0)

	var dl := DataLoader.new()
	add_child_autofree(dl)
	_seed_full_card_pool(dl)

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


# --- test_open_pack_returns_correct_card_count ---


func test_open_pack_returns_correct_card_count() -> void:
	var pack: ItemInstance = _make_pack_instance()
	var expected_count: int = (
		_system._commons_per_pack
		+ _system._uncommons_per_pack
		+ 1  # rare slot
		+ 1  # energy slot
	)
	var cards: Array[ItemInstance] = _system.open_pack(pack.instance_id)
	assert_eq(
		cards.size(), expected_count,
		"Pack should contain %d cards (6c + 3u + 1r + 1e)" % expected_count
	)


# --- test_drawn_cards_have_valid_ids ---


func test_drawn_cards_have_valid_ids() -> void:
	var pack: ItemInstance = _make_pack_instance()
	var cards: Array[ItemInstance] = _system.open_pack(pack.instance_id)
	assert_gt(cards.size(), 0, "Pack should produce cards")
	for card: ItemInstance in cards:
		assert_true(
			card.instance_id != "",
			"Drawn card must have a non-empty instance_id"
		)
		assert_not_null(
			card.definition,
			"Drawn card must have a definition"
		)
		assert_true(
			card.definition.id != "",
			"Drawn card definition id must not be empty"
		)


# --- test_rarity_draw_rejects_unknown_rarity ---


func test_rarity_draw_rejects_unknown_rarity() -> void:
	# Build a pool where the rare slot is only represented by an unrecognized
	# subcategory. The system logs push_error and falls back to a common card.
	var dl := DataLoader.new()
	add_child_autofree(dl)
	for i: int in range(6):
		var def: ItemDefinition = _make_card_definition(
			"common", "common", 0.25, "base_set", "fb_common_%d" % i
		)
		dl._items[def.id] = def
	for i: int in range(3):
		var def: ItemDefinition = _make_card_definition(
			"uncommon", "uncommon", 1.0, "base_set", "fb_uncommon_%d" % i
		)
		dl._items[def.id] = def
	var bogus_def: ItemDefinition = _make_card_definition(
		"mythic_ultra", "legendary", 100.0, "base_set", "bogus_rare"
	)
	dl._items[bogus_def.id] = bogus_def
	for i: int in range(2):
		var def: ItemDefinition = _make_card_definition(
			"energy", "common", 0.10, "base_set", "fb_energy_%d" % i
		)
		dl._items[def.id] = def

	_system._data_loader = dl
	var pack: ItemInstance = _make_pack_instance()
	var expected_count: int = (
		_system._commons_per_pack + _system._uncommons_per_pack + 1 + 1
	)
	var cards: Array[ItemInstance] = _system.open_pack(pack.instance_id)
	assert_eq(
		cards.size(), expected_count,
		"Pack should still yield correct card count when rare pool is empty"
	)
	# Rare slot is filled by the common fallback when no valid rare pool exists.
	var rare_slot_index: int = _system._commons_per_pack + _system._uncommons_per_pack
	var rare_slot_card: ItemInstance = cards[rare_slot_index]
	assert_eq(
		rare_slot_card.definition.subcategory, "common",
		"Rare slot should fall back to a common card when no valid rare pool exists"
	)


# --- test_no_double_open ---


func test_no_double_open() -> void:
	var pack: ItemInstance = _make_pack_instance()
	var pack_id: String = pack.instance_id
	var first_cards: Array[ItemInstance] = _system.open_pack(pack_id)
	assert_gt(first_cards.size(), 0, "First open should succeed")
	assert_null(
		_inventory.get_item(pack_id),
		"Pack should be removed from inventory after first open"
	)
	var second_cards: Array[ItemInstance] = _system.open_pack(pack_id)
	assert_eq(
		second_cards.size(), 0,
		"Second open on same pack should return empty array"
	)


# --- test_rarity_weight_distribution_skews_toward_common ---


func test_rarity_weight_distribution_skews_toward_common() -> void:
	seed(12345)
	var common_count: Array = [0]
	var uncommon_count: Array = [0]
	var rare_count: Array = [0]
	var ultra_rare_found: Array = [false]

	for _i: int in range(200):
		var pack: ItemInstance = _make_pack_instance()
		var cards: Array[ItemInstance] = _system.open_pack(pack.instance_id)
		for card: ItemInstance in cards:
			if not card.definition:
				continue
			match card.definition.subcategory:
				"common", "energy":
					common_count[0] += 1
				"uncommon":
					uncommon_count[0] += 1
				"rare", "rare_holo":
					rare_count[0] += 1
				"secret_rare":
					ultra_rare_found[0] = true
					rare_count[0] += 1

	assert_gt(
		common_count[0], uncommon_count,
		"Commons should outnumber uncommons over 200 packs"
	)
	assert_gt(
		uncommon_count[0], rare_count,
		"Uncommons should outnumber rares over 200 packs"
	)
	assert_true(
		ultra_rare_found[0],
		"At least one secret_rare (ultra_rare) should appear in 200 packs"
	)


# --- test_pack_cost_deducted_before_reveal ---


func test_pack_cost_deducted_before_reveal() -> void:
	var pack: ItemInstance = _make_pack_instance()
	var pack_cost: float = pack.definition.base_price
	var cash_before: float = _economy.get_cash()
	var cards: Array[ItemInstance] = _system.open_pack(pack.instance_id)
	assert_gt(cards.size(), 0, "Pack should open successfully")
	assert_almost_eq(
		_economy.get_cash(), cash_before - pack_cost, 0.01,
		"Player cash should be reduced by pack cost on successful opening"
	)


func test_pack_cost_insufficient_funds_blocks_open() -> void:
	_economy._current_cash = 1.0
	var pack: ItemInstance = _make_pack_instance()
	var cash_before: float = _economy.get_cash()
	var cards: Array[ItemInstance] = _system.open_pack(pack.instance_id)
	assert_eq(
		cards.size(), 0,
		"Pack should not open when player cannot afford it"
	)
	assert_almost_eq(
		_economy.get_cash(), cash_before, 0.01,
		"Cash should be unchanged when insufficient funds blocks the opening"
	)


# --- test_cards_added_to_inventory_with_rarity_prices ---


func test_cards_added_to_inventory_with_rarity_prices() -> void:
	var pack: ItemInstance = _make_pack_instance()
	var cards: Array[ItemInstance] = _system.open_pack(pack.instance_id)
	assert_gt(cards.size(), 0, "Pack should produce cards")
	for card: ItemInstance in cards:
		assert_gt(
			card.get_current_value(), 0.0,
			"Card '%s' should have a computed value > 0" % card.instance_id
		)

	# Secret-rare value should exceed common value when base prices differ.
	var secret_def: ItemDefinition = _make_card_definition(
		"secret_rare", "legendary", 50.0, "base_set", "price_check_secret"
	)
	var common_def: ItemDefinition = _make_card_definition(
		"common", "common", 0.25, "base_set", "price_check_common"
	)
	var secret_inst: ItemInstance = ItemInstance.create_from_definition(secret_def)
	var common_inst: ItemInstance = ItemInstance.create_from_definition(common_def)
	assert_gt(
		secret_inst.get_current_value(), common_inst.get_current_value(),
		"Ultra-rare (secret_rare) card value should exceed common card value"
	)
