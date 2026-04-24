## Phase 0.1 P1.4 regression test: Day Summary covers the mall cleanly and
## sits above the tutorial overlay. Verifies the tscn ships as a CanvasLayer
## at layer=12, the Overlay alpha target is ≥ 0.9, the Panel has a solid
## StyleBoxFlat background, and the responsive-modal margins replace the
## broken 400/200 hardcoded margins.
extends GutTest

const _DS_TSCN: String = "res://game/scenes/ui/day_summary.tscn"
const _DS_GD: String = "res://game/scenes/ui/day_summary.gd"


func test_day_summary_is_canvas_layer_at_layer_12() -> void:
	var src: String = FileAccess.get_file_as_string(_DS_TSCN)
	assert_true(
		src.contains('[node name="DaySummary" type="CanvasLayer"]'),
		"DaySummary root must be a CanvasLayer so it can sit above layer=10"
	)
	assert_true(
		src.contains("layer = 12"),
		"DaySummary CanvasLayer must be at layer=12 (above tutorial_overlay=10)"
	)


func test_overlay_target_alpha_is_opaque_enough() -> void:
	var src: String = FileAccess.get_file_as_string(_DS_GD)
	# Regex would be overkill — just assert the constant >= 0.9. We keep
	# the literal text match tight so lowering it below 0.9 fails this test.
	assert_true(
		(
			src.contains("OVERLAY_TARGET_ALPHA: float = 0.9")
			or src.contains("OVERLAY_TARGET_ALPHA: float = 1.0")
		),
		"OVERLAY_TARGET_ALPHA must be >= 0.9 so the mall does not bleed through"
	)


func test_panel_has_solid_stylebox() -> void:
	var src: String = FileAccess.get_file_as_string(_DS_TSCN)
	assert_true(
		src.contains("theme_override_styles/panel = SubResource"),
		"Day Summary Panel must have a solid StyleBoxFlat background"
	)


func test_hardcoded_400_margins_are_gone() -> void:
	var src: String = FileAccess.get_file_as_string(_DS_TSCN)
	assert_false(
		src.contains("margin_left = 400"),
		"hardcoded 400 px margin must be replaced with centered responsive modal"
	)
	assert_false(
		src.contains("margin_top = 200"),
		"hardcoded 200 px margin must be replaced with centered responsive modal"
	)


func test_day_cycle_controller_hides_mall_overview_on_open() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://game/scripts/systems/day_cycle_controller.gd"
	)
	assert_true(
		src.contains("set_mall_overview"),
		"DayCycleController must accept a MallOverview reference"
	)
	assert_true(
		src.contains("_mall_overview.visible = false"),
		"DayCycleController must hide MallOverview on Day Summary open"
	)
	assert_true(
		src.contains("_on_day_summary_dismissed"),
		"DayCycleController must reshow MallOverview on dismiss"
	)


func test_orphan_day_summary_panel_files_are_deleted() -> void:
	assert_false(
		FileAccess.file_exists("res://game/scenes/ui/day_summary_panel.tscn"),
		"orphan day_summary_panel.tscn must be deleted"
	)
	assert_false(
		FileAccess.file_exists("res://game/scripts/ui/day_summary_panel.gd"),
		"orphan day_summary_panel.gd must be deleted"
	)
