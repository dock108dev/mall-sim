## Tests for ObjectiveRail: four-slot rendering, auto-hide, Settings toggle,
## optional_hint visibility, flash animation, and objective_updated signal.
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


func _updated_payload(day: int, optional: String = "") -> Dictionary:
	return {
		"current_objective": "Objective day %d" % day,
		"next_action": "Action day %d" % day,
		"input_hint": "E",
		"optional_hint": optional,
	}


# ── Three-slot rendering via objective_changed ─────────────────────────────────

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


# ── Four-slot rendering via objective_updated ──────────────────────────────────

func test_objective_updated_updates_objective_label() -> void:
	var rail := _make_rail()
	EventBus.objective_updated.emit(_updated_payload(3))
	assert_eq(rail._objective_label.text, "Objective day 3")


func test_objective_updated_updates_action_label() -> void:
	var rail := _make_rail()
	EventBus.objective_updated.emit(_updated_payload(3))
	assert_eq(rail._action_label.text, "Action day 3")


func test_objective_updated_updates_hint_label() -> void:
	var rail := _make_rail()
	EventBus.objective_updated.emit(_updated_payload(3))
	assert_eq(rail._hint_label.text, "E")


func test_objective_updated_shows_rail() -> void:
	var rail := _make_rail()
	EventBus.objective_updated.emit(_updated_payload(3))
	assert_true(rail.visible)


# ── Optional hint slot ─────────────────────────────────────────────────────────

func test_optional_hint_hidden_when_empty_via_objective_changed() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	assert_false(rail._optional_hint_label.visible)


func test_optional_hint_shown_when_non_empty_via_objective_updated() -> void:
	var rail := _make_rail()
	EventBus.objective_updated.emit(_updated_payload(1, "Hint text here"))
	assert_true(rail._optional_hint_label.visible)
	assert_eq(rail._optional_hint_label.text, "Hint text here")


func test_optional_hint_text_set_correctly() -> void:
	var rail := _make_rail()
	EventBus.objective_updated.emit(_updated_payload(1, "Optional!"))
	assert_eq(rail._optional_hint_label.text, "Optional!")


func test_optional_hint_hides_when_cleared() -> void:
	var rail := _make_rail()
	EventBus.objective_updated.emit(_updated_payload(1, "Present"))
	assert_true(rail._optional_hint_label.visible)
	EventBus.objective_updated.emit(_updated_payload(1, ""))
	assert_false(rail._optional_hint_label.visible)


# ── Flash animation ────────────────────────────────────────────────────────────

func test_flash_tween_created_on_objective_changed() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	assert_not_null(rail._tween, "Tween must be created after objective_changed")


func test_flash_tween_created_on_objective_updated() -> void:
	var rail := _make_rail()
	EventBus.objective_updated.emit(_updated_payload(1))
	assert_not_null(rail._tween, "Tween must be created after objective_updated")


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


func test_hidden_payload_via_objective_updated_hides_rail() -> void:
	var rail := _make_rail()
	EventBus.objective_updated.emit(_updated_payload(1))
	EventBus.objective_updated.emit({"hidden": true})
	assert_false(rail.visible)


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


# ── Signal connections ─────────────────────────────────────────────────────────

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
	var label: Label = rail.get_node("MarginContainer/HBoxContainer/ObjectiveLabel") as Label
	assert_eq(
		int(label.mouse_filter),
		int(Control.MOUSE_FILTER_IGNORE),
		"ObjectiveLabel must have MOUSE_FILTER_IGNORE"
	)


func test_no_input_captured_action_label() -> void:
	var rail := _make_rail()
	var label: Label = rail.get_node("MarginContainer/HBoxContainer/ActionLabel") as Label
	assert_eq(
		int(label.mouse_filter),
		int(Control.MOUSE_FILTER_IGNORE),
		"ActionLabel must have MOUSE_FILTER_IGNORE"
	)


func test_no_input_captured_hint_label() -> void:
	var rail := _make_rail()
	var label: Label = rail.get_node("MarginContainer/HBoxContainer/HintLabel") as Label
	assert_eq(
		int(label.mouse_filter),
		int(Control.MOUSE_FILTER_IGNORE),
		"HintLabel must have MOUSE_FILTER_IGNORE"
	)


func test_no_input_captured_optional_hint_label() -> void:
	var rail := _make_rail()
	var label: Label = rail.get_node(
		"MarginContainer/HBoxContainer/OptionalHintLabel"
	) as Label
	assert_eq(
		int(label.mouse_filter),
		int(Control.MOUSE_FILTER_IGNORE),
		"OptionalHintLabel must have MOUSE_FILTER_IGNORE"
	)
