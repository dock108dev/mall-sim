## Tests for the CRT overlay scene and theme palette constants.
extends GutTest


func test_crt_overlay_scene_exists() -> void:
	assert_true(
		ResourceLoader.exists("res://game/scenes/ui/crt_overlay.tscn"),
		"crt_overlay.tscn must exist"
	)


func test_crt_overlay_scene_loads() -> void:
	var scene: PackedScene = load("res://game/scenes/ui/crt_overlay.tscn")
	assert_not_null(scene, "crt_overlay.tscn must load")


func test_crt_shader_exists() -> void:
	assert_true(
		ResourceLoader.exists("res://game/resources/shaders/crt_overlay.gdshader"),
		"crt_overlay.gdshader must exist"
	)


func test_crt_overlay_intensity_property() -> void:
	var scene: PackedScene = load("res://game/scenes/ui/crt_overlay.tscn")
	var overlay: Node = scene.instantiate()
	add_child(overlay)
	assert_true(overlay.has_method("_set_intensity") or "intensity" in overlay, "overlay must expose intensity")
	overlay.intensity = 0.5
	assert_almost_eq(overlay.intensity, 0.5, 0.001, "intensity clamps correctly")
	overlay.intensity = 2.0
	assert_almost_eq(overlay.intensity, 1.0, 0.001, "intensity clamped to 1.0")
	overlay.intensity = -1.0
	assert_almost_eq(overlay.intensity, 0.0, 0.001, "intensity clamped to 0.0")
	overlay.queue_free()


func test_settings_has_render_quality_enum() -> void:
	assert_true(
		Settings.RenderQuality.LOW == 0,
		"RenderQuality.LOW must equal 0"
	)
	assert_true(
		Settings.RenderQuality.HIGH == 2,
		"RenderQuality.HIGH must equal 2"
	)


func test_mall_theme_exists() -> void:
	assert_true(
		ResourceLoader.exists("res://game/resources/ui/mall_theme.tres"),
		"mall_theme.tres must exist"
	)


func test_mall_theme_has_jewel_tone_colors() -> void:
	var theme: Theme = load("res://game/resources/ui/mall_theme.tres")
	assert_not_null(theme, "mall_theme must load")
	assert_true(
		theme.has_color("teal", "MallTheme"),
		"theme must define teal color constant"
	)
	assert_true(
		theme.has_color("burgundy", "MallTheme"),
		"theme must define burgundy color constant"
	)
	assert_true(
		theme.has_color("forest_green", "MallTheme"),
		"theme must define forest_green color constant"
	)
	assert_true(
		theme.has_color("gold", "MallTheme"),
		"theme must define gold color constant"
	)


func test_mall_theme_has_font() -> void:
	var theme: Theme = load("res://game/resources/ui/mall_theme.tres")
	assert_true(
		theme.has_font("font", "Label"),
		"theme must define a font for Label"
	)


func test_no_hex_colors_in_tscn_files() -> void:
	var dir_path: String = "res://game/scenes"
	var hex_pattern: RegEx = RegEx.new()
	hex_pattern.compile('= "#[0-9a-fA-F]{6,8}"')
	var violations: Array[String] = []
	_scan_dir_for_hex(dir_path, hex_pattern, violations)
	assert_eq(
		violations.size(), 0,
		"No .tscn file should contain bare hex color strings: %s" % str(violations)
	)


func _scan_dir_for_hex(
	path: String, pattern: RegEx, violations: Array[String]
) -> void:
	var da := DirAccess.open(path)
	if not da:
		return
	da.list_dir_begin()
	var entry: String = da.get_next()
	while entry != "":
		if da.current_is_dir() and not entry.begins_with("."):
			_scan_dir_for_hex(path.path_join(entry), pattern, violations)
		elif entry.ends_with(".tscn"):
			var full: String = path.path_join(entry)
			var content: String = FileAccess.get_file_as_string(full)
			if pattern.search(content):
				violations.append(full)
		entry = da.get_next()
	da.list_dir_end()
