## GUT test verifying pack opening pull probabilities match spec:
## Common ~60%, Uncommon ~30%, Rare ~9%, Holo/Ultra ~1%, Secret <1%
## (verified over ≥1000 packs using real DataLoader content)
extends GutTest

const PACK_DEFINITION_ID: String = "pc_booster_base_set"
const TOTAL_PACKS: int = 1000
const STORE_ID: StringName = &"pocket_creatures"

var _data_loader: DataLoader
var _inventory: InventorySystem
var _pack_system: PackOpeningSystem


func before_each() -> void:
	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_data_loader.load_all()

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)

	_pack_system = PackOpeningSystem.new()
	_pack_system.initialize(_data_loader, _inventory, null)


## Verifies that pulling from 1000 packs yields roughly 60/30/9/1/<1 distribution
## across common / uncommon / rare / holo / secret subcategories.
func test_pull_probabilities_match_spec() -> void:
	var counts: Dictionary = {
		"common": 0,
		"uncommon": 0,
		"rare": 0,
		"holo_rare": 0,
		"secret_rare": 0,
		"other": 0,
	}
	var total_cards: int = 0

	var pack_def: ItemDefinition = _data_loader.get_item(PACK_DEFINITION_ID)
	assert_not_null(pack_def, "Base set pack definition must exist")

	for i: int in range(TOTAL_PACKS):
		var inst_id: StringName = StringName("prob_pack_%d" % i)
		var pack: ItemInstance = ItemInstance.create_from_definition(pack_def)
		pack.instance_id = inst_id
		_inventory.add_item(STORE_ID, pack)

		# Override RNG seed to ensure variety across packs.
		_pack_system.seed_rng(i * 31337 + 7)

		var cards: Array[ItemInstance] = _pack_system.open_pack(String(inst_id))
		for card: ItemInstance in cards:
			total_cards += 1
			if not card.definition:
				counts["other"] += 1
				continue
			match card.definition.subcategory:
				"common", "bulk":
					counts["common"] += 1
				"uncommon":
					counts["uncommon"] += 1
				"rare":
					counts["rare"] += 1
				"rare_holo":
					counts["holo_rare"] += 1
				"secret_rare":
					counts["secret_rare"] += 1
				"energy":
					counts["common"] += 1
				_:
					counts["other"] += 1
		# Drain inventory between iterations: pocket_creatures backroom holds
		# 130 items, so 1000 packs × ~11 cards would otherwise overflow capacity
		# and trigger PackOpeningSystem register_item failures.
		for card: ItemInstance in cards:
			_inventory.remove_item(card.instance_id)

	assert_gt(total_cards, 0, "Should have drawn cards")

	var common_pct: float = 100.0 * counts["common"] / total_cards
	var uncommon_pct: float = 100.0 * counts["uncommon"] / total_cards
	var rare_pct: float = 100.0 * counts["rare"] / total_cards
	var holo_pct: float = 100.0 * counts["holo_rare"] / total_cards
	var secret_pct: float = 100.0 * counts["secret_rare"] / total_cards

	# Common should be roughly 55-70% (pack has 6-7 common-type cards of 10 real cards).
	assert_gt(common_pct, 50.0, "Common cards should be > 50%%")
	assert_lt(common_pct, 75.0, "Common cards should be < 75%%")

	# Uncommon should be roughly 20-40%.
	assert_gt(uncommon_pct, 20.0, "Uncommon cards should be > 20%%")
	assert_lt(uncommon_pct, 40.0, "Uncommon cards should be < 40%%")

	# Rare slot: plain rare should dominate (spec ~9% of all, ~90% of rare slot).
	assert_gt(rare_pct, 5.0, "Rare cards should be > 5%%")
	assert_lt(rare_pct, 15.0, "Rare cards should be < 15%%")

	# Holo/ultra should appear less than plain rare (spec ~1% of all).
	assert_lt(holo_pct, rare_pct, "Holo should be rarer than plain rare")
	assert_lt(holo_pct, 5.0, "Holo cards should be < 5%%")

	# Secret should be the rarest tier.
	assert_lt(secret_pct, holo_pct + 1.0, "Secret should be rarest tier")
	assert_lt(secret_pct, 3.0, "Secret cards should be < 3%%")
