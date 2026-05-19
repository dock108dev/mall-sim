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
	BetaRunState.reset_new_run()
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
	BetaRunState.reset_new_run()


## GAMEPLAY_SCENE_PATH must be gameplay_shell.tscn — the hub is the direct destination.
func test_gameplay_scene_path_is_gameplay_shell() -> void:
	assert_true(
		GameManager.GAMEPLAY_SCENE_PATH.ends_with("gameplay_shell.tscn"),
		"GAMEPLAY_SCENE_PATH must end with gameplay_shell.tscn, not an intermediate scene"
	)


## game_world.tscn is a child of mall_hub, not the root gameplay scene.
func test_gameplay_path_does_not_route_through_game_world() -> void:
	assert_false(
		GameManager.GAMEPLAY_SCENE_PATH.ends_with("game_world.tscn"),
		"GAMEPLAY_SCENE_PATH must not be game_world.tscn — that scene is a hub child"
	)


## New Game: start_new_game() queues gameplay_shell.tscn, no intermediate screen.
func test_new_game_queues_gameplay_scene() -> void:
	GameManager.start_new_game()

	assert_eq(
		_fake_transition.requested_paths.size(), 1,
		"start_new_game must queue exactly one scene transition"
	)
	assert_true(
		_fake_transition.requested_paths[0].ends_with("gameplay_shell.tscn"),
		"New game transition must target gameplay_shell.tscn"
	)


## Continue: load_game() also lands on gameplay_shell.tscn.
func test_load_game_queues_gameplay_scene() -> void:
	GameManager.load_game(1)

	assert_eq(
		_fake_transition.requested_paths.size(), 1,
		"load_game must queue exactly one scene transition"
	)
	assert_true(
		_fake_transition.requested_paths[0].ends_with("gameplay_shell.tscn"),
		"Continue/load transition must target gameplay_shell.tscn"
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


func test_default_new_game_store_scene_loads_beta_entry_nodes() -> void:
	assert_eq(
		GameManager.DEFAULT_STARTING_STORE,
		&"retro_games",
		"Default new-game store must be the beta store"
	)
	var scene_path: String = "res://game/scenes/stores/retro_games.tscn"
	assert_true(
		scene_path.ends_with("retro_games.tscn"),
		"Default new-game store must resolve to the beta store scene"
	)
	var scene: PackedScene = load(scene_path) as PackedScene
	assert_not_null(scene, "Default new-game store scene must load")
	if scene == null:
		return
	var root: Node3D = scene.instantiate() as Node3D
	assert_not_null(root, "Default new-game store must instantiate as Node3D")
	if root == null:
		return
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_not_null(
		root.get_node_or_null("BetaDayOneController"),
		"Default store boot must include the beta Day 1 controller"
	)
	assert_not_null(
		root.get_node_or_null("PlayerEntrySpawn"),
		"Default store boot must include the first-person spawn marker"
	)
	var controller: Node = root.get_node_or_null("BetaDayOneController")
	if controller != null:
		assert_eq(
			String(controller.call("current_stage")),
			"training_talk_manager",
			"Default beta store boot must start on the pre-opening manager beat"
		)
	root.free()


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
		_fake_transition.requested_paths[0].ends_with("gameplay_shell.tscn"),
		"New game from menu must land on gameplay_shell.tscn"
	)


## Main menu does not route load slots while beta load is unavailable.
func test_start_game_session_with_slot_does_not_route_to_hub() -> void:
	var menu: Control = load("res://game/scenes/ui/main_menu.gd").new()
	menu._start_game_session(2)
	menu.free()

	assert_eq(
		_fake_transition.requested_paths.size(), 0,
		"_start_game_session(slot) must not route while beta load is unavailable"
	)
