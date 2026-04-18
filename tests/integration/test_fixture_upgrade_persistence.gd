## Integration test: fixture tier upgrade persists through save/load cycle.
extends GutTest

const TEST_SIGNAL_UTILS: GDScript = preload("res://game/tests/test_signal_utils.gd")

const SAVE_SLOT: int = 1
const ENTRY_EDGE_Y: int = 8
const PLACEMENT_POS: Vector2i = Vector2i(5, 5)
const SECOND_POS: Vector2i = Vector2i(3, 3)
const FIXTURE_TYPE: String = "floor_rack"
const REGISTER_ID: String = "register_upgrade_test"
const REGISTER_POS: Vector2i = Vector2i(0, 0)
const STARTING_CASH: float = 10000.0
const TEST_STORE: StringName = &"sports"

var _build_mode: BuildModeSystem
var _placement: FixturePlacementSystem
var _economy: EconomySystem
var _inventory: InventorySystem
var _time_system: TimeSystem
var _reputation: ReputationSystem
var _data_loader: DataLoader
var _save_manager: SaveManager

var _saved_game_state: GameManager.GameState
var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]
var _saved_data_loader: DataLoader

var _placed_fixture_id: String = ""


func before_each() -> void:
	_saved_game_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_data_loader = GameManager.data_loader
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	GameManager.current_store_id = TEST_STORE
	GameManager.owned_stores = [TEST_STORE]

	_data_loader = DataLoader.new()
	add_child_autofree(_data_loader)
	_data_loader.load_all_content()
	GameManager.data_loader = _data_loader

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(STARTING_CASH)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(_data_loader)

	_time_system = TimeSystem.new()
	add_child_autofree(_time_system)
	_time_system.initialize()

	_reputation = ReputationSystem.new()
	add_child_autofree(_reputation)
	_reputation._scores[String(TEST_STORE)] = 100.0

	_build_mode = BuildModeSystem.new()
	add_child_autofree(_build_mode)
	_build_mode.initialize(
		null, BuildModeGrid.StoreSize.SMALL, Vector3.ZERO
	)

	_placement = FixturePlacementSystem.new()
	add_child_autofree(_placement)
	_placement.initialize(
		_build_mode.get_grid(),
		_inventory,
		_economy,
		ENTRY_EDGE_Y,
		BuildModeGrid.StoreSize.SMALL
	)
	_placement.set_data_loader(_data_loader)
	_placement.set_reputation_system(_reputation)

	_placement.register_existing_fixture(
		REGISTER_ID, "register", REGISTER_POS, 0, true, 90.0
	)

	_build_mode.set_placement_system(_placement)

	_save_manager = SaveManager.new()
	add_child_autofree(_save_manager)
	_save_manager.initialize(_economy, _inventory, _time_system)
	_save_manager.set_fixture_placement_system(_placement)

	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)

	EventBus.fixture_placed.connect(_on_fixture_placed)
	_placed_fixture_id = ""


func after_each() -> void:
	_save_manager.delete_save(SAVE_SLOT)
	TEST_SIGNAL_UTILS.safe_disconnect(EventBus.fixture_placed, _on_fixture_placed)
	GameManager.current_state = _saved_game_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	GameManager.data_loader = _saved_data_loader


func _on_fixture_placed(
	fixture_id: String, _pos: Vector2i, _rot: int
) -> void:
	_placed_fixture_id = fixture_id


func _place_fixture(pos: Vector2i) -> String:
	_placed_fixture_id = ""
	_placement.select_fixture(FIXTURE_TYPE)
	var placed: bool = _placement.try_place(pos)
	assert_true(placed, "Fixture placement at %s should succeed" % pos)
	assert_false(
		_placed_fixture_id.is_empty(),
		"fixture_placed signal should provide a fixture_id"
	)
	return _placed_fixture_id


func _create_fresh_placement() -> FixturePlacementSystem:
	var fresh_grid: BuildModeGrid = BuildModeGrid.new()
	add_child_autofree(fresh_grid)
	fresh_grid.initialize(
		BuildModeGrid.StoreSize.SMALL, Vector3.ZERO
	)

	var fresh_placement: FixturePlacementSystem = (
		FixturePlacementSystem.new()
	)
	add_child_autofree(fresh_placement)
	fresh_placement.initialize(
		fresh_grid,
		_inventory,
		_economy,
		ENTRY_EDGE_Y,
		BuildModeGrid.StoreSize.SMALL
	)
	fresh_placement.set_data_loader(_data_loader)
	fresh_placement.set_reputation_system(_reputation)
	return fresh_placement


