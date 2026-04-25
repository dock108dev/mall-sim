## Tests the boot → main menu → management hub routing chain (ISSUE-006).
## Verifies no intermediate non-functional scenes exist between menu and hub,
## and that the objective rail receives its first payload on new-game start.
extends GutTest


class FakeDataLoader:
	extends DataLoader

	var run_calls: int = 0
	var load_errors: Array[String] = []

	func run() -> void:
		run_calls += 1

	func get_load_errors() -> Array[String]:
		return load_errors.duplicate()


class FakeSceneTransition:
	extends SceneTransition

	var requested_paths: Array[String] = []

	func transition_to_scene(scene_path: String) -> void:
		requested_paths.append(scene_path)

	func transition_to_packed(_scene: PackedScene) -> void:
		return


var _orig_state: int
var _orig_pending_load_slot: int
var _orig_data_loader: DataLoader
var _orig_scene_transition: SceneTransition
var _orig_boot_completed: bool
var _fake_loader: FakeDataLoader
var _fake_transition: FakeSceneTransition


func before_each() -> void:
	_orig_state = GameManager.current_state
	_orig_pending_load_slot = GameManager.pending_load_slot
	_orig_data_loader = GameManager.data_loader
	_orig_scene_transition = GameManager._scene_transition
	_orig_boot_completed = GameManager._boot_completed

	_fake_loader = FakeDataLoader.new()
	_fake_transition = FakeSceneTransition.new()
	GameManager.data_loader = _fake_loader
	GameManager._scene_transition = _fake_transition
	GameManager.current_state = GameManager.State.MAIN_MENU
	GameManager.pending_load_slot = -1
	GameManager._boot_completed = true


func after_each() -> void:
	GameManager.current_state = _orig_state
	GameManager.pending_load_slot = _orig_pending_load_slot
	GameManager.data_loader = _orig_data_loader
	GameManager._scene_transition = _orig_scene_transition
	GameManager._boot_completed = _orig_boot_completed
	if is_instance_valid(_fake_loader):
		_fake_loader.free()
	if is_instance_valid(_fake_transition):
		_fake_transition.free()


## GAMEPLAY_SCENE_PATH must be mall_hub.tscn — the hub is the direct destination.
func test_gameplay_scene_path_is_mall_hub() -> void:
	assert_true(
		GameManager.GAMEPLAY_SCENE_PATH.ends_with("mall_hub.tscn"),
		"GAMEPLAY_SCENE_PATH must end with mall_hub.tscn, not an intermediate scene"
	)


## game_world.tscn is a child of mall_hub, not the root gameplay scene.
func test_gameplay_path_does_not_route_through_game_world() -> void:
	assert_false(
		GameManager.GAMEPLAY_SCENE_PATH.ends_with("game_world.tscn"),
		"GAMEPLAY_SCENE_PATH must not be game_world.tscn — that scene is a hub child"
	)


## New Game: start_new_game() queues mall_hub.tscn, no intermediate screen.
func test_new_game_queues_mall_hub_scene() -> void:
	GameManager.start_new_game()

	assert_eq(
		_fake_transition.requested_paths.size(), 1,
		"start_new_game must queue exactly one scene transition"
	)
	assert_true(
		_fake_transition.requested_paths[0].ends_with("mall_hub.tscn"),
		"New game transition must target mall_hub.tscn"
	)


## Continue: load_game() also lands on mall_hub.tscn.
func test_load_game_queues_mall_hub_scene() -> void:
	GameManager.load_game(1)

	assert_eq(
		_fake_transition.requested_paths.size(), 1,
		"load_game must queue exactly one scene transition"
	)
	assert_true(
		_fake_transition.requested_paths[0].ends_with("mall_hub.tscn"),
		"Continue/load transition must target mall_hub.tscn"
	)


## start_new_game and load_game both target the same hub scene path.
func test_new_game_and_load_game_share_gameplay_scene_path() -> void:
	GameManager.start_new_game()
	var new_game_path: String = _fake_transition.requested_paths[0]

	_fake_transition.requested_paths.clear()
	GameManager.current_state = GameManager.State.MAIN_MENU
	GameManager.load_game(2)
	var load_path: String = _fake_transition.requested_paths[0]

	assert_eq(
		new_game_path, load_path,
		"New game and continue must load the same hub scene"
	)


## Objective rail: ObjectiveDirector emits objective_changed when day_started fires.
## bootstrap_new_game_state emits day_started(1) during apply_pending_session_state,
## guaranteeing the rail has a payload before gameplay_ready.
func test_objective_director_emits_objective_changed_on_day_started() -> void:
	var received: Array[Dictionary] = []
	var conn: Callable = func(payload: Dictionary) -> void:
		received.append(payload)
	EventBus.objective_changed.connect(conn)

	EventBus.day_started.emit(1)

	EventBus.objective_changed.disconnect(conn)
	assert_gt(
		received.size(), 0,
		"objective_changed must fire when day_started fires (rail gets populated)"
	)
	assert_false(
		received[0].get("hidden", false),
		"Day-1 objective must not be hidden on first load"
	)


## Boot completion flag: mark_boot_completed() sets the flag read by is_boot_completed().
func test_mark_boot_completed_sets_flag() -> void:
	GameManager._boot_completed = false
	assert_false(
		GameManager.is_boot_completed(),
		"Boot flag must start false"
	)
	GameManager.mark_boot_completed()
	assert_true(
		GameManager.is_boot_completed(),
		"mark_boot_completed must set the flag"
	)


## Main menu delegates -1 slot to start_new_game, landing on mall_hub.
func test_start_game_session_negative_slot_routes_to_hub() -> void:
	var menu: Control = load("res://game/scenes/ui/main_menu.gd").new()
	menu._start_game_session(-1)
	menu.free()

	assert_eq(
		_fake_transition.requested_paths.size(), 1,
		"_start_game_session(-1) must trigger a scene transition"
	)
	assert_true(
		_fake_transition.requested_paths[0].ends_with("mall_hub.tscn"),
		"New game from menu must land on mall_hub.tscn"
	)


## Main menu delegates positive slot to load_game, also landing on mall_hub.
func test_start_game_session_with_slot_routes_to_hub() -> void:
	var menu: Control = load("res://game/scenes/ui/main_menu.gd").new()
	menu._start_game_session(2)
	menu.free()

	assert_eq(
		_fake_transition.requested_paths.size(), 1,
		"_start_game_session(slot) must trigger a scene transition"
	)
	assert_true(
		_fake_transition.requested_paths[0].ends_with("mall_hub.tscn"),
		"Continue from menu must also land on mall_hub.tscn"
	)
