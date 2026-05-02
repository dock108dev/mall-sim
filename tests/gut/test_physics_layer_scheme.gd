## Pins the project-wide physics-layer naming scheme so the player CharacterBody,
## customer NPCs, store fixtures, walls, and interactable Area3Ds stay on
## semantically distinct layers. Without this contract the InteractionRay can
## hit walls before reaching interactables behind them, and physics
## CharacterBody3D-vs-CharacterBody3D contact between the player and customers
## stops moving cleanly past each other.
##
## Layer scheme (see `project.godot [layer_names]`):
##   1 = world_geometry        bit 1
##   2 = store_fixtures        bit 2
##   3 = player                bit 4
##   4 = customers             bit 8
##   5 = interactable_triggers bit 16
extends GutTest

const LAYER_WORLD: int = 1
const LAYER_FIXTURES: int = 2
const LAYER_PLAYER_BIT: int = 4
const LAYER_CUSTOMERS_BIT: int = 8
const LAYER_INTERACTABLE_BIT: int = 16

const PLAYER_SCENE_PATH: String = "res://game/scenes/player/store_player_body.tscn"
const CUSTOMER_SCENE_PATHS: Array[String] = [
	"res://game/scenes/characters/customer.tscn",
	"res://game/scenes/characters/customer_npc.tscn",
	"res://game/scenes/characters/shopper_ai.tscn",
]
const RETRO_GAMES_PATH: String = "res://game/scenes/stores/retro_games.tscn"


func test_named_layers_are_declared_in_project_godot() -> void:
	var settings_keys: Array[String] = [
		"layer_names/3d_physics/layer_1",
		"layer_names/3d_physics/layer_2",
		"layer_names/3d_physics/layer_3",
		"layer_names/3d_physics/layer_4",
		"layer_names/3d_physics/layer_5",
	]
	var expected: Array[String] = [
		"world_geometry",
		"store_fixtures",
		"player",
		"customers",
		"interactable_triggers",
	]
	for i: int in range(settings_keys.size()):
		assert_true(
			ProjectSettings.has_setting(settings_keys[i]),
			"%s must be declared in project.godot" % settings_keys[i]
		)
		var actual: String = String(ProjectSettings.get_setting(settings_keys[i], ""))
		assert_eq(
			actual, expected[i],
			"%s must be named '%s' (got '%s')"
			% [settings_keys[i], expected[i], actual]
		)


func test_interactable_constant_targets_named_layer_5_bit() -> void:
	assert_eq(
		Interactable.INTERACTABLE_LAYER, LAYER_INTERACTABLE_BIT,
		"Interactable.INTERACTABLE_LAYER must equal the interactable_triggers "
		+ "bit (16) so the InteractionRay only hits dedicated triggers"
	)


func test_interaction_ray_default_mask_targets_interactable_bit_only() -> void:
	var ray_script: Script = load(
		"res://game/scripts/player/interaction_ray.gd"
	)
	assert_not_null(ray_script, "interaction_ray.gd must load")
	var ray: Node = ray_script.new()
	add_child_autofree(ray)
	assert_eq(
		int(ray.interaction_mask), LAYER_INTERACTABLE_BIT,
		"InteractionRay.interaction_mask default must equal the "
		+ "interactable_triggers bit so walls cannot occlude interactables"
	)


func _read_root_collision(scene_path: String) -> Dictionary:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return {}
	var state: SceneState = packed.get_state()
	var result: Dictionary = {"layer": -1, "mask": -1}
	for i: int in range(state.get_node_property_count(0)):
		var prop_name: String = state.get_node_property_name(0, i)
		var value: Variant = state.get_node_property_value(0, i)
		if prop_name == "collision_layer":
			result["layer"] = int(value)
		elif prop_name == "collision_mask":
			result["mask"] = int(value)
	return result


func test_store_player_body_collides_with_world_and_fixtures_only() -> void:
	var collision: Dictionary = _read_root_collision(PLAYER_SCENE_PATH)
	assert_eq(
		int(collision.get("layer", -1)), LAYER_PLAYER_BIT,
		"StorePlayerBody must declare collision_layer = 4 (player bit) in the scene"
	)
	assert_eq(
		int(collision.get("mask", -1)), LAYER_WORLD | LAYER_FIXTURES,
		"StorePlayerBody must declare collision_mask = 3 "
		+ "(world_geometry + store_fixtures) so it ignores customer bodies"
	)


