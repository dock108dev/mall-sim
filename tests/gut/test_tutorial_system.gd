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
		TutorialSystem.TutorialStep.PLATFORM_MATCH,
		"Welcome timeout should advance to PLATFORM_MATCH"
	)

	EventBus.customer_platform_identified.emit(&"c1", &"ignite_go", true)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.STOCK_SHELF,
		"customer_platform_identified should advance to STOCK_SHELF"
	)

	EventBus.item_stocked.emit("item_1", "shelf_1")
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.CONDITION_RISK,
		"item_stocked should advance to CONDITION_RISK"
	)

	assert_eq(completed_steps.size(), 3, "Three steps should complete in sequence")
	assert_eq(completed_steps[0], "welcome", "First completed step should be welcome")
	assert_eq(
		completed_steps[1],
		"platform_match",
		"Second completed step should be platform_match"
	)
	assert_eq(
		completed_steps[2],
		"stock_shelf",
		"Third completed step should be stock_shelf"
	)
	assert_eq(changed_steps.size(), 3, "Each advancement should emit a changed step")
	assert_eq(
		changed_steps[0], "platform_match",
		"First changed step should be platform_match"
	)
	assert_eq(
		changed_steps[1], "stock_shelf",
		"Second changed step should be stock_shelf"
	)
	assert_eq(
		changed_steps[2],
		"condition_risk",
		"Third changed step should be condition_risk"
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
	for step_index: int in range(TutorialSystem.STEP_COUNT):
		var step_id: String = TutorialSystem.STEP_IDS.get(
			step_index, ""
		)
		assert_true(
			_tutorial._completed_steps.get(step_id, false) as bool,
			"Skipping should mark %s complete" % step_id
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


func test_gameplay_ready_completes_welcome_step() -> void:
	_tutorial.initialize(true)

	EventBus.gameplay_ready.emit()

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.PLATFORM_MATCH,
		"gameplay_ready should complete the welcome step"
	)
	assert_true(
		_tutorial._completed_steps.get("welcome", false) as bool,
		"Welcome should be tracked as completed"
	)


func test_load_progress_without_file_starts_first_step() -> void:
	_tutorial.initialize(false)

	assert_true(
		_tutorial.tutorial_active,
		"Missing persisted progress should begin tutorial"
	)
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.WELCOME,
		"Missing persisted progress should start at WELCOME"
	)


func test_stale_schema_version_resets_progress() -> void:
	# Hand-craft a cfg from an earlier schema version: ordinals reference the
	# old owner-loop enum (e.g. v2 PLACE_ITEM was index 3) and would land on
	# unrelated beats in the current employee-loop enum.
	var stale := ConfigFile.new()
	stale.set_value("tutorial", "schema_version", 2)
	stale.set_value("tutorial", "completed", false)
	stale.set_value("tutorial", "active", true)
	stale.set_value("tutorial", "current_step", 3)
	stale.set_value(
		"tutorial", "completed_steps",
		{"welcome": true, "open_inventory": true, "select_item": true}
	)
	stale.set_value("tutorial", "tips_shown", {})
	var save_err: Error = stale.save(_PROGRESS_PATH)
	assert_eq(save_err, OK, "Setup: stale cfg must be writable")

	_tutorial.initialize(false)

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.WELCOME,
		"Stale schema_version must reset progress to WELCOME"
	)
	assert_false(
		_tutorial.tutorial_completed,
		"Stale schema_version must clear tutorial_completed"
	)
	assert_eq(
		_tutorial._completed_steps.size(), 0,
		"Stale schema_version must drop persisted completed_steps"
	)


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
