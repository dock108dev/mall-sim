## Integration test: build mode fixture placement pipeline end-to-end.
extends GutTest

const TEST_SIGNAL_UTILS: GDScript = preload("res://game/tests/test_signal_utils.gd")

const ENTRY_EDGE_Y: int = 8
const REGISTER_ID: String = "register_placement_test"
const REGISTER_POS: Vector2i = Vector2i(0, 0)
const PLACE_POS: Vector2i = Vector2i(5, 5)
const REMOVE_POS: Vector2i = Vector2i(7, 3)
const STARTING_CASH: float = 10000.0
const TEST_STORE: StringName = &"sports"
const FIXTURE_TYPE: String = "floor_rack"

var _build_mode: BuildModeSystem
var _placement: FixturePlacementSystem
var _economy: EconomySystem
var _inventory: InventorySystem
var _data_loader: DataLoader

var _saved_game_state: GameManager.GameState
var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]
var _saved_data_loader: DataLoader

var _placed_fixture_id: String = ""
var _placed_grid_pos: Vector2i = Vector2i.ZERO
var _removed_fixture_id: String = ""
var _removed_grid_pos: Vector2i = Vector2i.ZERO
var _invalid_reason: String = ""


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

	_build_mode = BuildModeSystem.new()
	add_child_autofree(_build_mode)
	_build_mode.initialize(null, BuildModeGrid.StoreSize.SMALL, Vector3.ZERO)

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

	_placement.register_existing_fixture(
		REGISTER_ID, "register", REGISTER_POS, 0, true, 90.0
	)
	_build_mode.set_placement_system(_placement)

	watch_signals(EventBus)
	EventBus.fixture_placed.connect(_on_fixture_placed)
	EventBus.fixture_removed.connect(_on_fixture_removed)
	EventBus.fixture_placement_invalid.connect(_on_fixture_placement_invalid)
	_placed_fixture_id = ""
	_placed_grid_pos = Vector2i.ZERO
	_removed_fixture_id = ""
	_removed_grid_pos = Vector2i.ZERO
	_invalid_reason = ""


func after_each() -> void:
	TEST_SIGNAL_UTILS.safe_disconnect(EventBus.fixture_placed, _on_fixture_placed)
	TEST_SIGNAL_UTILS.safe_disconnect(EventBus.fixture_removed, _on_fixture_removed)
	TEST_SIGNAL_UTILS.safe_disconnect(
		EventBus.fixture_placement_invalid, _on_fixture_placement_invalid
	)
	GameManager.current_state = _saved_game_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores
	GameManager.data_loader = _saved_data_loader


func _on_fixture_placed(fixture_id: String, grid_pos: Vector2i, _rot: int) -> void:
	_placed_fixture_id = fixture_id
	_placed_grid_pos = grid_pos


func _on_fixture_removed(fixture_id: String, grid_pos: Vector2i) -> void:
	_removed_fixture_id = fixture_id
	_removed_grid_pos = grid_pos


func _on_fixture_placement_invalid(reason: String) -> void:
	_invalid_reason = reason


## Scenario: valid placement updates slot state and emits fixture_placed.
func test_valid_placement_updates_state_and_emits_signal() -> void:
	_placement.select_fixture(FIXTURE_TYPE)
	var placed: bool = _placement.try_place(PLACE_POS)

	assert_true(placed, "try_place should return true for a valid placement")
	assert_false(_placed_fixture_id.is_empty(), "fixture_placed signal should carry a fixture_id")
	assert_eq(_placed_grid_pos, PLACE_POS, "fixture_placed signal should carry correct grid_pos")
	assert_eq(
		_placement.get_fixture_at(PLACE_POS),
		_placed_fixture_id,
		"get_fixture_at should return the placed fixture_id"
	)
	assert_signal_emitted(EventBus, "fixture_placed")


## Scenario: occupied slot is rejected, state is unchanged, signal emitted.
func test_occupied_slot_rejects_placement() -> void:
	_placement.select_fixture(FIXTURE_TYPE)
	var first: bool = _placement.try_place(PLACE_POS)
	assert_true(first, "First placement should succeed")

	var original_id: String = _placement.get_fixture_at(PLACE_POS)
	_placed_fixture_id = ""
	_invalid_reason = ""

	_placement.select_fixture(FIXTURE_TYPE)
	var second: bool = _placement.try_place(PLACE_POS)

	assert_false(second, "Second placement at occupied position should fail")
	assert_true(_placed_fixture_id.is_empty(), "fixture_placed should not emit on failure")
	assert_eq(
		_placement.get_fixture_at(PLACE_POS),
		original_id,
		"Slot should be unchanged — original fixture still occupies it"
	)
	assert_signal_emitted(EventBus, "fixture_placement_invalid")
	assert_false(_invalid_reason.is_empty(), "Invalid reason should be non-empty")


## Scenario: unknown fixture type is rejected and logged via push_error.
func test_unknown_fixture_type_is_rejected() -> void:
	_placement.select_fixture("nonexistent_fixture_type")
	var placed: bool = _placement.try_place(PLACE_POS)

	assert_false(placed, "Unknown fixture type should be rejected")
	assert_true(
		_placement.get_fixture_at(PLACE_POS).is_empty(),
		"Slot should remain empty after rejection"
	)
	assert_true(_placed_fixture_id.is_empty(), "fixture_placed should not emit for unknown type")


## Scenario: remove_fixture clears slot and emits fixture_removed.
func test_remove_fixture_clears_slot_and_emits_signal() -> void:
	_placement.select_fixture(FIXTURE_TYPE)
	var placed: bool = _placement.try_place(REMOVE_POS)
	assert_true(placed, "Placement before removal should succeed")

	var fixture_id: String = _placement.get_fixture_at(REMOVE_POS)
	assert_false(fixture_id.is_empty(), "Fixture should exist at position before removal")

	_removed_fixture_id = ""
	_removed_grid_pos = Vector2i.ZERO

	var removed: bool = _placement.try_remove(REMOVE_POS)

	assert_true(removed, "try_remove should return true for a valid removal")
	assert_true(
		_placement.get_fixture_at(REMOVE_POS).is_empty(),
		"Slot should be empty after removal"
	)
	assert_signal_emitted(EventBus, "fixture_removed")
	assert_eq(
		_removed_fixture_id, fixture_id,
		"fixture_removed signal should carry the correct fixture_id"
	)
	assert_eq(
		_removed_grid_pos, REMOVE_POS,
		"fixture_removed signal should carry the correct grid_pos"
	)
