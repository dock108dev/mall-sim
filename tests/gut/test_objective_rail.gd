## Tests for ObjectiveRail: four-slot rendering, auto-hide, Settings toggle,
## optional_hint visibility, flash animation, objective_updated signal,
## D4 accent band store-identity color binding, and screen-state / modal
## visibility guards.
extends GutTest


var _saved_state: GameManager.State


func before_each() -> void:
	_saved_state = GameManager.current_state
	# Default to STORE_VIEW so existing tests of payload-driven visibility do
	# not collide with the MAIN_MENU/DAY_SUMMARY guard added for ISSUE-004.
	GameManager.current_state = GameManager.State.STORE_VIEW


func after_each() -> void:
	GameManager.current_state = _saved_state
	if InputFocus != null:
		InputFocus._reset_for_tests()


func _make_rail() -> CanvasLayer:
	var rail: CanvasLayer = preload(
		"res://game/scenes/ui/objective_rail.tscn"
	).instantiate() as CanvasLayer
	add_child_autofree(rail)
	return rail


func _emit_state(new_state: GameManager.State) -> void:
	var old: GameManager.State = GameManager.current_state
	GameManager.current_state = new_state
	EventBus.game_state_changed.emit(int(old), int(new_state))


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
	assert_true(rail._hint_label.visible)


func test_hint_slot_hidden_when_key_empty() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit({
		"text": "No-key day",
		"action": "Right-click stocked items to adjust price",
		"key": "",
	})
	assert_false(
		rail._hint_label.visible,
		"hint chip must be hidden when key is empty"
	)


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


# ── D4 accent band store-identity color binding ───────────────────────────────

func test_accent_band_node_exists() -> void:
	var rail := _make_rail()
	assert_not_null(rail._band, "AccentBand ColorRect must exist")


func test_accent_band_default_color_is_hub() -> void:
	var rail := _make_rail()
	assert_eq(rail._band.color, Color.html("#5BB8E8"),
		"Default band color must be hub accent #5BB8E8")


func test_accent_band_retro_games_amber() -> void:
	var rail := _make_rail()
	EventBus.store_entered.emit(&"retro_games")
	assert_eq(rail._band.color, Color.html("#E8A547"),
		"Retro Games must show CRT Amber #E8A547")


func test_accent_band_pocket_creatures_teal() -> void:
	var rail := _make_rail()
	EventBus.store_entered.emit(&"pocket_creatures")
	assert_eq(rail._band.color, Color.html("#2EB5A8"),
		"Pocket Creatures must show Holo Teal #2EB5A8")


func test_accent_band_rentals_magenta() -> void:
	var rail := _make_rail()
	EventBus.store_entered.emit(&"rentals")
	assert_eq(rail._band.color, Color.html("#E04E8C"),
		"Video Rental (rentals) must show Late-Fee Magenta #E04E8C")


func test_accent_band_video_rental_alias_magenta() -> void:
	var rail := _make_rail()
	EventBus.store_entered.emit(&"video_rental")
	assert_eq(rail._band.color, Color.html("#E04E8C"),
		"Video Rental alias must show Late-Fee Magenta #E04E8C")


func test_accent_band_electronics_cyan() -> void:
	var rail := _make_rail()
	EventBus.store_entered.emit(&"electronics")
	assert_eq(rail._band.color, Color.html("#3AA8D8"),
		"Electronics must show CRT Cyan #3AA8D8")


func test_accent_band_consumer_electronics_alias_cyan() -> void:
	var rail := _make_rail()
	EventBus.store_entered.emit(&"consumer_electronics")
	assert_eq(rail._band.color, Color.html("#3AA8D8"),
		"consumer_electronics alias must show CRT Cyan #3AA8D8")


func test_accent_band_sports_crimson() -> void:
	var rail := _make_rail()
	EventBus.store_entered.emit(&"sports")
	assert_eq(rail._band.color, Color.html("#E85555"),
		"Sports must show Grading Crimson #E85555")


func test_accent_band_sports_memorabilia_alias_crimson() -> void:
	var rail := _make_rail()
	EventBus.store_entered.emit(&"sports_memorabilia")
	assert_eq(rail._band.color, Color.html("#E85555"),
		"sports_memorabilia alias must show Grading Crimson #E85555")


func test_accent_band_resets_to_hub_on_store_exited() -> void:
	var rail := _make_rail()
	EventBus.store_entered.emit(&"retro_games")
	assert_eq(rail._band.color, Color.html("#E8A547"),
		"Pre-condition: band should be amber after entering retro_games")
	EventBus.store_exited.emit(&"retro_games")
	assert_eq(rail._band.color, Color.html("#5BB8E8"),
		"Band must reset to hub color #5BB8E8 after store_exited")


