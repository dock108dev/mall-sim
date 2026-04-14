## Tests upgrade JSON loading, StoreUpgradeSystem purchase logic,
## effect calculations, and save/load persistence.
extends GutTest


var _data_loader: DataLoader
var _economy: EconomySystem
var _reputation: ReputationSystem
var _system: StoreUpgradeSystem

const TEST_STORE: String = "sports"


func before_each() -> void:
	_data_loader = DataLoader.new()
	_data_loader.load_all_content()

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(5000.0)

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)

	_system = StoreUpgradeSystem.new()
	add_child_autofree(_system)
	_system.initialize(_data_loader, _economy, _reputation)


func test_upgrade_count() -> void:
	var all: Array[UpgradeDefinition] = (
		_data_loader.get_all_upgrades()
	)
	assert_eq(all.size(), 16, "Should load exactly 16 upgrades")


func test_universal_upgrade_count() -> void:
	var all: Array[UpgradeDefinition] = (
		_data_loader.get_all_upgrades()
	)
	var universal_count: int = 0
	for u: UpgradeDefinition in all:
		if u.is_universal():
			universal_count += 1
	assert_eq(
		universal_count, 6,
		"Should have 6 universal upgrades"
	)


func test_store_specific_upgrade_count() -> void:
	var all: Array[UpgradeDefinition] = (
		_data_loader.get_all_upgrades()
	)
	var specific_count: int = 0
	for u: UpgradeDefinition in all:
		if not u.is_universal():
			specific_count += 1
	assert_eq(
		specific_count, 10,
		"Should have 10 store-specific upgrades"
	)


func test_better_shelving_fields() -> void:
	var u: UpgradeDefinition = _data_loader.get_upgrade(
		"better_shelving"
	)
	assert_not_null(u, "better_shelving should exist")
	assert_eq(u.display_name, "Better Shelving")
	assert_eq(u.cost, 300.0)
	assert_eq(u.rep_required, 15.0)
	assert_eq(u.store_type, "")
	assert_eq(u.effect_type, "slot_bonus")
	assert_eq(u.effect_value, 2.0)


func test_store_specific_upgrade_restriction() -> void:
	var u: UpgradeDefinition = _data_loader.get_upgrade(
		"sports_trophy_wall"
	)
	assert_not_null(u, "sports_trophy_wall should exist")
	assert_eq(u.store_type, "sports")
	assert_false(u.is_universal())


func test_upgrades_for_store_filtering() -> void:
	var sports: Array[UpgradeDefinition] = (
		_data_loader.get_upgrades_for_store("sports")
	)
	var has_shelving: bool = false
	var has_trophy: bool = false
	var has_crt: bool = false
	for u: UpgradeDefinition in sports:
		if u.id == "better_shelving":
			has_shelving = true
		if u.id == "sports_trophy_wall":
			has_trophy = true
		if u.id == "retro_crt_lounge":
			has_crt = true
	assert_true(
		has_shelving,
		"sports should include universal better_shelving"
	)
	assert_true(
		has_trophy,
		"sports should include sports_trophy_wall"
	)
	assert_false(
		has_crt,
		"sports should NOT include retro_crt_lounge"
	)


func test_universal_upgrades_appear_for_all_stores() -> void:
	var stores: Array[String] = [
		"sports", "retro_games", "rentals",
		"pocket_creatures", "electronics",
	]
	for store_type: String in stores:
		var upgrades: Array[UpgradeDefinition] = (
			_data_loader.get_upgrades_for_store(store_type)
		)
		var has_shelving: bool = false
		for u: UpgradeDefinition in upgrades:
			if u.id == "better_shelving":
				has_shelving = true
				break
		assert_true(
			has_shelving,
			"better_shelving should appear for %s" % store_type
		)


func test_purchase_deducts_cash() -> void:
	_reputation.modify_reputation(TEST_STORE, 20.0)
	var before: float = _economy.get_cash()
	var result: bool = _system.purchase_upgrade(
		TEST_STORE, "better_shelving"
	)
	assert_true(result, "Purchase should succeed")
	assert_eq(
		_economy.get_cash(), before - 300.0,
		"Cash should be deducted by upgrade cost"
	)


func test_purchase_marks_installed() -> void:
	_reputation.modify_reputation(TEST_STORE, 20.0)
	_system.purchase_upgrade(TEST_STORE, "better_shelving")
	assert_true(
		_system.is_purchased(TEST_STORE, "better_shelving"),
		"Should be marked as purchased"
	)


func test_cannot_repurchase() -> void:
	_reputation.modify_reputation(TEST_STORE, 20.0)
	_system.purchase_upgrade(TEST_STORE, "better_shelving")
	var result: bool = _system.purchase_upgrade(
		TEST_STORE, "better_shelving"
	)
	assert_false(result, "Cannot purchase same upgrade twice")


