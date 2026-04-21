## Tests for ObjectiveRail: three-slot rendering, auto-hide, and Settings toggle.
extends GutTest


func _make_rail() -> CanvasLayer:
	var rail: CanvasLayer = preload(
		"res://game/scenes/ui/objective_rail.tscn"
	).instantiate() as CanvasLayer
	add_child_autofree(rail)
	return rail


func _day_payload(day: int) -> Dictionary:
	return {
		"text": "Objective day %d" % day,
		"action": "Action day %d" % day,
		"key": "E",
	}


# ── Three-slot rendering ───────────────────────────────────────────────────────

func test_objective_slot_renders_on_objective_changed() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	assert_eq(rail._objective_label.text, "Objective day 1")


func test_action_slot_renders_on_objective_changed() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	assert_eq(rail._action_label.text, "Action day 1")


func test_hint_slot_renders_on_objective_changed() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	assert_eq(rail._hint_label.text, "E")


func test_rail_becomes_visible_on_valid_payload() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	assert_true(rail.visible)


# ── Auto-hide via hidden payload ───────────────────────────────────────────────

func test_hidden_payload_hides_rail() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	EventBus.objective_changed.emit({"hidden": true})
	assert_false(rail.visible)


func test_subsequent_content_payload_clears_auto_hide() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit({"hidden": true})
	EventBus.objective_changed.emit(_day_payload(2))
	assert_false(rail._auto_hidden)
	assert_true(rail.visible)


# ── Settings toggle ────────────────────────────────────────────────────────────

func test_settings_false_hides_rail() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	EventBus.preference_changed.emit("show_objective_rail", false)
	assert_false(rail.visible)


func test_settings_true_after_auto_hide_clears_and_shows() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	EventBus.objective_changed.emit({"hidden": true})
	assert_false(rail.visible)
	EventBus.preference_changed.emit("show_objective_rail", true)
	assert_false(rail._auto_hidden, "preference true must clear _auto_hidden")
	assert_true(rail.visible)


# ── Signal connections ────────────────────────────────────────────────────────

func test_day_started_signal_does_not_crash() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	EventBus.day_started.emit(2)
	assert_true(rail != null)


func test_arc_unlock_triggered_signal_does_not_crash() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	EventBus.arc_unlock_triggered.emit("test_arc", 5)
	assert_true(rail != null)


# ── Mouse filter ───────────────────────────────────────────────────────────────

func test_no_input_captured_margin_container() -> void:
	var rail := _make_rail()
	var margin: MarginContainer = rail.get_node("MarginContainer") as MarginContainer
	assert_eq(
		int(margin.mouse_filter),
		int(Control.MOUSE_FILTER_IGNORE),
		"MarginContainer must have MOUSE_FILTER_IGNORE"
	)


func test_no_input_captured_objective_label() -> void:
	var rail := _make_rail()
	var label: Label = rail.get_node("MarginContainer/VBoxContainer/ObjectiveLabel") as Label
	assert_eq(
		int(label.mouse_filter),
		int(Control.MOUSE_FILTER_IGNORE),
		"ObjectiveLabel must have MOUSE_FILTER_IGNORE"
	)


func test_no_input_captured_action_label() -> void:
	var rail := _make_rail()
	var label: Label = rail.get_node("MarginContainer/VBoxContainer/ActionLabel") as Label
	assert_eq(
		int(label.mouse_filter),
		int(Control.MOUSE_FILTER_IGNORE),
		"ActionLabel must have MOUSE_FILTER_IGNORE"
	)


func test_no_input_captured_hint_label() -> void:
	var rail := _make_rail()
	var label: Label = rail.get_node("MarginContainer/VBoxContainer/HintLabel") as Label
	assert_eq(
		int(label.mouse_filter),
		int(Control.MOUSE_FILTER_IGNORE),
		"HintLabel must have MOUSE_FILTER_IGNORE"
	)
