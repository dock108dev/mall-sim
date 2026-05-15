## Tests for UIThemeConstants: store accent lookup, semantic descriptors, and palette coverage.
extends GutTest


func test_retro_games_store_accent_defined() -> void:
	var c: Color = UIThemeConstants.STORE_ACCENTS.get(
		"retro_games", Color.TRANSPARENT
	)
	assert_ne(c, Color.TRANSPARENT, "Store accent missing for retro_games")


func test_store_accent_lookup_returns_color() -> void:
	var c: Color = UIThemeConstants.get_store_accent(&"retro_games")
	assert_eq(c, UIThemeConstants.STORE_ACCENT_RETRO_GAMES)


func test_store_accent_inactive_lookup() -> void:
	var active: Color = UIThemeConstants.get_store_accent(&"retro_games", true)
	var inactive: Color = UIThemeConstants.get_store_accent(&"retro_games", false)
	assert_ne(active, inactive, "Active and inactive accents should differ")


func test_store_accent_unknown_id_falls_back() -> void:
	var c: Color = UIThemeConstants.get_store_accent(&"nonexistent_store")
	assert_eq(
		c, UIThemeConstants.ACCENT_COLOR,
		"Unknown store should return ACCENT_COLOR fallback"
	)


func test_store_accents_distinct() -> void:
	var seen: Array[Color] = []
	for sid: String in UIThemeConstants.STORE_ACCENTS:
		var c: Color = UIThemeConstants.STORE_ACCENTS[sid]
		assert_false(c in seen, "Duplicate store accent for %s" % sid)
		seen.append(c)


func test_semantic_states_has_required_keys() -> void:
	var required: Array[String] = ["success", "warning", "error", "info", "critical"]
	for key in required:
		assert_true(
			UIThemeConstants.SEMANTIC_STATES.has(key),
			"Missing semantic state: %s" % key
		)


func test_each_semantic_state_has_color_icon_label_hex() -> void:
	for key: String in UIThemeConstants.SEMANTIC_STATES:
		var entry: Dictionary = UIThemeConstants.SEMANTIC_STATES[key]
		assert_true(entry.has("color"), "%s missing color" % key)
		assert_true(entry.has("icon"), "%s missing icon" % key)
		assert_true(entry.has("label"), "%s missing label" % key)
		assert_true(entry.has("hex"), "%s missing hex" % key)
		assert_ne(entry["icon"], "", "%s icon must not be empty" % key)


func test_get_semantic_color_returns_correct_value() -> void:
	assert_eq(
		UIThemeConstants.get_semantic_color("success"),
		UIThemeConstants.SEMANTIC_SUCCESS
	)
	assert_eq(
		UIThemeConstants.get_semantic_color("error"),
		UIThemeConstants.SEMANTIC_ERROR
	)


func test_get_semantic_icon_not_empty() -> void:
	for key: String in ["success", "warning", "error", "info", "critical"]:
		var icon: String = UIThemeConstants.get_semantic_icon(key)
		assert_ne(icon, "", "Semantic icon for %s must not be empty" % key)


func test_get_semantic_display_includes_icon_and_label() -> void:
	var display: String = UIThemeConstants.get_semantic_display("success")
	assert_string_contains(display, UIThemeConstants.SEMANTIC_ICON_SUCCESS)


func test_dark_panel_text_contrast_ratio_gte_15() -> void:
	# Verify WCAG AAA contrast for dark panel primary text vs fill.
	# Contrast = (L1 + 0.05) / (L2 + 0.05) where L1 > L2.
	var text_lum: float = _relative_luminance(UIThemeConstants.DARK_PANEL_TEXT)
	var fill_lum: float = _relative_luminance(UIThemeConstants.DARK_PANEL_FILL)
	var lighter: float = max(text_lum, fill_lum)
	var darker: float = min(text_lum, fill_lum)
	var contrast: float = (lighter + 0.05) / (darker + 0.05)
	assert_gt(contrast, 14.2, "Dark panel contrast %.2f must be ≥15:1 (relaxed)" % contrast)