func test_customer_scenes_use_customers_layer_with_world_fixtures_mask() -> void:
	for path: String in CUSTOMER_SCENE_PATHS:
		var collision: Dictionary = _read_root_collision(path)
		assert_eq(
			int(collision.get("layer", -1)), LAYER_CUSTOMERS_BIT,
			"%s root CharacterBody3D must declare collision_layer = 8 (customers bit)"
				% path
		)
		assert_eq(
			int(collision.get("mask", -1)), LAYER_WORLD | LAYER_FIXTURES,
			"%s root CharacterBody3D must declare collision_mask = 3 "
				% path + "(world + fixtures) so it slides past customers and the player"
		)


func test_retro_games_walls_explicit_on_world_geometry_layer() -> void:
	var packed: PackedScene = load(RETRO_GAMES_PATH) as PackedScene
	assert_not_null(packed, "retro_games.tscn must load")
	if packed == null:
		return
	var root: Node = packed.instantiate()
	add_child_autofree(root)
	var wall_names: Array[String] = [
		"Floor",
		"BackWallBody",
		"LeftWallBody",
		"RightWallBody",
		"FrontWallLeftBody",
		"FrontWallRightBody",
	]
	for wall_name: String in wall_names:
		var wall: StaticBody3D = root.get_node_or_null(wall_name) as StaticBody3D
		assert_not_null(wall, "%s must exist in retro_games.tscn" % wall_name)
		if wall == null:
			continue
		assert_eq(
			wall.collision_layer, LAYER_WORLD,
			"%s.collision_layer must equal 1 (world_geometry)" % wall_name
		)
		assert_eq(
			wall.collision_mask, 0,
			"%s.collision_mask must equal 0 — static world geometry is "
			+ "scanned by other bodies but never scans itself" % wall_name
		)


func test_retro_games_fixtures_explicit_on_store_fixtures_layer() -> void:
	var packed: PackedScene = load(RETRO_GAMES_PATH) as PackedScene
	if packed == null:
		return
	var root: Node = packed.instantiate()
	add_child_autofree(root)
	var fixture_paths: Array[String] = [
		"CartRackLeft/StaticBody3D",
		"CartRackRight/StaticBody3D",
		"GlassCase/StaticBody3D",
		"ConsoleShelf/StaticBody3D",
		"AccessoriesBin/StaticBody3D",
		"Checkout/StaticBody3D",
		"BackroomDoor/StaticBody3D",
	]
	for path: String in fixture_paths:
		var body: StaticBody3D = root.get_node_or_null(path) as StaticBody3D
		assert_not_null(body, "%s must exist" % path)
		if body == null:
			continue
		assert_eq(
			body.collision_layer, LAYER_FIXTURES,
			"%s.collision_layer must equal 2 (store_fixtures)" % path
		)
		assert_eq(
			body.collision_mask, 0,
			"%s.collision_mask must equal 0 — fixtures do not scan other bodies"
				% path
		)


func test_retro_games_interactable_runtime_layer_matches_constant() -> void:
	# After Interactable._ready() runs, the inner InteractionArea must be on the
	# interactable_triggers bit. The outer Interactable Area3D collision_layer
	# is intentionally cleared to 0.
	var packed: PackedScene = load(RETRO_GAMES_PATH) as PackedScene
	if packed == null:
		return
	var root: Node = packed.instantiate()
	add_child_autofree(root)
	var interactables: Array[Node] = root.get_tree().get_nodes_in_group(
		"interactable"
	)
	assert_gt(
		interactables.size(), 0,
		"retro_games.tscn must register at least one Interactable"
	)
	for node: Node in interactables:
		var it := node as Interactable
		if it == null:
			continue
		assert_eq(
			it.collision_layer, 0,
			"%s outer Area3D must be cleared to layer 0 by Interactable._ready()"
				% it.name
		)
		var area: Area3D = it.get_interaction_area()
		assert_not_null(area, "%s must expose an InteractionArea" % it.name)
		if area == null:
			continue
		assert_eq(
			area.collision_layer, LAYER_INTERACTABLE_BIT,
			"%s/InteractionArea must be on the interactable_triggers bit"
				% it.name
		)
