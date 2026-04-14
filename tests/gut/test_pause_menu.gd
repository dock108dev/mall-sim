## Tests for PauseMenu pause/resume, save, day summary, and quit flow.
extends GutTest


var _pause_menu: PauseMenu


func before_each() -> void:
	var scene: PackedScene = load(
		"res://game/scenes/ui/pause_menu.tscn"
	)
	_pause_menu = scene.instantiate() as PauseMenu
	add_child(_pause_menu)


func after_each() -> void:
	if is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
	get_tree().paused = false
	GameManager.current_state = GameManager.GameState.MAIN_MENU


func test_process_mode_always() -> void:
	assert_eq(
		_pause_menu.process_mode,
		Node.PROCESS_MODE_ALWAYS,
	)


func test_starts_hidden() -> void:
	assert_false(_pause_menu.is_open())


func test_open_pauses_tree() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	_pause_menu.open()
	assert_true(get_tree().paused)
	assert_true(_pause_menu.is_open())


func test_open_sets_paused_state() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	_pause_menu.open()
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.PAUSED,
	)


func test_close_unpauses_tree() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	_pause_menu.open()
	_pause_menu.close()
	assert_false(get_tree().paused)
	assert_false(_pause_menu.is_open())


func test_resume_restores_gameplay_state() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	_pause_menu.open()
	_pause_menu._resume()
	assert_eq(
		GameManager.current_state,
		GameManager.GameState.GAMEPLAY,
	)
	assert_false(_pause_menu.is_open())


func test_cannot_open_outside_gameplay() -> void:
	GameManager.current_state = GameManager.GameState.MAIN_MENU
	var can_open: bool = _pause_menu._can_open()
	assert_false(can_open)


func test_cannot_open_when_panel_is_open() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	EventBus.panel_opened.emit("inventory_panel")
	var can_open: bool = _pause_menu._can_open()
	assert_false(can_open)


func test_can_open_after_panel_closes() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	EventBus.panel_opened.emit("inventory_panel")
	EventBus.panel_closed.emit("inventory_panel")
	var can_open: bool = _pause_menu._can_open()
	assert_true(can_open)


func test_day_summary_button_disabled_by_default() -> void:
	assert_true(_pause_menu._day_summary_button.disabled)


func test_day_summary_enabled_after_day_end() -> void:
	EventBus.day_ended.emit(1)
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	_pause_menu.open()
	assert_false(_pause_menu._day_summary_button.disabled)


func test_day_summary_disabled_on_new_day() -> void:
	EventBus.day_ended.emit(1)
	EventBus.day_started.emit(2)
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	_pause_menu.open()
	assert_true(_pause_menu._day_summary_button.disabled)


func test_quit_confirmed_unpauses_tree() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	_pause_menu.open()
	assert_true(get_tree().paused)
	_pause_menu._on_quit_confirmed()
	assert_false(get_tree().paused)
	assert_false(_pause_menu.is_open())


func test_quit_canceled_stays_paused() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	_pause_menu.open()
	_pause_menu._on_quit_canceled()
	assert_true(get_tree().paused)
	assert_true(_pause_menu.is_open())


func test_save_toast_hidden_on_open() -> void:
	GameManager.current_state = GameManager.GameState.GAMEPLAY
	_pause_menu.open()
	assert_false(_pause_menu._save_toast.visible)
