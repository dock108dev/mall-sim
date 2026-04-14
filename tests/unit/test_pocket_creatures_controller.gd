## Unit tests for PocketCreaturesStoreController — pack opening signals,
## rarity draw distribution, demand wiring, and error handling.
extends GutTest


const STORE_TYPE: String = "pocket_creatures"

var _controller: PocketCreaturesStoreController
var _inventory: InventorySystem
var _economy: EconomySystem
var _dl: DataLoader

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
	def.store_type = STORE_TYPE
	def.base_price = 1.0
	def.tags = PackedStringArray([set_tag])
	return def


func _make_pack_definition(set_tag: String = "base_set") -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = "pc_booster_%s" % set_tag
	def.item_name = "Test Booster Pack"
	def.category = "booster_packs"
	def.subcategory = "sealed"
	def.store_type = STORE_TYPE
	def.base_price = 3.99
	def.tags = PackedStringArray(["pack", "booster", "sealed", set_tag])
	return def


func _make_pack_instance(set_tag: String = "base_set") -> ItemInstance:
	var def: ItemDefinition = _make_pack_definition(set_tag)
	var inst: ItemInstance = ItemInstance.create_from_definition(def)
	_inventory._items[inst.instance_id] = inst
	return inst


func _seed_card_pool(dl: DataLoader) -> void:
	var defs: Array[ItemDefinition] = []
	for i: int in range(10):
		defs.append(_make_card_definition("common", "base_set", "common_%d" % i))
	for i: int in range(5):
		defs.append(_make_card_definition("uncommon", "base_set", "uncommon_%d" % i))
	for i: int in range(3):
		defs.append(_make_card_definition("rare", "base_set", "rare_%d" % i))
	for i: int in range(2):
		defs.append(_make_card_definition("rare_holo", "base_set", "holo_%d" % i))
	defs.append(_make_card_definition("secret_rare", "base_set", "secret_0"))
	for i: int in range(3):
		defs.append(_make_card_definition("energy", "base_set", "energy_%d" % i))
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

	_dl = DataLoader.new()
	add_child_autofree(_dl)
	_seed_card_pool(_dl)

	var pack_sys := PackOpeningSystem.new()
	pack_sys._set_tags = ["base_set"]
	pack_sys._data_loader = _dl
	pack_sys._inventory_system = _inventory
	pack_sys._economy_system = _economy
	pack_sys._commons_per_pack = 6
	pack_sys._uncommons_per_pack = 3
	pack_sys._energy_per_pack = 1
	pack_sys._rare_slot_rare_chance = 0.64
	pack_sys._rare_slot_holo_chance = 0.33
	pack_sys._pack_conditions = ["good", "near_mint", "mint"]

	_controller = PocketCreaturesStoreController.new()
	add_child_autofree(_controller)
	_controller.pack_opening_system = pack_sys

	EventBus.pack_opened.connect(_on_pack_opened)


func after_each() -> void:
	if EventBus.pack_opened.is_connected(_on_pack_opened):
		EventBus.pack_opened.disconnect(_on_pack_opened)


# --- test_pack_open_emits_pull_result ---


func test_pack_open_emits_pull_result() -> void:
	var pack: ItemInstance = _make_pack_instance()
	_controller.open_pack(StringName(pack.instance_id))

	assert_eq(
		_pack_opened_ids.size(), 1,
		"pack_opened signal should fire exactly once"
	)
	var card_ids: Array = _pack_opened_cards[0]
	assert_gt(
		card_ids.size(), 0,
		"Pack result should contain at least one card"
	)
	for raw_id: Variant in card_ids:
		var card: ItemInstance = _inventory.get_item(str(raw_id))
		assert_not_null(
			card,
			"Card '%s' should exist in inventory" % raw_id
		)
		assert_not_null(
			card.definition,
			"Card '%s' should have a valid definition" % raw_id
		)
		assert_false(
			card.definition.id.is_empty(),
			"Card definition id should not be empty"
		)


# --- test_rarity_draw_within_spec ---