func test_accent_band_unknown_store_defaults_to_hub() -> void:
	var rail := _make_rail()
	EventBus.store_entered.emit(&"nonexistent_store_xyz")
	assert_eq(rail._band.color, Color.html("#5BB8E8"),
		"Unknown store ID must fall back to hub color #5BB8E8")


# ── Screen-state guard ─────────────────────────────────────────────────────────

func test_rail_hidden_in_main_menu_state() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	assert_true(rail.visible, "Pre-condition: rail visible in STORE_VIEW")
	_emit_state(GameManager.State.MAIN_MENU)
	assert_false(
		rail.visible,
		"Rail must hide when GameManager state is MAIN_MENU"
	)


func test_rail_hidden_in_day_summary_state() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	_emit_state(GameManager.State.DAY_SUMMARY)
	assert_false(
		rail.visible,
		"Rail must hide when GameManager state is DAY_SUMMARY"
	)


func test_rail_visible_again_after_returning_to_gameplay_state() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	_emit_state(GameManager.State.MAIN_MENU)
	assert_false(rail.visible)
	_emit_state(GameManager.State.STORE_VIEW)
	assert_true(
		rail.visible,
		"Rail must reappear once state returns to a gameplay state"
	)


func test_payload_during_main_menu_does_not_show_rail() -> void:
	var rail := _make_rail()
	_emit_state(GameManager.State.MAIN_MENU)
	EventBus.objective_changed.emit(_day_payload(1))
	assert_false(
		rail.visible,
		"A payload arriving while in MAIN_MENU must not surface the rail"
	)


# ── Modal context guard ────────────────────────────────────────────────────────

func test_rail_hidden_when_modal_context_pushed() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	assert_true(rail.visible, "Pre-condition: rail visible without modal")
	InputFocus.push_context(InputFocus.CTX_MODAL)
	assert_false(
		rail.visible,
		"Rail must hide while a modal context is on top of the InputFocus stack"
	)


func test_rail_visible_again_when_modal_context_popped() -> void:
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	InputFocus.push_context(InputFocus.CTX_MODAL)
	assert_false(rail.visible, "Pre-condition: rail hidden under modal")
	InputFocus.pop_context()
	assert_true(
		rail.visible,
		"Rail must reappear when the modal context is popped"
	)


# ── Flash re-trigger on hidden→visible transition ──────────────────────────────

func test_flash_retriggers_when_rail_transitions_from_modal_hidden_to_visible() -> void:
	# When a payload arrives while a modal is up, the initial _flash() runs
	# against an invisible rail — the alpha tween completes in the background
	# and the rail snaps in at full opacity when the modal closes. Verify the
	# rail re-flashes on the hidden→visible edge so the player still sees the
	# 1-second fade-in.
	var rail := _make_rail()
	InputFocus.push_context(InputFocus.CTX_MODAL)
	EventBus.objective_changed.emit(_day_payload(1))
	assert_false(rail.visible, "Pre-condition: rail hidden behind modal")
	var pre_pop_tween: Tween = rail._tween
	InputFocus.pop_context()
	assert_true(rail.visible, "Rail must be visible after modal pops")
	assert_not_null(rail._tween, "A flash tween must exist after re-show")
	assert_ne(
		rail._tween, pre_pop_tween,
		"Hidden→visible transition must replace the original (modal-hidden) tween"
	)
	assert_eq(
		rail._margin.modulate.a, 0.0,
		"Re-flash must reset the margin alpha to 0 so the fade is visible"
	)


func test_refresh_does_not_retrigger_flash_when_already_visible() -> void:
	# Once visible, calling _refresh_visibility() again must not start a new
	# flash tween — only the hidden→visible edge re-flashes.
	var rail := _make_rail()
	EventBus.objective_changed.emit(_day_payload(1))
	assert_true(rail.visible, "Pre-condition: rail visible")
	var first_tween: Tween = rail._tween
	rail._refresh_visibility()
	assert_eq(
		rail._tween, first_tween,
		"Already-visible refresh must not start a second flash tween"
	)


func test_refresh_does_not_flash_when_resolving_hidden() -> void:
	# A refresh that resolves should_show=false must not call _flash().
	var rail := _make_rail()
	# No payload yet -> rail stays hidden. Force a refresh via state change.
	_emit_state(GameManager.State.MAIN_MENU)
	assert_false(rail.visible, "Rail hidden in MAIN_MENU with no payload")
	assert_null(rail._tween, "No flash tween should run while staying hidden")
