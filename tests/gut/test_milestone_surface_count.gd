## Milestone completion must not create a large gameplay notification card.
## Milestones live in `MilestonesPanel`; transient unlock/reward feedback uses
## the compact toast lane.
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


func test_game_world_does_not_spawn_notification_mode_milestone_card() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://game/scenes/world/game_world.gd"
	)
	assert_false(
		src.contains("notification_mode = true"),
		"game_world must not spawn a large notification-mode MilestoneCard"
	)
	assert_false(
		src.contains("_MILESTONE_CARD_SCENE"),
		"game_world must not preload milestone_card for gameplay notifications"
	)


# ── AC3: no duplicate source files ──────────────────────────────────────────

func test_no_milestone_popup_source_exists() -> void:
	assert_false(
		FileAccess.file_exists("res://game/scenes/ui/milestone_popup.tscn"),
		"milestone_popup.tscn must not exist — canonical surface is milestones_panel"
	)
	assert_false(
		FileAccess.file_exists("res://game/scripts/ui/milestone_popup.gd"),
		"milestone_popup.gd must not exist"
	)


func test_no_milestone_banner_source_exists() -> void:
	assert_false(
		FileAccess.file_exists("res://game/scenes/ui/milestone_banner.tscn"),
		"milestone_banner.tscn must not exist — transient feedback uses the toast lane"
	)
	assert_false(
		FileAccess.file_exists("res://game/scripts/ui/milestone_banner.gd"),
		"milestone_banner.gd must not exist"
	)


# ── AC4: EventBus milestone signals handled by canonical components ──────────

func test_milestone_completed_connected_in_milestones_panel() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://game/scenes/ui/milestones_panel.gd"
	)
	assert_true(
		src.contains("milestone_completed.connect"),
		"milestones_panel.gd must connect to EventBus.milestone_completed"
	)


func test_unlock_system_uses_id_based_toast_lane() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://game/autoload/unlock_system.gd"
	)
	assert_true(
		src.contains("toast_requested_with_id.emit"),
		"UnlockSystem must use the id-based toast lane for one-shot unlock notices"
	)


func test_milestones_panel_connects_toggle_signal() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://game/scenes/ui/milestones_panel.gd"
	)
	assert_true(
		src.contains("toggle_milestones_panel.connect"),
		"milestones_panel.gd must connect to EventBus.toggle_milestones_panel"
	)


# ── AC5: milestone surface reachable from HUD ────────────────────────────────

func test_hud_tscn_has_milestones_button() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://game/scenes/ui/hud.tscn"
	)
	assert_true(
		src.contains("MilestonesButton"),
		"hud.tscn must define a MilestonesButton node for milestone panel access"
	)


func test_hud_gd_emits_toggle_milestones_panel() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://game/scenes/ui/hud.gd"
	)
	assert_true(
		src.contains("toggle_milestones_panel.emit"),
		"hud.gd must emit toggle_milestones_panel when milestones button is pressed"
	)
