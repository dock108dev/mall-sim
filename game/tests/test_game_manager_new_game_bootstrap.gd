## GUT tests for GameManager new-game bootstrap ordering.
extends GutTest


class FakeDataLoader:
	extends DataLoader

	func run() -> void:
		return

	func get_load_errors() -> Array[String]:
		return []


class FakeGameWorld:
	extends Node

	var calls: Array[String] = []

	func initialize_systems() -> void:
		calls.append("initialize_systems")

	func bootstrap_new_game_state(store_id: StringName) -> void:
		calls.append("bootstrap_new_game_state:%s" % store_id)


var _saved_current_store_id: StringName = &""
var _saved_owned_stores: Array[StringName] = []
var _saved_data_loader: DataLoader = null
var _fake_data_loader: FakeDataLoader = null


func before_each() -> void:
	_saved_current_store_id = GameManager.current_store_id
	_saved_owned_stores = GameManager.owned_stores.duplicate()
	_saved_data_loader = GameManager.data_loader
	_fake_data_loader = FakeDataLoader.new()
	GameManager.data_loader = _fake_data_loader


func after_each() -> void:
	GameManager.current_store_id = _saved_current_store_id
	GameManager.owned_stores = _saved_owned_stores
	GameManager.data_loader = _saved_data_loader
	if is_instance_valid(_fake_data_loader):
		_fake_data_loader.free()


func test_start_new_game_initializes_systems_before_bootstrap() -> void:
	var fake_world := FakeGameWorld.new()
	add_child_autofree(fake_world)
	GameManager.current_store_id = &"retro_games"
	GameManager.owned_stores = [&"retro_games"]

	GameManager._start_new_game(fake_world)

	assert_eq(
		fake_world.calls,
		[
			"initialize_systems",
			"bootstrap_new_game_state:sports",
		],
		"New game bootstrap should initialize runtime systems before seeding state"
	)
	assert_eq(GameManager.current_store_id, &"")
	assert_eq(GameManager.owned_stores, [])