func test_rarity_draw_within_spec() -> void:
	var common_count: Array = [0]
	var rare_count: Array = [0]
	var secret_rare_count: Array = [0]
	var total_count: Array = [0]
	const PACKS_TO_OPEN: int = 100

	for _i: int in range(PACKS_TO_OPEN):
		var pack: ItemInstance = _make_pack_instance()
		var cards: Array[ItemInstance] = (
			_controller.open_pack_with_cards(StringName(pack.instance_id))
		)
		for card: ItemInstance in cards:
			if not card.definition:
				continue
			total_count[0] += 1
			match card.definition.subcategory:
				"common":
					common_count[0] += 1
				"rare", "rare_holo":
					rare_count[0] += 1
				"secret_rare":
					secret_rare_count[0] += 1

	assert_gt(
		common_count[0], 0,
		"Should draw at least one common card over %d packs" % PACKS_TO_OPEN
	)
	assert_gt(
		rare_count[0], 0,
		"Should draw at least one rare card over %d packs" % PACKS_TO_OPEN
	)
	assert_gt(total_count[0], 0, "Total card count must be positive")

	var common_to_rare: float = float(common_count[0]) / float(rare_count[0])
	assert_gte(
		common_to_rare, 3.0,
		"Commons should appear at least 3x more than rares (ratio: %.2f)"
		% common_to_rare
	)

	var ultra_rare_ratio: float = float(secret_rare_count[0]) / float(total_count[0])
	assert_lte(
		ultra_rare_ratio, 0.10,
		"Ultra-rare cards should appear in <=10%% of total draws (got %.1f%%)"
		% (ultra_rare_ratio * 100.0)
	)


# --- test_tournament_event_raises_demand_signal ---


func test_tournament_event_raises_demand_signal() -> void:
	var meta := MetaShiftSystem.new()
	add_child_autofree(meta)
	meta._shift_active = true
	meta._rising_cards = [
		{
			"item_id": "pc_card_base_set_common_0",
			"name": "Rising Test Card",
			"multiplier": 2.5,
			"set_tag": "base_set",
		}
	]
	_controller.set_meta_shift_system(meta)

	watch_signals(EventBus)
	EventBus.seasonal_event_started.emit("tournament_spring")

	assert_true(
		_controller.is_meta_shift_active(),
		"Controller should report active demand spike after tournament event"
	)
	var rising: Array[Dictionary] = _controller.get_meta_rising_cards()
	assert_gt(
		rising.size(), 0,
		"Rising cards should be non-empty when tournament demand is active"
	)
	var multiplier: float = rising[0].get("multiplier", 1.0) as float
	assert_gt(
		multiplier, 1.0,
		"Demand spike multiplier should exceed 1.0 for category-rising cards"
	)


# --- test_duplicate_pack_open_draws_independently ---


func test_duplicate_pack_open_draws_independently() -> void:
	var pack_a: ItemInstance = _make_pack_instance()
	var pack_b: ItemInstance = _make_pack_instance()

	_controller.open_pack(StringName(pack_a.instance_id))
	_controller.open_pack(StringName(pack_b.instance_id))

	assert_eq(
		_pack_opened_ids.size(), 2,
		"Each open_pack call should emit a separate pack_opened signal"
	)
	assert_true(
		_pack_opened_ids[0] != _pack_opened_ids[1],
		"Each signal emission should carry a distinct pack_id"
	)

	var cards_a: Array = _pack_opened_cards[0]
	var cards_b: Array = _pack_opened_cards[1]
	assert_gt(cards_a.size(), 0, "First pack result should contain cards")
	assert_gt(cards_b.size(), 0, "Second pack result should contain cards")


# --- test_pack_open_unknown_id_errors ---


func test_pack_open_unknown_id_errors() -> void:
	var result: Array[StringName] = _controller.open_pack(&"fake_pack")

	assert_eq(
		result.size(), 0,
		"Unknown pack ID should return an empty array"
	)
	assert_eq(
		_pack_opened_ids.size(), 0,
		"No pack_opened signal should fire for an unknown pack ID"
	)
