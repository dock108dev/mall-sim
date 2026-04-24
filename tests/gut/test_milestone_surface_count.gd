## Phase 0.1 P1.5 regression test: milestone completion is shown by a single
## surface — the `milestone_card` slide-in notification. The duplicate
## `MilestoneContainer` in the Day Summary panel is removed so milestone
## descriptions do not render twice (once correctly in the banner, once
## wrapped one word per line inside the collapsed Day Summary margin).
extends GutTest


func test_day_summary_tscn_has_no_milestone_container() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://game/scenes/ui/day_summary.tscn"
	)
	assert_false(
		src.contains("MilestoneContainer"),
		"MilestoneContainer must be removed from day_summary.tscn (P1.5)"
	)


func test_day_summary_gd_has_no_milestone_code_paths() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://game/scenes/ui/day_summary.gd"
	)
	assert_false(
		src.contains("_add_milestone_label"),
		"_add_milestone_label must be deleted from day_summary.gd"
	)
	assert_false(
		src.contains("_clear_milestones"),
		"_clear_milestones must be deleted from day_summary.gd"
	)
	assert_false(
		src.contains("_milestone_container"),
		"_milestone_container @onready must be removed"
	)
	assert_false(
		src.contains("_milestone_labels"),
		"_milestone_labels array must be removed"
	)


func test_milestone_card_is_the_single_notification_surface() -> void:
	# MilestoneCard (notification mode) is the sole render path on
	# EventBus.milestone_completed. It's still instantiated once in
	# game_world._setup_ui with notification_mode = true.
	var src: String = FileAccess.get_file_as_string(
		"res://game/scenes/world/game_world.gd"
	)
	assert_true(
		src.contains("notification_mode = true"),
		"game_world must instantiate milestone_card with notification_mode = true"
	)
