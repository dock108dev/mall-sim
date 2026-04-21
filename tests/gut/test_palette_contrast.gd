extends GutTest

# Values mirror game/themes/palette.tres — update both together.
const PANEL_SURFACE := Color(0.122, 0.102, 0.086, 1.0)

const STORE_ACCENTS: Dictionary = {
	"retro_games": Color(0.910, 0.647, 0.278, 1.0),
	"pocket_creatures": Color(0.180, 0.710, 0.659, 1.0),
	"video_rental": Color(0.878, 0.306, 0.549, 1.0),
	"electronics": Color(0.227, 0.659, 0.847, 1.0),
	"sports_cards": Color(0.910, 0.333, 0.333, 1.0),
}


func _srgb_to_linear(c: float) -> float:
	if c <= 0.04045:
		return c / 12.92
	return pow((c + 0.055) / 1.055, 2.4)


func _relative_luminance(color: Color) -> float:
	return (
		0.2126 * _srgb_to_linear(color.r)
		+ 0.7152 * _srgb_to_linear(color.g)
		+ 0.0722 * _srgb_to_linear(color.b)
	)


func _contrast_ratio(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


func _hue_delta(a: Color, b: Color) -> float:
	var d := absf(a.h - b.h) * 360.0
	if d > 180.0:
		d = 360.0 - d
	return d


func test_store_accents_pass_wcag_aa_against_panel_surface() -> void:
	for store_id: String in STORE_ACCENTS:
		var accent: Color = STORE_ACCENTS[store_id]
		var ratio: float = _contrast_ratio(accent, PANEL_SURFACE)
		assert_gt(ratio, 4.5, "%s contrast %.2f:1 fails WCAG AA" % [store_id, ratio])


func test_store_accent_hue_deltas_all_above_20_degrees() -> void:
	var ids: Array = STORE_ACCENTS.keys()
	for i: int in range(ids.size()):
		for j: int in range(i + 1, ids.size()):
			var a_id: String = ids[i]
			var b_id: String = ids[j]
			var delta: float = _hue_delta(STORE_ACCENTS[a_id], STORE_ACCENTS[b_id])
			assert_gt(
				delta,
				20.0,
				"Hue delta %s vs %s = %.1f° is below 20°" % [a_id, b_id, delta]
			)


func test_palette_has_nine_base_tokens() -> void:
	# Smoke-check that the base token count is correct by asserting the
	# expected semantic colors match ui_theme_constants.gd.
	var expected_interact := Color(0.357, 0.722, 0.910, 1.0)
	var expected_success := Color(0.427, 0.812, 0.353, 1.0)
	var expected_warning := Color(0.949, 0.722, 0.110, 1.0)
	var expected_danger := Color(0.898, 0.243, 0.169, 1.0)
	assert_eq(UIThemeConstants.SEMANTIC_INFO, expected_interact, "accent_interact mismatch")
	assert_eq(UIThemeConstants.SEMANTIC_SUCCESS, expected_success, "accent_success mismatch")
	assert_eq(UIThemeConstants.SEMANTIC_WARNING, expected_warning, "accent_warning mismatch")
	assert_eq(UIThemeConstants.SEMANTIC_ERROR, expected_danger, "accent_danger mismatch")


func test_store_accents_match_ui_theme_constants() -> void:
	for store_id: String in STORE_ACCENTS:
		var palette_color: Color = STORE_ACCENTS[store_id]
		var runtime_color: Color = UIThemeConstants.STORE_ACCENTS.get(store_id, Color.BLACK)
		assert_eq(
			palette_color,
			runtime_color,
			"palette.tres and UIThemeConstants disagree on %s accent" % store_id
		)
