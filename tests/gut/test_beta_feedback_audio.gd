## Day-1 beta feedback audio coverage.
##
## Uses AudioManager.audio_played as the observable contract so tests do not
## depend on AudioServer playback in headless runs.
extends GutTest


var _manager: Node


func before_each() -> void:
	_stop_sfx_players(AudioManager)
	_manager = Node.new()
	_manager.set_script(preload("res://game/autoload/audio_manager.gd"))
	add_child_autofree(_manager)
	_stop_sfx_players(_manager)
	watch_signals(_manager)


func after_each() -> void:
	_stop_sfx_players(_manager)
	_stop_sfx_players(AudioManager)


func test_customer_interaction_uses_ui_feedback_audio() -> void:
	EventBus.customer_interacted.emit(null)
	assert_true(
		_audio_key_seen("ui_click"),
		"Talking to the Day-1 customer must emit a subtle UI feedback key"
	)


func test_backroom_and_stock_feedback_use_distinct_audio_keys() -> void:
	EventBus.beta_backroom_count_changed.emit(5)
	EventBus.beta_shelf_count_changed.emit(5)
	assert_true(
		_audio_key_seen("ui_click"),
		"Checking the back-room delivery must emit immediate feedback"
	)
	assert_true(
		_audio_key_seen("item_placement"),
		"Stocking the beta shelf must reuse the item-placement feedback"
	)


func test_modal_and_day_close_feedback_are_observable() -> void:
	EventBus.modal_opened.emit(&"BetaDecisionCardPanel")
	EventBus.modal_closed.emit(&"BetaDecisionCardPanel")
	EventBus.day_close_requested.emit()
	EventBus.day_close_confirmed.emit()
	assert_gte(
		_audio_key_count("ui_click"), 3,
		"Modal open/close and close-day request must provide UI click feedback"
	)
	assert_true(
		_audio_key_seen("notification_ping"),
		"Close-day confirmation must emit a distinct acknowledgement key"
	)


func test_optional_hidden_clue_feedback_is_observable() -> void:
	EventBus.beta_hidden_clue_inspected.emit(&"day01_backroom_modded_console_hint")
	assert_true(
		_audio_key_seen("notification_ping"),
		"Inspecting the optional console stack must emit a subtle acknowledgement"
	)


func test_objective_completion_feedback_is_observable() -> void:
	EventBus.objective_completed.emit(&"stock_shelf", "Shelf stocked.")
	assert_true(
		_audio_key_seen("notification_ping"),
		"Completing a beta objective must emit an observable acknowledgement key"
	)


func test_blocked_interaction_feedback_is_throttled() -> void:
	EventBus.interactable_focused_disabled.emit("Finish the current objective first.")
	EventBus.interactable_focused_disabled.emit("Finish the current objective first.")
	EventBus.interactable_focused_disabled.emit("Employee area is locked.")
	assert_eq(
		_audio_key_count("ui_click"), 1,
		"Repeated blocked focus must not spam feedback audio"
	)


func test_empty_disabled_reason_stays_silent() -> void:
	EventBus.interactable_focused_disabled.emit("")
	assert_signal_not_emitted(
		_manager, "audio_played",
		"Empty disabled reasons are passive visual hints and should stay silent"
	)


func _audio_key_seen(key: String) -> bool:
	return _audio_key_count(key) > 0


func _audio_key_count(key: String) -> int:
	var count: int = 0
	var emissions: int = get_signal_emit_count(_manager, "audio_played")
	for idx: int in range(emissions):
		var params: Variant = get_signal_parameters(_manager, "audio_played", idx)
		if params is Array and not (params as Array).is_empty():
			if String((params as Array)[0]) == key:
				count += 1
	return count


func _stop_sfx_players(root: Node) -> void:
	if root == null:
		return
	for child: Node in root.get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
