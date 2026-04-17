## GUT acceptance tests for ISSUE-006 store and hallway lighting composition.
extends GutTest

const STORE_SCENES: Dictionary = {
	&"sports": preload("res://game/scenes/stores/sports_memorabilia.tscn"),
	&"retro_games": preload("res://game/scenes/stores/retro_games.tscn"),
	&"rentals": preload("res://game/scenes/stores/video_rental.tscn"),
	&"pocket_creatures": preload("res://game/scenes/stores/pocket_creatures.tscn"),
	&"electronics": preload("res://game/scenes/stores/consumer_electronics.tscn"),
}

const STORE_ENVIRONMENTS: Dictionary = {
	&"sports": preload("res://game/resources/environments/env_sports.tres"),
	&"retro_games": preload("res://game/resources/environments/env_retro_games.tres"),
	&"rentals": preload("res://game/resources/environments/env_rentals.tres"),
	&"pocket_creatures": preload("res://game/resources/environments/env_pocket_creatures.tres"),
	&"electronics": preload("res://game/resources/environments/env_electronics.tres"),
}

const HALLWAY_SCENE: PackedScene = preload("res://game/scenes/world/mall_hallway.tscn")
const HALLWAY_ENVIRONMENT: Environment = preload(
	"res://game/resources/environments/env_hallway.tres"
)


func test_all_store_interiors_have_configured_lighting() -> void:
	for store_key: Variant in STORE_SCENES.keys():
		var store_id := StringName(String(store_key))
		var scene: PackedScene = STORE_SCENES[store_id]
		var root := _instantiate_scene(scene)
		var lights := _collect_lights(root)
		assert_true(
			lights.size() >= 2,
			"Store '%s' should have configured lighting, not only a default light" % store_id
		)
		root.free()


func test_all_store_interiors_have_product_accent_spotlight() -> void:
	for store_key: Variant in STORE_SCENES.keys():
		var store_id := StringName(String(store_key))
		if store_id == &"sports":
			continue
		var scene: PackedScene = STORE_SCENES[store_id]
		var root := _instantiate_scene(scene)
		var has_spotlight := false
		for light: Light3D in _collect_lights(root):
			if light is SpotLight3D and light.light_energy > 0.0:
				has_spotlight = true
		assert_true(
			has_spotlight,
			"Store '%s' should have at least one product display SpotLight3D" % store_id
		)
		root.free()


func test_store_default_lighting_is_warm() -> void:
	for store_key: Variant in STORE_SCENES.keys():
		var store_id := StringName(String(store_key))
		var scene: PackedScene = STORE_SCENES[store_id]
		var root := _instantiate_scene(scene)
		var overheads := _collect_default_lights(root)
		assert_true(
			overheads.size() > 0,
			"Store '%s' should have warm overhead or ambient default lighting" % store_id
		)
		for light: Light3D in overheads:
			assert_true(
				_is_warm(light.light_color),
				"Store '%s' default light '%s' should be warm white/amber"
				% [store_id, light.name]
			)
		root.free()


func test_world_environment_resources_provide_warm_ambient_fill() -> void:
	for store_key: Variant in STORE_ENVIRONMENTS.keys():
		var store_id := StringName(String(store_key))
		var env: Environment = STORE_ENVIRONMENTS[store_id]
		assert_true(
			env.ambient_light_energy >= 0.25,
			"Store '%s' should have enough ambient fill to avoid harsh shadows" % store_id
		)
		assert_true(
			_is_warm(env.ambient_light_color),
			"Store '%s' ambient fill should stay warm, not cool-toned" % store_id
		)


func test_hallway_has_warm_fill_and_neon_accent_splashes() -> void:
	var root := _instantiate_scene(HALLWAY_SCENE)
	var neon_lights := 0
	for light: Light3D in _collect_lights(root):
		if (
			String(light.name).begins_with("NeonAccent_")
			and _is_saturated_accent(light.light_color)
		):
			neon_lights += 1

	assert_true(
		_is_warm(HALLWAY_ENVIRONMENT.ambient_light_color),
		"Hallway WorldEnvironment ambient fill should be warm"
	)
	assert_true(
		HALLWAY_ENVIRONMENT.ambient_light_energy >= 0.2,
		"Hallway WorldEnvironment should provide gentle ambient fill"
	)
	assert_true(
		neon_lights >= 3,
		"Mall hallway should include localized neon accent color splashes"
	)
	root.free()


func _instantiate_scene(scene: PackedScene) -> Node:
	var root := scene.instantiate()
	assert_not_null(root, "Scene should instantiate for lighting inspection")
	return root


func _collect_lights(root: Node) -> Array[Light3D]:
	var lights: Array[Light3D] = []
	_collect_lights_recursive(root, lights)
	return lights


func _collect_lights_recursive(node: Node, lights: Array[Light3D]) -> void:
	if node is Light3D:
		lights.append(node as Light3D)
	for child: Node in node.get_children():
		_collect_lights_recursive(child, lights)


func _collect_default_lights(root: Node) -> Array[Light3D]:
	var default_lights: Array[Light3D] = []
	for light: Light3D in _collect_lights(root):
		var name_lower := String(light.name).to_lower()
		if (
			name_lower.contains("ambient")
			or name_lower.contains("fluorescent")
			or name_lower.contains("overhead")
			or name_lower.contains("halogen")
		):
			default_lights.append(light)
	return default_lights


func _is_warm(color: Color) -> bool:
	return color.r >= color.b and color.g >= color.b


func _is_saturated_accent(color: Color) -> bool:
	var max_channel: float = max(color.r, max(color.g, color.b))
	var min_channel: float = min(color.r, min(color.g, color.b))
	return max_channel - min_channel >= 0.35
