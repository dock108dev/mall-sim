## ISSUE-005: Milestone modal and card typography — min-size, padding, line cap.
extends GutTest


const _PANEL_SCENE: PackedScene = preload(
	"res://game/scenes/ui/milestones_panel.tscn"
)
const _CARD_SCENE: PackedScene = preload(
	"res://game/scenes/ui/milestone_card.tscn"
)


var _panel: MilestonesPanel
var _card: MilestoneCard


func before_each() -> void:
	_panel = _PANEL_SCENE.instantiate() as MilestonesPanel
	add_child_autofree(_panel)
	_card = _CARD_SCENE.instantiate() as MilestoneCard
	add_child_autofree(_card)


func after_each() -> void:
	InputFocus._reset_for_tests()


# ── Milestone modal ──────────────────────────────────────────────────────────


func test_panel_min_width_at_least_480() -> void:
	var panel_root: PanelContainer = _panel.get_node("PanelRoot")
	assert_gte(
		panel_root.custom_minimum_size.x, 480.0,
		"MilestonesPanel must have custom_minimum_size.x >= 480 to prevent word-stacking"
	)


func test_panel_has_16px_padding_all_sides() -> void:
	var margin: MarginContainer = _panel.get_node("PanelRoot/Margin")
	assert_eq(
		margin.get_theme_constant("margin_left"), 16,
		"Milestone modal margin_left must be 16px"
	)
	assert_eq(
		margin.get_theme_constant("margin_top"), 16,
		"Milestone modal margin_top must be 16px"
	)
	assert_eq(
		margin.get_theme_constant("margin_right"), 16,
		"Milestone modal margin_right must be 16px"
	)
	assert_eq(
		margin.get_theme_constant("margin_bottom"), 16,
		"Milestone modal margin_bottom must be 16px"
	)


func test_panel_default_height_fits_720_viewport() -> void:
	var panel_root: PanelContainer = _panel.get_node("PanelRoot")
	var height: float = panel_root.offset_bottom - panel_root.offset_top
	assert_lte(
		height, 720.0 - 32.0,
		"Panel default height must not exceed viewport height - 32px at 720p"
	)


func test_panel_has_close_button() -> void:
	var close_btn: Button = _panel.get_node_or_null(
		"PanelRoot/Margin/VBox/Header/CloseButton"
	)
	assert_not_null(close_btn, "Milestone modal must have a visible CloseButton")
	assert_ne(close_btn.text, "", "CloseButton must have non-empty text")


func test_panel_has_scroll_container() -> void:
	var scroll: ScrollContainer = _panel.get_node_or_null(
		"PanelRoot/Margin/VBox/Scroll"
	)
	assert_not_null(scroll, "Milestone modal must have a ScrollContainer for overflow")


# ── Milestone card ───────────────────────────────────────────────────────────


func test_description_label_max_lines_is_3() -> void:
	var desc: Label = _card.get_node(
		"Margin/MainVBox/ContentHBox/InfoVBox/DescriptionLabel"
	)
	assert_eq(
		desc.max_lines_visible, 3,
		"DescriptionLabel must cap at 3 lines to prevent word-stacking"
	)


func test_description_label_has_ellipsis_overrun() -> void:
	var desc: Label = _card.get_node(
		"Margin/MainVBox/ContentHBox/InfoVBox/DescriptionLabel"
	)
	assert_eq(
		desc.text_overrun_behavior,
		TextServer.OVERRUN_TRIM_ELLIPSIS,
		"DescriptionLabel must use ellipsis overrun behavior"
	)


func test_info_vbox_has_min_width() -> void:
	var info_vbox: VBoxContainer = _card.get_node(
		"Margin/MainVBox/ContentHBox/InfoVBox"
	)
	assert_gte(
		info_vbox.custom_minimum_size.x, 200.0,
		"InfoVBox must have custom_minimum_size.x >= 200 to prevent word-stacking"
	)


func test_card_two_column_layout_nodes_exist() -> void:
	assert_not_null(
		_card.get_node_or_null("Margin/MainVBox/ContentHBox/InfoVBox"),
		"InfoVBox (left column) must exist"
	)
	assert_not_null(
		_card.get_node_or_null("Margin/MainVBox/ContentHBox/RightVBox"),
		"RightVBox (right column) must exist"
	)
