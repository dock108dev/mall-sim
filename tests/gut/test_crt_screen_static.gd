## Tests for the animated CRT screen static shader and material (ISSUE-004).
extends GutTest


func test_shader_file_exists() -> void:
	assert_true(
		ResourceLoader.exists("res://game/resources/shaders/crt_screen_static.gdshader"),
		"crt_screen_static.gdshader must exist"
	)


func test_material_file_exists() -> void:
	assert_true(
		ResourceLoader.exists("res://game/assets/materials/mat_crt_screen_static.tres"),
		"mat_crt_screen_static.tres must exist"
	)


func test_material_loads_as_shader_material() -> void:
	var mat: Resource = load("res://game/assets/materials/mat_crt_screen_static.tres")
	assert_not_null(mat, "mat_crt_screen_static.tres must load")
	assert_true(mat is ShaderMaterial, "material must be a ShaderMaterial")


func test_material_has_shader_assigned() -> void:
	var mat: ShaderMaterial = load("res://game/assets/materials/mat_crt_screen_static.tres")
	assert_not_null(mat.shader, "ShaderMaterial must have a shader assigned")


func test_shader_brightness_parameter_default() -> void:
	var mat: ShaderMaterial = load("res://game/assets/materials/mat_crt_screen_static.tres")
	var brightness: float = mat.get_shader_parameter("screen_brightness")
	assert_almost_eq(brightness, 2.0, 0.001, "default screen_brightness should be 2.0")


func test_retro_games_scene_applies_crt_material() -> void:
	var content: String = FileAccess.get_file_as_string(
		"res://game/scenes/stores/retro_games.tscn"
	)
	assert_true(
		content.contains("mat_crt_screen_static.tres"),
		"retro_games.tscn must reference mat_crt_screen_static.tres"
	)
	assert_true(
		content.contains("CRTScreen"),
		"retro_games.tscn must override CRTScreen node material"
	)


func test_consumer_electronics_scene_applies_crt_material() -> void:
	var content: String = FileAccess.get_file_as_string(
		"res://game/scenes/stores/consumer_electronics.tscn"
	)
	assert_true(
		content.contains("mat_crt_screen_static.tres"),
		"consumer_electronics.tscn must reference mat_crt_screen_static.tres"
	)
	assert_false(
		content.contains("kiosk_screen_mat"),
		"consumer_electronics.tscn must not contain inline kiosk_screen_mat"
	)


func test_video_rental_scene_applies_crt_material() -> void:
	var content: String = FileAccess.get_file_as_string(
		"res://game/scenes/stores/video_rental.tscn"
	)
	assert_true(
		content.contains("mat_crt_screen_static.tres"),
		"video_rental.tscn must reference mat_crt_screen_static.tres"
	)
	assert_false(
		content.contains("crt_screen_mat"),
		"video_rental.tscn must not contain inline crt_screen_mat"
	)
