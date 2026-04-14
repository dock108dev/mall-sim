## Integration test: BuildMode session — enter → place fixture → exit → save/load persistence.
extends GutTest


const SAVE_SLOT: int = 1
const ENTRY_EDGE_Y: int = 8
const PLACEMENT_POS: Vector2i = Vector2i(5, 5)
const FIXTURE_TYPE: String = "floor_rack"
const REGISTER_ID: String = "register_test_001"
const REGISTER_POS: Vector2i = Vector2i(0, 0)

var _build_mode: BuildModeSystem
var _placement: FixturePlacementSystem
var _economy: EconomySystem
var _inventory: InventorySystem
var _time_system: TimeSystem
var _save_manager: SaveManager

var _build_mode_entered_count: int = 0
var _build_mode_exited_count: int = 0
var _placed_fixture_id: String = ""
var _placed_pos: Vector2i = Vector2i.ZERO
var _placed_rotation: int = -1

var _saved_game_state: GameManager.GameState
var _saved_store_id: StringName
var _saved_owned_stores: Array[StringName]


func before_each() -> void:
	_saved_game_state = GameManager.current_state
	_saved_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	GameManager.current_store_id = &"sports"
	GameManager.owned_stores = [&"sports"]

	_economy = EconomySystem.new()
	add_child_autofree(_economy)
	_economy.initialize(5000.0)

	_inventory = InventorySystem.new()
	add_child_autofree(_inventory)
	_inventory.initialize(null)

	_time_system = TimeSystem.new()
	add_child_autofree(_time_system)
	_time_system.initialize()

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

	_placement.register_existing_fixture(
		REGISTER_ID, "register", REGISTER_POS, 0, true, 90.0
	)

	_build_mode.set_placement_system(_placement)

	_save_manager = SaveManager.new()
	add_child_autofree(_save_manager)
	_save_manager.initialize(_economy, _inventory, _time_system)
	_save_manager.set_fixture_placement_system(_placement)

	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)

	_build_mode_entered_count = 0
	_build_mode_exited_count = 0
	_placed_fixture_id = ""
	_placed_pos = Vector2i.ZERO
	_placed_rotation = -1

	EventBus.build_mode_entered.connect(_on_build_mode_entered)
	EventBus.build_mode_exited.connect(_on_build_mode_exited)
	EventBus.fixture_placed.connect(_on_fixture_placed)


func after_each() -> void:
	_save_manager.delete_save(SAVE_SLOT)
	_safe_disconnect(EventBus.build_mode_entered, _on_build_mode_entered)
	_safe_disconnect(EventBus.build_mode_exited, _on_build_mode_exited)
	_safe_disconnect(EventBus.fixture_placed, _on_fixture_placed)
	GameManager.current_state = _saved_game_state
	GameManager.current_store_id = _saved_store_id
	GameManager.owned_stores = _saved_owned_stores


func _safe_disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


func _on_build_mode_entered() -> void:
	_build_mode_entered_count += 1


func _on_build_mode_exited() -> void:
	_build_mode_exited_count += 1


func _on_fixture_placed(
	fixture_id: String, pos: Vector2i, rot: int
) -> void:
	_placed_fixture_id = fixture_id
	_placed_pos = pos
	_placed_rotation = rot


## Full integration scenario: enter → place → exit → save → reload → verify.
func test_build_mode_session_with_save_load_persistence() -> void:
	# Step 1: Enter build mode.
	_build_mode.enter_build_mode()

	assert_true(
		_build_mode.is_active,
		"BuildModeSystem should be active after entering build mode"
	)
	assert_eq(
		_build_mode_entered_count, 1,
		"build_mode_entered signal should fire exactly once"
	)

	# Step 2: Place a fixture using select + try_place.
	_placement.select_fixture(FIXTURE_TYPE)
	var placed: bool = _placement.try_place(PLACEMENT_POS)

	assert_true(placed, "floor_rack placement at (5, 5) should succeed")
	assert_false(
		_placed_fixture_id.is_empty(),
		"fixture_placed signal should fire and carry a fixture_id"
	)
	assert_eq(
		_placed_pos, PLACEMENT_POS,
		"fixture_placed signal should carry the correct grid position"
	)
	assert_eq(
		_placed_rotation, 0,
		"fixture_placed signal should carry rotation 0"
	)

	# Step 3: Verify get_placed_fixtures returns the placed fixture.
	var fixtures_before: Array[Dictionary] = _placement.get_placed_fixtures()
	var ids_before: Array[String] = []
	for f: Dictionary in fixtures_before:
		ids_before.append(f.get("fixture_id", "") as String)
	assert_true(
		ids_before.has(_placed_fixture_id),
		"get_placed_fixtures should include the placed fixture before exit"
	)

	# Step 4: Exit build mode (register is already placed, so exit is valid).
	_build_mode.exit_build_mode()

	assert_false(
		_build_mode.is_active,
		"BuildModeSystem should be inactive after exiting build mode"
	)
	assert_eq(
		_build_mode_exited_count, 1,
		"build_mode_exited signal should fire exactly once"
	)
	assert_eq(
		_build_mode.current_state,
		BuildModeSystem.State.IDLE,
		"BuildModeSystem state should return to IDLE after exit"
	)

	# Step 5: Save the current game state.
	var saved: bool = _save_manager.save_game(SAVE_SLOT)
	assert_true(saved, "save_game should return true with no push_error calls")

	# Step 6: Reinitialize a fresh FixturePlacementSystem (simulating a reload).
	var fresh_grid: BuildModeGrid = BuildModeGrid.new()
	add_child_autofree(fresh_grid)
	fresh_grid.initialize(BuildModeGrid.StoreSize.SMALL, Vector3.ZERO)

	var fresh_placement: FixturePlacementSystem = FixturePlacementSystem.new()
	add_child_autofree(fresh_placement)
	fresh_placement.initialize(
		fresh_grid,
		_inventory,
		_economy,
		ENTRY_EDGE_Y,
		BuildModeGrid.StoreSize.SMALL
	)

	assert_eq(
		fresh_placement.get_placed_fixtures().size(), 0,
		"Fresh FixturePlacementSystem should start empty"
	)

	_save_manager.set_fixture_placement_system(fresh_placement)

	# Step 7: Load and verify fixture state is restored.
	var loaded: bool = _save_manager.load_game(SAVE_SLOT)
	assert_true(loaded, "load_game should return true")

	assert_eq(
		fresh_placement.get_fixture_at(PLACEMENT_POS),
		_placed_fixture_id,
		"Loaded system should have the same fixture at the same position"
	)

	var fixtures_after: Array[Dictionary] = fresh_placement.get_placed_fixtures()
	var found_type: String = ""
	for f: Dictionary in fixtures_after:
		if f.get("fixture_id", "") == _placed_fixture_id:
			found_type = f.get("fixture_type", "") as String
			break

	assert_eq(
		found_type, FIXTURE_TYPE,
		"Loaded fixture should preserve its fixture_type"
	)
