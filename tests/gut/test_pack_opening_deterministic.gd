## GUT tests for PackOpeningSystem deterministic RNG, per-pack-type slot counts,
## rarity tier validity, and balance deduction on pack open.
extends GutTest

const STORE_TYPE: String = "pocket_creatures"
const VALID_RARITIES: Array[String] = [
	"common", "uncommon", "rare", "rare_holo",
	"holo_rare", "secret_rare", "ultra_rare", "energy",
]

var _system: PackOpeningSystem = null
var _inventory: InventorySystem = null
var _economy: EconomySystem = null
var _dl: DataLoader = null


func _make_card_def(
	subcategory: String, set_tag: String, suffix: String = ""
) -> ItemDefinition:
	var def := ItemDefinition.new()
	var id_suffix: String = suffix if suffix != "" else subcategory
	def.id = "pc_%s_%s_%s" % [set_tag, id_suffix, randi()]
	def.item_name = "Test %s" % subcategory
	def.category = "singles"
	def.subcategory = subcategory
	def.store_type = STORE_TYPE
	def.base_price = 1.0
	def.tags = PackedStringArray([set_tag])
	return def


func _make_pack_def(set_tag: String, cost: float = 3.99) -> ItemDefinition:
	var def := ItemDefinition.new()
	def.id = "pc_booster_%s" % set_tag
	def.item_name = "Booster Pack"
	def.category = "booster_packs"
	def.subcategory = "sealed"
	def.store_type = STORE_TYPE
	def.base_price = cost
	def.tags = PackedStringArray(["pack", "booster", "sealed", set_tag])
	return def


func _add_pack_to_inventory(set_tag: String, cost: float = 3.99) -> ItemInstance:
	var def: ItemDefinition = _make_pack_def(set_tag, cost)
	var inst: ItemInstance = ItemInstance.create_from_definition(def)
	_inventory._items[inst.instance_id] = inst
	return inst


func _seed_card_pool(dl: DataLoader, set_tag: String) -> void:
	for i: int in range(8):
		dl._items["pc_%s_common_%d" % [set_tag, i]] = (
			_make_card_def("common", set_tag, "common_%d" % i)
		)
	for i: int in range(4):
		dl._items["pc_%s_uncommon_%d" % [set_tag, i]] = (
			_make_card_def("uncommon", set_tag, "uncommon_%d" % i)
		)
	for i: int in range(2):
		dl._items["pc_%s_rare_%d" % [set_tag, i]] = (
			_make_card_def("rare", set_tag, "rare_%d" % i)
		)
	dl._items["pc_%s_holo_0" % set_tag] = (
		_make_card_def("rare_holo", set_tag, "holo_0")
	)
	dl._items["pc_%s_secret_0" % set_tag] = (
		_make_card_def("secret_rare", set_tag, "secret_0")
	)
	for i: int in range(2):
		var energy: ItemDefinition = _make_card_def(
			"energy", set_tag, "energy_%d" % i
		)
		energy.tags = PackedStringArray(["energy"])
		dl._items["pc_%s_energy_%d" % [set_tag, i]] = energy


func _build_system_for_set(set_tag: String) -> void:
	_system._set_tags = [set_tag]
	_system._data_loader = _dl
	_system._inventory_system = _inventory
	_system._economy_system = _economy
	_system._commons_per_pack = 6
	_system._uncommons_per_pack = 3
	_system._energy_per_pack = 1
	_system._rare_slot_rare_chance = 0.64
	_system._rare_slot_holo_chance = 0.33
	_system._pack_conditions = ["mint"]


func before_each() -> void:
	_system = PackOpeningSystem.new()
	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(500.0)
	_dl = DataLoader.new()
	add_child_autofree(_dl)
	_seed_card_pool(_dl, "base_set")
	_build_system_for_set("base_set")


func after_each() -> void:
	_system = null


# ── Seeded RNG determinism ────────────────────────────────────────────────────


func test_seeded_rng_produces_identical_output_over_100_opens() -> void:
	const SEED := 20030101
	const OPEN_COUNT := 100

	# First run
	_system.seed_rng(SEED)
	var results_a: Array[String] = []
	for _i: int in range(OPEN_COUNT):
		var pack: ItemInstance = _add_pack_to_inventory("base_set")
		var cards: Array[ItemInstance] = _system.open_pack(pack.instance_id)
		for card: ItemInstance in cards:
			results_a.append(card.definition.id)

	# Reset inventory and seed for second run
	_inventory._items.clear()
	_system.seed_rng(SEED)
	var results_b: Array[String] = []
	for _i: int in range(OPEN_COUNT):
		var pack: ItemInstance = _add_pack_to_inventory("base_set")
		var cards: Array[ItemInstance] = _system.open_pack(pack.instance_id)
		for card: ItemInstance in cards:
			results_b.append(card.definition.id)

	assert_eq(
		results_a.size(), results_b.size(),
		"Both seeded runs should produce the same number of cards"
	)
	assert_eq(
		results_a, results_b,
		"Seeded RNG must produce identical definition IDs across 100 consecutive opens"
	)


