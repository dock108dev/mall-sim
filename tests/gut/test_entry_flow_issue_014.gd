## ISSUE-014: Boot → MainMenu → New Game → MallHub via SceneRouter.
## Verifies AuditLog emits the entry-flow checkpoints and that
## GameManager.begin_new_run() initializes a fresh run state.
extends GutTest


func before_each() -> void:
	AuditLog.clear()
	GameManager.pending_load_slot = -1


func test_begin_new_run_resets_day_and_emits_checkpoint() -> void:
	GameManager.set_current_day(7)
	GameManager.begin_new_run()
	assert_eq(
		GameManager.get_current_day(), 1,
		"begin_new_run() must reset current_day to 1"
	)
	assert_eq(
		GameManager.pending_load_slot, -1,
		"begin_new_run() must clear pending_load_slot"
	)
	var entries: Array[Dictionary] = AuditLog.recent(16)
	var saw_new_game_clicked: bool = false
	for entry: Dictionary in entries:
		if (
			entry.get("checkpoint", &"") == &"new_game_clicked"
			and entry.get("status", "") == "PASS"
		):
			saw_new_game_clicked = true
			break
	assert_true(
		saw_new_game_clicked,
		"begin_new_run() must emit AUDIT: PASS new_game_clicked"
	)


func test_main_menu_scene_emits_main_menu_ready() -> void:
	var scene: PackedScene = load("res://game/scenes/ui/main_menu.tscn")
	var menu: Control = scene.instantiate() as Control
	add_child_autofree(menu)
	await get_tree().process_frame
	var entries: Array[Dictionary] = AuditLog.recent(16)
	var saw: bool = false
	for entry: Dictionary in entries:
		if (
			entry.get("checkpoint", &"") == &"main_menu_ready"
			and entry.get("status", "") == "PASS"
		):
			saw = true
			break
	assert_true(saw, "MainMenu._ready() must emit main_menu_ready")
