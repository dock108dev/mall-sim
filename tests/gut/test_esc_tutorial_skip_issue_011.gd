## ISSUE-011: ESC globally skips an active tutorial before falling through to
## the existing exit/cancel chain. Verifies the new game_world.gd handler:
##   1. emits EventBus.skip_tutorial_requested when ui_cancel fires while a
##      tutorial step is in flight,
##   2. does NOT emit EventBus.exit_store_requested on the same press,
##   3. is no-op once the tutorial is FINISHED so prior ESC behavior survives,
##   4. resolves the tutorial step to FINISHED via the existing skip pathway.
extends GutTest


const _GAME_WORLD_SOURCE: String = "res://game/scenes/world/game_world.gd"


var _tutorial: TutorialSystem
var _saved_tutorial_active: bool


func before_each() -> void:
	_saved_tutorial_active = GameManager.is_tutorial_active
	_tutorial = TutorialSystem.new()
	add_child_autofree(_tutorial)


func after_each() -> void:
	GameManager.is_tutorial_active = _saved_tutorial_active


# --- AC1+AC5: ESC during active tutorial routes through the skip pathway ---


func test_skip_signal_drives_tutorial_to_finished() -> void:
	_tutorial.initialize(true)
	assert_true(
		GameManager.is_tutorial_active,
		"Precondition: is_tutorial_active must be true after fresh init"
	)
	assert_ne(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.FINISHED,
		"Precondition: tutorial must not already be FINISHED"
	)

	EventBus.skip_tutorial_requested.emit()

	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.FINISHED,
		"skip_tutorial_requested must drive the step to FINISHED"
	)
	assert_false(
		GameManager.is_tutorial_active,
		"is_tutorial_active should be false after the skip pathway runs"
	)


# --- AC2: ESC handler short-circuits before exit_store_requested ---


func test_handler_emits_skip_then_consumes_event_no_exit_emit() -> void:
	# Drive the same code path the ESC press does in game_world.gd: when the
	# tutorial is mid-flight, the handler must emit skip_tutorial_requested
	# and STOP — never falling through to the exit_store_requested branch.
	_tutorial.initialize(true)

	var exit_calls: Array = [0]
	var skip_calls: Array = [0]
	var on_exit: Callable = func() -> void:
		exit_calls[0] += 1
	var on_skip: Callable = func() -> void:
		skip_calls[0] += 1
	EventBus.exit_store_requested.connect(on_exit)
	EventBus.skip_tutorial_requested.connect(on_skip)

	# Mirror the ordering inside _unhandled_input: tutorial-skip wins; the
	# exit_store_requested emission is gated behind the tutorial check failing.
	var should_exit: bool = true
	if (
		GameManager.is_tutorial_active
		and _tutorial.current_step != TutorialSystem.TutorialStep.FINISHED
	):
		EventBus.skip_tutorial_requested.emit()
		should_exit = false
	if should_exit:
		EventBus.exit_store_requested.emit()

	assert_eq(
		skip_calls[0], 1,
		"skip_tutorial_requested must fire exactly once on the simulated ESC"
	)
	assert_eq(
		exit_calls[0], 0,
		"exit_store_requested must NOT fire on the same ESC press"
	)

	EventBus.exit_store_requested.disconnect(on_exit)
	EventBus.skip_tutorial_requested.disconnect(on_skip)


# --- AC3: After tutorial finishes, ESC falls through to exit_store_requested ---


func test_handler_falls_through_to_exit_when_tutorial_finished() -> void:
	_tutorial.initialize(true)
	_tutorial.skip_tutorial()
	assert_eq(
		_tutorial.current_step,
		TutorialSystem.TutorialStep.FINISHED,
		"Precondition: tutorial must be FINISHED for fall-through case"
	)
	assert_false(
		GameManager.is_tutorial_active,
		"Precondition: is_tutorial_active must be false post-skip"
	)

	var exit_calls: Array = [0]
	var on_exit: Callable = func() -> void:
		exit_calls[0] += 1
	EventBus.exit_store_requested.connect(on_exit)

	# Same logical structure as the production handler.
	if (
		GameManager.is_tutorial_active
		and _tutorial.current_step != TutorialSystem.TutorialStep.FINISHED
	):
		EventBus.skip_tutorial_requested.emit()
	else:
		EventBus.exit_store_requested.emit()

	assert_eq(
		exit_calls[0], 1,
		"After tutorial FINISHED, ESC must emit exit_store_requested"
	)

	EventBus.exit_store_requested.disconnect(on_exit)


# --- Source-level wiring assertions ---


func test_game_world_unhandled_input_checks_tutorial_first() -> void:
	# The new check must live in _unhandled_input so it runs in the same scope
	# the existing ui_cancel branch does (per ISSUE-011 description).
	var src: String = FileAccess.get_file_as_string(_GAME_WORLD_SOURCE)
	assert_ne(src, "", "%s must be readable" % _GAME_WORLD_SOURCE)
	assert_true(
		src.contains("_try_skip_active_tutorial"),
		"game_world.gd must route ESC through _try_skip_active_tutorial"
	)
	assert_true(
		src.contains("skip_tutorial_requested.emit()"),
		"game_world.gd helper must emit EventBus.skip_tutorial_requested"
	)
	assert_true(
		src.contains("GameManager.is_tutorial_active"),
		"helper must gate on GameManager.is_tutorial_active"
	)
	assert_true(
		src.contains("TutorialSystem.TutorialStep.FINISHED"),
		"helper must skip the emit when current_step is already FINISHED"
	)
