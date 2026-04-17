## Tests for TutorialSystem progression, skip persistence, and contextual tips.
extends GutTest


const _PROGRESS_PATH: String = TutorialSystem.PROGRESS_PATH

var _tutorial: TutorialSystem
var _saved_tutorial_active: bool = false


func before_each() -> void:
	_clear_progress_file()
	_saved_tutorial_active = GameManager.is_tutorial_active
	_tutorial = TutorialSystem.new()
	add_child_autofree(_tutorial)


func after_each() -> void:
	GameManager.is_tutorial_active = _saved_tutorial_active
	_clear_progress_file()


func test_step_progression_advances_three_sequential_steps() -> void:
	_tutorial.initialize(true)

	var completed_steps: Array[String] = []
	var changed_steps: Array[String] = []
	var on_completed: Callable = func(step_id: String) -> void:
		completed_steps.append(step_id)
	var on_changed: Callable = func(step_id: String) -> void:
		changed_steps.append(step_id)

	EventBus.tutorial_step_completed.connect(on_completed)
	EventBus.tutorial_step_changed.connect(on_changed)

	_tutorial._welcome_timer = TutorialSystem.WELCOME_DURATION
	_tutorial._process(0.01)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.WALK_TO_STORE,
		"Welcome timeout should advance to WALK_TO_STORE"
	)

	_tutorial._movement_accumulated = TutorialSystem.MOVEMENT_THRESHOLD
	_tutorial._track_movement(0.01)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.ENTER_STORE,
		"Movement threshold should advance to ENTER_STORE"
	)

	_tutorial._on_store_entered(&"retro_games")
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.OPEN_INVENTORY,
		"Store entry should advance to OPEN_INVENTORY"
	)

	assert_eq(completed_steps.size(), 3, "Three steps should complete in sequence")
	assert_eq(completed_steps[0], "welcome", "First completed step should be welcome")
	assert_eq(
		completed_steps[1],
		"walk_to_store",
		"Second completed step should be walk_to_store"
	)
	assert_eq(
		completed_steps[2],
		"enter_store",
		"Third completed step should be enter_store"
	)
	assert_eq(changed_steps.size(), 3, "Each advancement should emit a changed step")
	assert_eq(changed_steps[0], "walk_to_store", "First changed step should be walk_to_store")
	assert_eq(changed_steps[1], "enter_store", "Second changed step should be enter_store")
	assert_eq(
		changed_steps[2],
		"open_inventory",
		"Third changed step should be open_inventory"
	)

	EventBus.tutorial_step_completed.disconnect(on_completed)
	EventBus.tutorial_step_changed.disconnect(on_changed)


func test_skip_tutorial_persists_completion_and_prevents_restart() -> void:
	_tutorial.initialize(true)
	_tutorial.skip_tutorial()

	assert_true(
		_tutorial.tutorial_completed,
		"Skipping should mark the tutorial completed"
	)
	assert_false(
		_tutorial.tutorial_active,
		"Skipping should deactivate the tutorial"
	)
	assert_false(
		GameManager.is_tutorial_active,
		"Skipping should clear GameManager tutorial activity"
	)

	var reloaded_tutorial: TutorialSystem = TutorialSystem.new()
	add_child_autofree(reloaded_tutorial)

	var restart_step_ids: Array[String] = []
	var on_restart_step: Callable = func(step_id: String) -> void:
		restart_step_ids.append(step_id)
	EventBus.tutorial_step_changed.connect(on_restart_step)

	reloaded_tutorial.initialize(false)

	assert_true(
		reloaded_tutorial.tutorial_completed,
		"Reloaded state should keep the tutorial completed after skip"
	)
	assert_false(
		reloaded_tutorial.tutorial_active,
		"Reloaded state should not reactivate the tutorial after skip"
	)
	assert_eq(
		restart_step_ids.size(),
		0,
		"Reloading a skipped tutorial should not emit tutorial step start signals"
	)

	EventBus.tutorial_step_changed.disconnect(on_restart_step)


func test_contextual_tips_emit_once_per_trigger_id() -> void:
	_tutorial.tutorial_completed = true
	_tutorial._tips_shown["build_mode"] = true
	_tutorial._ensure_day_started_connected()

	var tip_texts: Array[String] = []
	var on_tip: Callable = func(tip_text: String) -> void:
		tip_texts.append(tip_text)
	EventBus.contextual_tip_requested.connect(on_tip)

	EventBus.day_started.emit(2)
	EventBus.day_started.emit(2)
	EventBus.day_started.emit(3)
	EventBus.day_started.emit(3)

	var ordering_tip_key: String = TutorialSystem.CONTEXTUAL_TIP_KEYS.get(
		"ordering",
		""
	)
	var reputation_tip_key: String = TutorialSystem.CONTEXTUAL_TIP_KEYS.get(
		"reputation",
		""
	)
	assert_eq(
		tip_texts.size(),
		2,
		"Repeated contextual triggers should emit each tip only once"
	)
	assert_eq(
		tip_texts[0],
		tr(ordering_tip_key),
		"Day 2 should emit the ordering tip once"
	)
	assert_eq(
		tip_texts[1],
		tr(reputation_tip_key),
		"Day 3 should emit the reputation tip once"
	)
	assert_true(
		_tutorial._tips_shown.get("ordering", false) as bool,
		"Ordering tip should be tracked as shown"
	)
	assert_true(
		_tutorial._tips_shown.get("reputation", false) as bool,
		"Reputation tip should be tracked as shown"
	)

	EventBus.contextual_tip_requested.disconnect(on_tip)


func _clear_progress_file() -> void:
	if not FileAccess.file_exists(_PROGRESS_PATH):
		return

	var absolute_path: String = ProjectSettings.globalize_path(_PROGRESS_PATH)
	var err: Error = DirAccess.remove_absolute(absolute_path)
	if err != OK and err != ERR_DOES_NOT_EXIST:
		push_error(
			"Failed to remove tutorial progress file: %s" % error_string(err)
		)
