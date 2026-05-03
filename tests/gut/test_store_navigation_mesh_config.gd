## Verifies store scenes ship with bake-ready navigation mesh settings.
extends GutTest

const STORE_SCENE_PATHS: Array[String] = [
	"res://game/scenes/stores/sports_memorabilia.tscn",
	"res://game/scenes/stores/retro_games.tscn",
	"res://game/scenes/stores/video_rental.tscn",
	"res://game/scenes/stores/consumer_electronics.tscn",
	"res://game/scenes/stores/pocket_creatures.tscn",
]


func test_store_navigation_meshes_use_bake_ready_settings() -> void:
	for scene_path: String in STORE_SCENE_PATHS:
		var packed: PackedScene = load(scene_path)
		assert_not_null(
			packed, "Store scene '%s' should load" % scene_path
		)
		if packed == null:
			continue
		var instance: Node = packed.instantiate()
		assert_not_null(
			instance, "Store scene '%s' should instantiate" % scene_path
		)
		if instance == null:
			continue
		var region: NavigationRegion3D = (
			instance.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
		)
		assert_not_null(
			region,
			"Store scene '%s' should expose NavigationRegion3D" % scene_path
		)
		if region == null:
			instance.free()
			continue
		var nav_mesh: NavigationMesh = region.navigation_mesh
		assert_not_null(
			nav_mesh,
			"Store scene '%s' should carry a NavigationMesh" % scene_path
		)
		if nav_mesh != null:
			assert_almost_eq(
				nav_mesh.cell_size, 0.25, 0.001,
				"Store scene '%s' should pin nav mesh cell size to 0.25m"
				% scene_path
			)
			var parsed_type: int = nav_mesh.geometry_parsed_geometry_type
			assert_true(
				parsed_type == NavigationMesh.PARSED_GEOMETRY_BOTH
				or parsed_type == NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS,
				(
					"Store scene '%s' should parse StaticBody3D colliders "
					+ "during rebakes (got %d)"
				) % [scene_path, parsed_type]
			)
		instance.free()