func test_insufficient_cash_blocks_purchase() -> void:
	_economy.initialize(100.0)
	_reputation.modify_reputation(TEST_STORE, 20.0)
	var result: bool = _system.purchase_upgrade(
		TEST_STORE, "better_shelving"
	)
	assert_false(
		result,
		"Should not purchase with insufficient cash"
	)


func test_insufficient_rep_blocks_purchase() -> void:
	var result: bool = _system.purchase_upgrade(
		TEST_STORE, "better_shelving"
	)
	assert_false(
		result,
		"Should not purchase with insufficient reputation"
	)


func test_slot_bonus_effect() -> void:
	_reputation.modify_reputation(TEST_STORE, 20.0)
	assert_eq(
		_system.get_slot_bonus(TEST_STORE), 0,
		"No bonus before purchase"
	)
	_system.purchase_upgrade(TEST_STORE, "better_shelving")
	assert_eq(
		_system.get_slot_bonus(TEST_STORE), 2,
		"Slot bonus should be 2 after purchase"
	)


func test_price_multiplier_effect() -> void:
	_reputation.modify_reputation(TEST_STORE, 30.0)
	assert_eq(
		_system.get_price_multiplier(TEST_STORE), 1.0,
		"Default price multiplier is 1.0"
	)
	_system.purchase_upgrade(TEST_STORE, "display_cases")
	assert_almost_eq(
		_system.get_price_multiplier(TEST_STORE), 1.1,
		0.001, "Price multiplier should be 1.1"
	)


func test_traffic_multiplier_effect() -> void:
	_reputation.modify_reputation(TEST_STORE, 25.0)
	_system.purchase_upgrade(TEST_STORE, "premium_signage")
	assert_almost_eq(
		_system.get_traffic_multiplier(TEST_STORE), 1.15,
		0.001, "Traffic multiplier should be 1.15"
	)


func test_save_and_load_persistence() -> void:
	_reputation.modify_reputation(TEST_STORE, 50.0)
	_system.purchase_upgrade(TEST_STORE, "better_shelving")
	_system.purchase_upgrade(TEST_STORE, "display_cases")

	var save_data: Dictionary = _system.get_save_data()

	var new_system := StoreUpgradeSystem.new()
	add_child_autofree(new_system)
	new_system.initialize(_data_loader, _economy, _reputation)
	new_system.load_save_data(save_data)

	assert_true(
		new_system.is_purchased(TEST_STORE, "better_shelving"),
		"better_shelving should persist after load"
	)
	assert_true(
		new_system.is_purchased(TEST_STORE, "display_cases"),
		"display_cases should persist after load"
	)
	assert_false(
		new_system.is_purchased(TEST_STORE, "premium_signage"),
		"premium_signage should not be purchased after load"
	)


func test_effect_value_after_load() -> void:
	_reputation.modify_reputation(TEST_STORE, 50.0)
	_system.purchase_upgrade(TEST_STORE, "better_shelving")

	var save_data: Dictionary = _system.get_save_data()

	var new_system := StoreUpgradeSystem.new()
	add_child_autofree(new_system)
	new_system.initialize(_data_loader, _economy, _reputation)
	new_system.load_save_data(save_data)

	assert_eq(
		new_system.get_slot_bonus(TEST_STORE), 2,
		"Slot bonus should persist after load"
	)


func test_all_upgrade_ids_present() -> void:
	var expected_ids: Array[String] = [
		"better_shelving", "display_cases", "premium_signage",
		"backroom_expansion", "store_expansion", "climate_control",
		"sports_trophy_wall", "sports_season_pass_display",
		"retro_crt_lounge", "retro_parts_stockroom",
		"video_late_fee_kiosk", "video_new_releases_wall",
		"pocket_tournament_arena", "pocket_climate_vault",
		"electronics_demo_hub", "electronics_extended_warranty_desk",
	]
	for upgrade_id: String in expected_ids:
		var u: UpgradeDefinition = _data_loader.get_upgrade(
			upgrade_id
		)
		assert_not_null(
			u, "Upgrade '%s' should be loadable" % upgrade_id
		)


func test_stacked_multiplier_effects() -> void:
	_reputation.modify_reputation(TEST_STORE, 30.0)
	_system.purchase_upgrade(TEST_STORE, "display_cases")
	_system.purchase_upgrade(TEST_STORE, "sports_trophy_wall")
	var expected: float = 1.1 * 1.15
	assert_almost_eq(
		_system.get_price_multiplier(TEST_STORE), expected,
		0.001, "Stacked price multipliers should multiply"
	)
