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
		var scene_text: String = FileAccess.get_file_as_string(scene_path)
		assert_false(
			scene_text.is_empty(),
			"Store scene '%s' should be readable" % scene_path
		)
		assert_string_contains(
			scene_text,
			"cell_size = 0.25",
			"Store scene '%s' should pin nav mesh cell size to 0.25m"
			% scene_path
		)
		assert_string_contains(
			scene_text,
			"geometry_parsed_geometry_type = 2",
			"Store scene '%s' should parse StaticBody3D colliders during rebakes"
			% scene_path
		)
