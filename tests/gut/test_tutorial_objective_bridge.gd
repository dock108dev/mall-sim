## Tests ObjectiveDirector bridge: tutorial_step_changed drives ObjectiveRail content.
## Verifies that when tutorial is active, tutorial step text takes priority over
## day objectives, and that tutorial_completed restores day objective content.
extends GutTest

var _orig_tutorial_active: bool
var _orig_tutorial_step_id: String
var _orig_loop_completed: bool
var _orig_current_day: int


func before_each() -> void:
	_orig_tutorial_active = ObjectiveDirector._tutorial_active
	_orig_tutorial_step_id = ObjectiveDirector._current_tutorial_step_id
	_orig_loop_completed = ObjectiveDirector._loop_completed
	_orig_current_day = ObjectiveDirector._current_day
	ObjectiveDirector._tutorial_active = false
	ObjectiveDirector._current_tutorial_step_id = ""
	ObjectiveDirector._loop_completed = false


func after_each() -> void:
	ObjectiveDirector._tutorial_active = _orig_tutorial_active
	ObjectiveDirector._current_tutorial_step_id = _orig_tutorial_step_id
	ObjectiveDirector._loop_completed = _orig_loop_completed
	ObjectiveDirector._current_day = _orig_current_day


# ── Tutorial step → ObjectiveRail ─────────────────────────────────────────────

func test_tutorial_step_changed_emits_objective_changed() -> void:
	var received: Array[Dictionary] = []
	var conn: Callable = func(p: Dictionary) -> void:
		received.append(p)
	EventBus.objective_changed.connect(conn)

	EventBus.tutorial_step_changed.emit("enter_store")

	EventBus.objective_changed.disconnect(conn)
	assert_gt(received.size(), 0, "objective_changed must fire on tutorial_step_changed")


func test_tutorial_step_text_from_json() -> void:
	var received: Array[Dictionary] = []
	var conn: Callable = func(p: Dictionary) -> void:
		received.append(p)
	EventBus.objective_changed.connect(conn)

	EventBus.tutorial_step_changed.emit("enter_store")

	EventBus.objective_changed.disconnect(conn)
	assert_gt(received.size(), 0)
	assert_false(
		received[0].get("text", "").is_empty(),
		"Tutorial step text must not be empty"
	)


func test_tutorial_step_sets_action_slot() -> void:
	var received: Array[Dictionary] = []
	var conn: Callable = func(p: Dictionary) -> void:
		received.append(p)
	EventBus.objective_changed.connect(conn)

	EventBus.tutorial_step_changed.emit("open_inventory")

	EventBus.objective_changed.disconnect(conn)
	assert_gt(received.size(), 0)
	assert_false(
		received[0].get("action", "").is_empty(),
		"Tutorial step must populate action slot"
	)


func test_tutorial_step_sets_key_slot() -> void:
	var received: Array[Dictionary] = []
	var conn: Callable = func(p: Dictionary) -> void:
		received.append(p)
	EventBus.objective_changed.connect(conn)

	EventBus.tutorial_step_changed.emit("open_inventory")

	EventBus.objective_changed.disconnect(conn)
	assert_gt(received.size(), 0)
	assert_eq(received[0].get("key", ""), "[I]", "open_inventory key hint must be [I]")


func test_tutorial_active_flag_set_after_step_changed() -> void:
	EventBus.tutorial_step_changed.emit("place_item")
	assert_true(
		ObjectiveDirector._tutorial_active,
		"_tutorial_active must be true after tutorial_step_changed"
	)


func test_tutorial_active_flag_cleared_on_completed() -> void:
	EventBus.tutorial_step_changed.emit("end_of_day")
	assert_true(ObjectiveDirector._tutorial_active)
	EventBus.tutorial_completed.emit()
	assert_false(
		ObjectiveDirector._tutorial_active,
		"_tutorial_active must be false after tutorial_completed"
	)


func test_tutorial_active_flag_cleared_on_skipped() -> void:
	EventBus.tutorial_step_changed.emit("set_price")
	EventBus.tutorial_skipped.emit()
	assert_false(
		ObjectiveDirector._tutorial_active,
		"_tutorial_active must be false after tutorial_skipped"
	)


# ── Payload via objective_updated (four-slot) ─────────────────────────────────

func test_tutorial_step_drives_objective_updated() -> void:
	var received: Array[Dictionary] = []
	var conn: Callable = func(p: Dictionary) -> void:
		received.append(p)
	EventBus.objective_updated.connect(conn)

	EventBus.tutorial_step_changed.emit("set_price")

	EventBus.objective_updated.disconnect(conn)
	assert_gt(received.size(), 0, "objective_updated must fire on tutorial_step_changed")
	assert_false(received[0].get("hidden", false), "Tutorial payload must not be hidden")


func test_objective_updated_has_current_objective() -> void:
	var received: Array[Dictionary] = []
	var conn: Callable = func(p: Dictionary) -> void:
		received.append(p)
	EventBus.objective_updated.connect(conn)

	EventBus.tutorial_step_changed.emit("place_item")

	EventBus.objective_updated.disconnect(conn)
	assert_gt(received.size(), 0)
	assert_false(
		received[0].get("current_objective", "").is_empty(),
		"current_objective must be set from tutorial prompt_text"
	)


# ── Tutorial finish restores day objectives ───────────────────────────────────

func test_day_objective_emitted_after_tutorial_completed() -> void:
	ObjectiveDirector._current_day = 1
	EventBus.tutorial_step_changed.emit("end_of_day")
	assert_true(ObjectiveDirector._tutorial_active)

	var received: Array[Dictionary] = []
	var conn: Callable = func(p: Dictionary) -> void:
		received.append(p)
	EventBus.objective_changed.connect(conn)

	EventBus.tutorial_completed.emit()

	EventBus.objective_changed.disconnect(conn)
	assert_gt(received.size(), 0, "objective_changed must fire after tutorial_completed")
	assert_false(received[0].get("hidden", false), "Post-tutorial objective must not be hidden")


# ── No screen empty when tutorial active ─────────────────────────────────────

func test_all_tutorial_steps_produce_non_empty_objective() -> void:
	var step_ids: Array[String] = [
		"welcome", "walk_to_store", "enter_store", "open_inventory",
		"place_item", "open_pricing", "set_price",
		"wait_for_customer", "sale_completed", "end_of_day",
	]
	for step_id: String in step_ids:
		var received: Array[Dictionary] = []
		var conn: Callable = func(p: Dictionary) -> void:
			received.append(p)
		EventBus.objective_changed.connect(conn)

		EventBus.tutorial_step_changed.emit(step_id)

		EventBus.objective_changed.disconnect(conn)
		assert_gt(received.size(), 0, "objective_changed must fire for step: %s" % step_id)
		assert_false(
			received[0].get("text", "").is_empty(),
			"objective text must not be empty for step: %s" % step_id
		)