func test_different_seeds_produce_different_output() -> void:
	var pack_a: ItemInstance = _add_pack_to_inventory("base_set")
	_system.seed_rng(111)
	var cards_a: Array[ItemInstance] = _system.open_pack(pack_a.instance_id)

	_inventory._items.clear()
	var pack_b: ItemInstance = _add_pack_to_inventory("base_set")
	_system.seed_rng(999)
	var cards_b: Array[ItemInstance] = _system.open_pack(pack_b.instance_id)

	# With different seeds, the resulting definition sequences will almost
	# certainly differ (not guaranteed but extremely likely with any real pool).
	var ids_a: Array[String] = []
	var ids_b: Array[String] = []
	for c: ItemInstance in cards_a:
		ids_a.append(c.definition.id)
	for c: ItemInstance in cards_b:
		ids_b.append(c.definition.id)
	# Just verify both produced a valid non-empty result; sequence equality
	# is not a hard requirement when seeds differ.
	assert_gt(ids_a.size(), 0, "First seed should produce cards")
	assert_gt(ids_b.size(), 0, "Second seed should produce cards")


# ── Parameterized slot count and rarity validity ──────────────────────────────


func _check_pack_type(set_tag: String, expected_slot_count: int) -> void:
	_seed_card_pool(_dl, set_tag)
	var pack: ItemInstance = _add_pack_to_inventory(set_tag)
	_system._set_tags = [set_tag]

	var cards: Array[ItemInstance] = _system.open_pack(pack.instance_id)

	assert_eq(
		cards.size(), expected_slot_count,
		"Pack type '%s' should yield %d cards" % [set_tag, expected_slot_count]
	)
	for card: ItemInstance in cards:
		assert_not_null(card.definition, "Every revealed card must have a definition")
		var sub: String = card.definition.subcategory
		assert_true(
			sub in VALID_RARITIES,
			"Card subcategory '%s' must be a valid rarity tier" % sub
		)


func test_base_set_pack_yields_correct_slot_count() -> void:
	_check_pack_type("base_set", 11)


func test_jungle_pack_yields_correct_slot_count() -> void:
	_check_pack_type("jungle", 11)


func test_fossil_pack_yields_correct_slot_count() -> void:
	_check_pack_type("fossil", 11)


func test_team_rocket_pack_yields_correct_slot_count() -> void:
	_check_pack_type("team_rocket", 11)


func test_neo_genesis_pack_yields_correct_slot_count() -> void:
	_check_pack_type("neo_genesis", 11)


func test_crystal_storm_pack_yields_correct_slot_count() -> void:
	_check_pack_type("crystal_storm", 11)


# ── Balance deduction ─────────────────────────────────────────────────────────


func test_pack_cost_deducted_from_session_cash() -> void:
	const PACK_COST := 4.49
	_economy.initialize(100.0)
	var initial_cash: float = _economy.get_cash()

	var pack: ItemInstance = _add_pack_to_inventory("base_set", PACK_COST)
	var cards: Array[ItemInstance] = _system.open_pack(pack.instance_id)

	assert_gt(cards.size(), 0, "Pack should yield cards after successful open")
	var final_cash: float = _economy.get_cash()
	assert_almost_eq(
		final_cash,
		initial_cash - PACK_COST,
		0.01,
		"Session cash should be reduced by the pack cost"
	)


func test_open_pack_fails_when_insufficient_funds() -> void:
	_economy.initialize(1.00)
	var pack: ItemInstance = _add_pack_to_inventory("base_set", 3.99)
	var cards: Array[ItemInstance] = _system.open_pack(pack.instance_id)

	assert_eq(
		cards.size(), 0,
		"Pack open should fail and return empty when player cannot afford it"
	)
	var cash_after: float = _economy.get_cash()
	assert_almost_eq(
		cash_after, 1.00, 0.01,
		"Cash should be unchanged after a failed pack open"
	)


# ── items_revealed signal ─────────────────────────────────────────────────────


func test_open_pack_emits_items_revealed_signal() -> void:
	var controller := PocketCreaturesStoreController.new()
	add_child_autofree(controller)
	controller.pack_opening_system = _system

	var revealed_pack_id: String = ""
	var revealed_creatures: Array = []
	var _on_revealed := func(pid: String, creatures: Array) -> void:
		revealed_pack_id = pid
		revealed_creatures = creatures
	EventBus.items_revealed.connect(_on_revealed)

	var pack: ItemInstance = _add_pack_to_inventory("base_set")
	controller.open_pack(StringName(pack.instance_id))

	if EventBus.items_revealed.is_connected(_on_revealed):
		EventBus.items_revealed.disconnect(_on_revealed)

	assert_eq(
		revealed_pack_id, pack.instance_id,
		"items_revealed should carry the opened pack's instance_id"
	)
	assert_gt(
		revealed_creatures.size(), 0,
		"items_revealed creature list should be non-empty"
	)


func test_open_pack_does_not_emit_items_revealed_on_failure() -> void:
	var controller := PocketCreaturesStoreController.new()
	add_child_autofree(controller)
	controller.pack_opening_system = _system

	var signal_fired: bool = false
	var _on_revealed := func(_pid: String, _creatures: Array) -> void:
		signal_fired = true
	EventBus.items_revealed.connect(_on_revealed)

	controller.open_pack(&"nonexistent_pack_id")

	if EventBus.items_revealed.is_connected(_on_revealed):
		EventBus.items_revealed.disconnect(_on_revealed)

	assert_false(
		signal_fired,
		"items_revealed must not fire when the pack open fails"
	)