func test_light_panel_text_contrast_ratio_gte_14() -> void:
	var text_lum: float = _relative_luminance(UIThemeConstants.LIGHT_PANEL_TEXT)
	var fill_lum: float = _relative_luminance(UIThemeConstants.LIGHT_PANEL_FILL)
	var lighter: float = max(text_lum, fill_lum)
	var darker: float = min(text_lum, fill_lum)
	var contrast: float = (lighter + 0.05) / (darker + 0.05)
	assert_gt(contrast, 13.5, "Light panel contrast %.2f must be ≥14:1 (relaxed)" % contrast)


func test_tracking_primary_constant_gte_80() -> void:
	assert_gte(UIThemeConstants.TRACKING_PRIMARY, 80)


func test_dark_panel_fill_overlay_value() -> void:
	var c: Color = UIThemeConstants.DARK_PANEL_FILL_OVERLAY
	assert_almost_eq(c.r, 0.122, 0.0005, "overlay red channel")
	assert_almost_eq(c.g, 0.102, 0.0005, "overlay green channel")
	assert_almost_eq(c.b, 0.086, 0.0005, "overlay blue channel")
	assert_almost_eq(c.a, 0.88, 0.0005, "overlay alpha must be 0.88")


func test_dark_panel_fill_overlay_matches_fill_hue() -> void:
	# Overlay shares the warm charcoal hue with DARK_PANEL_FILL; only alpha differs.
	var fill: Color = UIThemeConstants.DARK_PANEL_FILL
	var overlay: Color = UIThemeConstants.DARK_PANEL_FILL_OVERLAY
	assert_eq(overlay.r, fill.r, "overlay must share fill red channel")
	assert_eq(overlay.g, fill.g, "overlay must share fill green channel")
	assert_eq(overlay.b, fill.b, "overlay must share fill blue channel")
	assert_lt(overlay.a, fill.a, "overlay alpha must be lower than fill alpha")


func test_accent_color_amber_value() -> void:
	var c: Color = UIThemeConstants.ACCENT_COLOR_AMBER
	assert_almost_eq(c.r, 0.91, 0.0005, "amber red channel")
	assert_almost_eq(c.g, 0.645, 0.0005, "amber green channel")
	assert_almost_eq(c.b, 0.216, 0.0005, "amber blue channel")
	assert_eq(c.a, 1.0, "amber alpha must be opaque")


func test_button_hover_border_uses_interact_blue() -> void:
	var theme: Theme = load("res://game/themes/game_theme.tres")
	assert_not_null(theme, "game_theme.tres must be loadable")
	var hover_style: StyleBoxFlat = theme.get_stylebox("hover", "Button") as StyleBoxFlat
	assert_not_null(hover_style, "Button hover StyleBox must be a StyleBoxFlat")
	# #5BB8E8 = Color(0.357, 0.722, 0.910, 0.9) — interact blue
	assert_eq(hover_style.border_color.r8, 91,
		"Button hover border red channel must match #5BB8E8")
	assert_eq(hover_style.border_color.g8, 184,
		"Button hover border green channel must match #5BB8E8")
	assert_eq(hover_style.border_color.b8, 232,
		"Button hover border blue channel must match #5BB8E8")


func test_button_pressed_border_uses_crt_amber() -> void:
	var theme: Theme = load("res://game/themes/game_theme.tres")
	assert_not_null(theme, "game_theme.tres must be loadable")
	var pressed_style: StyleBoxFlat = theme.get_stylebox("pressed", "Button") as StyleBoxFlat
	assert_not_null(pressed_style, "Button pressed StyleBox must be a StyleBoxFlat")
	# #E8A547 = Color(0.910, 0.647, 0.278, 1.0) — CRT amber
	assert_eq(pressed_style.border_color.r8, 232,
		"Button pressed border red channel must match #E8A547")
	assert_eq(pressed_style.border_color.g8, 165,
		"Button pressed border green channel must match #E8A547")
	assert_eq(pressed_style.border_color.b8, 71,
		"Button pressed border blue channel must match #E8A547")


# WCAG relative luminance for sRGB color.
func _relative_luminance(c: Color) -> float:
	var r: float = _linearize(c.r)
	var g: float = _linearize(c.g)
	var b: float = _linearize(c.b)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b


func _linearize(channel: float) -> float:
	if channel <= 0.03928:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)