## Scenario: fixture upgraded to tier 2 persists after save → load.
func test_fixture_tier_upgrade_persists_after_save_load() -> void:
	var fixture_id: String = _place_fixture(PLACEMENT_POS)

	var initial_tier: int = _placement.get_fixture_tier(fixture_id)
	assert_eq(
		initial_tier, FixtureDefinition.TierLevel.BASIC,
		"Initial fixture tier should be BASIC"
	)

	var upgraded: bool = _placement.try_upgrade(fixture_id)
	assert_true(upgraded, "Upgrade from BASIC to IMPROVED should succeed")
	assert_eq(
		_placement.get_fixture_tier(fixture_id),
		FixtureDefinition.TierLevel.IMPROVED,
		"Fixture tier should be IMPROVED after upgrade"
	)

	var saved: bool = _save_manager.save_game(SAVE_SLOT)
	assert_true(saved, "save_game should succeed")

	var fresh_placement: FixturePlacementSystem = (
		_create_fresh_placement()
	)
	assert_eq(
		fresh_placement.get_placed_fixtures().size(), 0,
		"Fresh placement system should start empty"
	)

	_save_manager.set_fixture_placement_system(fresh_placement)
	var loaded: bool = _save_manager.load_game(SAVE_SLOT)
	assert_true(loaded, "load_game should succeed")

	assert_eq(
		fresh_placement.get_fixture_at(PLACEMENT_POS),
		fixture_id,
		"Fixture should exist at the same grid position after load"
	)
	assert_eq(
		fresh_placement.get_fixture_tier(fixture_id),
		FixtureDefinition.TierLevel.IMPROVED,
		"Fixture tier should be IMPROVED after load"
	)


## Scenario: max-tier fixture saves and loads correctly.
func test_max_tier_fixture_persists_after_save_load() -> void:
	var fixture_id: String = _place_fixture(PLACEMENT_POS)

	var upgrade_1: bool = _placement.try_upgrade(fixture_id)
	assert_true(upgrade_1, "Upgrade to IMPROVED should succeed")

	var upgrade_2: bool = _placement.try_upgrade(fixture_id)
	assert_true(upgrade_2, "Upgrade to PREMIUM should succeed")

	assert_eq(
		_placement.get_fixture_tier(fixture_id),
		FixtureDefinition.TierLevel.PREMIUM,
		"Fixture tier should be PREMIUM (max) after two upgrades"
	)

	var saved: bool = _save_manager.save_game(SAVE_SLOT)
	assert_true(saved, "save_game should succeed")

	var fresh_placement: FixturePlacementSystem = (
		_create_fresh_placement()
	)
	_save_manager.set_fixture_placement_system(fresh_placement)
	var loaded: bool = _save_manager.load_game(SAVE_SLOT)
	assert_true(loaded, "load_game should succeed")

	assert_eq(
		fresh_placement.get_fixture_at(PLACEMENT_POS),
		fixture_id,
		"Max-tier fixture should exist at same position after load"
	)
	assert_eq(
		fresh_placement.get_fixture_tier(fixture_id),
		FixtureDefinition.TierLevel.PREMIUM,
		"Fixture tier should be PREMIUM after load"
	)


## Scenario: upgrading one fixture does not affect another after save/load.
func test_upgrade_does_not_affect_other_fixtures() -> void:
	var fixture_a: String = _place_fixture(PLACEMENT_POS)
	var fixture_b: String = _place_fixture(SECOND_POS)

	var upgraded: bool = _placement.try_upgrade(fixture_a)
	assert_true(upgraded, "Upgrade of fixture A should succeed")

	assert_eq(
		_placement.get_fixture_tier(fixture_a),
		FixtureDefinition.TierLevel.IMPROVED,
		"Fixture A should be IMPROVED"
	)
	assert_eq(
		_placement.get_fixture_tier(fixture_b),
		FixtureDefinition.TierLevel.BASIC,
		"Fixture B should remain BASIC"
	)

	var saved: bool = _save_manager.save_game(SAVE_SLOT)
	assert_true(saved, "save_game should succeed")

	var fresh_placement: FixturePlacementSystem = (
		_create_fresh_placement()
	)
	_save_manager.set_fixture_placement_system(fresh_placement)
	var loaded: bool = _save_manager.load_game(SAVE_SLOT)
	assert_true(loaded, "load_game should succeed")

	assert_eq(
		fresh_placement.get_fixture_tier(fixture_a),
		FixtureDefinition.TierLevel.IMPROVED,
		"Fixture A should be IMPROVED after load"
	)
	assert_eq(
		fresh_placement.get_fixture_tier(fixture_b),
		FixtureDefinition.TierLevel.BASIC,
		"Fixture B should remain BASIC after load"
	)
	assert_eq(
		fresh_placement.get_fixture_at(PLACEMENT_POS),
		fixture_a,
		"Fixture A should be at its original position"
	)
	assert_eq(
		fresh_placement.get_fixture_at(SECOND_POS),
		fixture_b,
		"Fixture B should be at its original position"
	)
