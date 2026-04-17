## Verifies ISSUE-051 storefront readability cues across all five store scenes.
extends GutTest


const HALLWAY_FLOOR_MATERIAL: Material = preload(
	"res://game/assets/materials/mat_floor_tile_cream.tres"
)
const STORE_READABILITY: Array[Dictionary] = [
	{
		"scene_path": "res://game/scenes/stores/sports_memorabilia.tscn",
		"sign_name": "Sports Memorabilia",
		"tagline": "Cards & Signed Gear",
	},
	{
		"scene_path": "res://game/scenes/stores/retro_games.tscn",
		"sign_name": "Retro Games",
		"tagline": "Consoles & Classics",
	},
	{
		"scene_path": "res://game/scenes/stores/video_rental.tscn",
		"sign_name": "Video Rental",
		"tagline": "Movies, Games & Snacks",
	},
	{
		"scene_path": "res://game/scenes/stores/pocket_creatures.tscn",
		"sign_name": "PocketCreatures",
		"tagline": "Cards, Packs & Tournaments",
	},
	{
		"scene_path": "res://game/scenes/stores/consumer_electronics.tscn",
		"sign_name": "Consumer Electronics",
		"tagline": "Devices & Gadgets",
	},
]


func test_all_store_scenes_have_distinct_threshold_trim() -> void:
	for config: Dictionary in STORE_READABILITY:
		var root: Node3D = _instantiate_store(config)
		var threshold: MeshInstance3D = root.find_child(
			"ThresholdStrip", true, false
		) as MeshInstance3D
		assert_not_null(
			threshold,
			"%s should include a threshold strip" % config["scene_path"]
		)
		if threshold == null:
			continue
 
		var threshold_mesh: BoxMesh = threshold.mesh as BoxMesh
		assert_not_null(
			threshold_mesh,
			"%s threshold should use a BoxMesh" % config["scene_path"]
		)
		if threshold_mesh == null:
			continue
 
		assert_gte(
			threshold_mesh.size.z, 0.3,
			"%s threshold should be at least 0.3m deep" % config["scene_path"]
		)
		assert_lte(
			threshold_mesh.size.z, 0.5,
			"%s threshold should stay within the 0.5m trim target" % config["scene_path"]
		)
 
		var threshold_material: Material = threshold.get_surface_override_material(0)
		assert_not_null(
			threshold_material,
			"%s threshold should override its material" % config["scene_path"]
		)
		assert_ne(
			threshold_material,
			HALLWAY_FLOOR_MATERIAL,
			"%s threshold should differ from the hallway floor material" % config["scene_path"]
		)


func test_all_store_scenes_use_two_tier_sign_hierarchy() -> void:
	for config: Dictionary in STORE_READABILITY:
		var root: Node3D = _instantiate_store(config)
		var sign_name: Label3D = root.find_child(
			"SignName", true, false
		) as Label3D
		var sign_tagline: Label3D = root.find_child(
			"SignTagline", true, false
		) as Label3D
		var sign_backing: MeshInstance3D = root.find_child(
			"SignBacking", true, false
		) as MeshInstance3D

		assert_not_null(
			sign_name,
			"%s should have a primary sign label" % config["scene_path"]
		)
		assert_not_null(
			sign_tagline,
			"%s should have a secondary sign label" % config["scene_path"]
		)
		assert_not_null(
			sign_backing,
			"%s should have a lit sign backing" % config["scene_path"]
		)
		if sign_name == null or sign_tagline == null or sign_backing == null:
			continue
 
		assert_eq(sign_name.text, config["sign_name"])
		assert_eq(sign_tagline.text, config["tagline"])
		assert_gt(
			sign_name.font_size, sign_tagline.font_size,
			"%s primary sign should be larger than the tagline" % config["scene_path"]
		)
		assert_gt(
			sign_name.transform.origin.y, sign_tagline.transform.origin.y,
			"%s primary sign should sit above the tagline" % config["scene_path"]
		)
		assert_gte(
			sign_name.outline_size, 6,
			"%s primary sign should have a readable outline" % config["scene_path"]
		)

		var sign_backing_material := sign_backing.get_surface_override_material(0)
		assert_true(
			sign_backing_material is StandardMaterial3D,
			"%s sign backing should use a lit StandardMaterial3D" % config["scene_path"]
		)
		if sign_backing_material is StandardMaterial3D:
			assert_true(
				(sign_backing_material as StandardMaterial3D).emission_enabled,
				"%s sign backing should stay emissive" % config["scene_path"]
			)


func test_all_store_scenes_have_entry_silhouette_panels() -> void:
	for config: Dictionary in STORE_READABILITY:
		var root: Node3D = _instantiate_store(config)
		var front_wall: MeshInstance3D = root.find_child(
			"FrontWallLeft", true, false
		) as MeshInstance3D
		var left_panel: MeshInstance3D = root.find_child(
			"SilhouetteLeftPanel", true, false
		) as MeshInstance3D
		var right_panel: MeshInstance3D = root.find_child(
			"SilhouetteRightPanel", true, false
		) as MeshInstance3D
		var header_panel: MeshInstance3D = root.find_child(
			"SilhouetteHeaderPanel", true, false
		) as MeshInstance3D

		assert_not_null(
			left_panel,
			"%s should have a left silhouette panel" % config["scene_path"]
		)
		assert_not_null(
			right_panel,
			"%s should have a right silhouette panel" % config["scene_path"]
		)
		assert_not_null(
			header_panel,
			"%s should have a header silhouette panel" % config["scene_path"]
		)
		if (
			front_wall == null
			or left_panel == null
			or right_panel == null
			or header_panel == null
		):
			continue

		assert_gt(
			header_panel.transform.origin.y, left_panel.transform.origin.y,
			"%s silhouette header should sit above the side panels" % config["scene_path"]
		)

		var wall_material: Material = front_wall.get_surface_override_material(0)
		assert_ne(
			left_panel.get_surface_override_material(0),
			wall_material,
			"%s silhouette panel should contrast with the front wall" % config["scene_path"]
		)


func _instantiate_store(config: Dictionary) -> Node3D:
	var scene: PackedScene = load(config["scene_path"])
	assert_not_null(scene, "Scene should load: %s" % config["scene_path"])
	var root: Node3D = scene.instantiate() as Node3D
	assert_not_null(root, "Scene should instantiate: %s" % config["scene_path"])
	add_child_autofree(root)
	return root
