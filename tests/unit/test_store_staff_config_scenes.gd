## Verifies each store scene has a StoreStaffConfig node with wired Marker3D children.
extends GutTest


const STORE_SCENES: Array[String] = [
	"res://game/scenes/stores/sports_memorabilia.tscn",
	"res://game/scenes/stores/retro_games.tscn",
	"res://game/scenes/stores/video_rental.tscn",
	"res://game/scenes/stores/pocket_creatures.tscn",
	"res://game/scenes/stores/consumer_electronics.tscn",
]


func test_all_stores_have_staff_config() -> void:
	for scene_path: String in STORE_SCENES:
		var scene: PackedScene = load(scene_path)
		assert_not_null(scene, "Scene should load: %s" % scene_path)
		var root: Node3D = scene.instantiate() as Node3D
		add_child_autofree(root)

		var config: StoreStaffConfig = root.get_node_or_null(
			"StoreStaffConfig"
		) as StoreStaffConfig
		assert_not_null(
			config,
			"%s should have StoreStaffConfig child" % scene_path
		)
		if not config:
			continue

		assert_gt(
			config.register_points.size(), 0,
			"%s: register_points should not be empty" % scene_path
		)
		for marker: Marker3D in config.register_points:
			assert_not_null(
				marker,
				"%s: register_points entry should not be null" % scene_path
			)

		assert_not_null(
			config.backroom_point,
			"%s: backroom_point should be wired" % scene_path
		)
		assert_not_null(
			config.greeter_point,
			"%s: greeter_point should be wired" % scene_path
		)
		assert_not_null(
			config.break_point,
			"%s: break_point should be wired" % scene_path
		)


func test_staff_config_marker_names() -> void:
	for scene_path: String in STORE_SCENES:
		var scene: PackedScene = load(scene_path)
		var root: Node3D = scene.instantiate() as Node3D
		add_child_autofree(root)

		var config: Node = root.get_node_or_null("StoreStaffConfig")
		if not config:
			continue

		assert_not_null(
			config.get_node_or_null("RegisterPoint"),
			"%s: StoreStaffConfig should have RegisterPoint child" % scene_path
		)
		assert_not_null(
			config.get_node_or_null("BackroomPoint"),
			"%s: StoreStaffConfig should have BackroomPoint child" % scene_path
		)
		assert_not_null(
			config.get_node_or_null("GreeterPoint"),
			"%s: StoreStaffConfig should have GreeterPoint child" % scene_path
		)
		assert_not_null(
			config.get_node_or_null("StaffBreakPoint"),
			"%s: StoreStaffConfig should have StaffBreakPoint child" % scene_path
		)


func test_staff_config_is_pure_data_node() -> void:
	var config := StoreStaffConfig.new()
	add_child_autofree(config)
	assert_eq(config.max_staff, 2, "Default max_staff should be 2")
	assert_true(
		config.register_points.is_empty(),
		"Default register_points should be empty"
	)
	assert_null(config.backroom_point, "Default backroom_point should be null")
	assert_null(config.greeter_point, "Default greeter_point should be null")
	assert_null(config.break_point, "Default break_point should be null")
